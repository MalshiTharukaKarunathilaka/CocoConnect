import { useEffect, useMemo, useRef, useState } from 'react'
import { GeoJSON, MapContainer, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { api } from '../api'
import { PROVINCE_COLORS, label, provinceOf, rampOf } from './data'

const norm = (s) => String(s || '').toLowerCase().replace(/[^a-z]/g, '')
const lkr = (n) => `Rs. ${Number(n).toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

// Districts that are split into smaller regions (only Kurunegala so far).
const SUB_FILES = { kurunegala: '/geo/kurunegala-cdo.json' }
const subCache = {}
const loadSub = (key) => (subCache[key] ||= fetch(SUB_FILES[key]).then((r) => r.json()))

// ---- number that counts to its new value -----------------------------------
function useCountUp(target, ms = 800) {
  const [shown, setShown] = useState(target ?? 0)
  const from = useRef(target ?? 0)
  useEffect(() => {
    if (target == null) return undefined
    const start = performance.now()
    const begin = from.current
    let raf
    const tick = (now) => {
      const t = Math.min(1, (now - start) / ms)
      const v = begin + (target - begin) * (1 - Math.pow(1 - t, 3))
      from.current = v
      setShown(v)
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, ms])
  return shown
}

function Fit({ geo, focus }) {
  const map = useMap()
  useEffect(() => {
    map.invalidateSize()
    const feats = focus ? geo.features.filter((f) => norm(f.properties.district) === focus) : geo.features
    map.fitBounds(L.geoJSON({ type: 'FeatureCollection', features: feats }).getBounds(), { padding: [14, 14], maxZoom: focus ? 10 : 9, animate: true })
  }, [map, geo, focus])
  return null
}

// A real coconut photo that turns gently in 3D.
function Coconut({ small }) {
  return (
    <div className={`pc-nut ${small ? 'small' : ''}`}>
      <div className="pc-turn">
        <img src="/photos/coconut.png" alt="" draggable={false} />
        <span className="pc-gloss" />
      </div>
    </div>
  )
}

export default function PriceMap({ geo }) {
  const [data, setData] = useState(null) // { districts: [...], updatedAt }
  const [error, setError] = useState('')
  const [picked, setPicked] = useState(null) // district name as in the map file
  const [region, setRegion] = useState(null) // small region inside the district
  const [subGeo, setSubGeo] = useState(null)
  const [preview, setPreview] = useState(null) // Kurunegala's regions, drawn faintly before you zoom in
  useEffect(() => {
    let live = true
    loadSub('kurunegala').then((g) => live && setPreview(g)).catch(() => {})
    return () => {
      live = false
    }
  }, [])

  useEffect(() => {
    let live = true
    const load = () =>
      api('/admin/prices/districts')
        .then((r) => live && (setData(r), setError('')))
        .catch((e) => live && setError(e.message || 'Could not load prices'))
    load()
    const t = setInterval(load, 60000) // prices follow the database
    return () => {
      live = false
      clearInterval(t)
    }
  }, [])

  const pickedKey = norm(picked)
  const subKey = SUB_FILES[pickedKey] ? pickedKey : null
  useEffect(() => {
    setRegion(null)
    if (!subKey) return setSubGeo(null)
    let live = true
    loadSub(subKey).then((g) => live && setSubGeo(g)).catch(() => live && setSubGeo(null))
    return () => {
      live = false
    }
  }, [subKey])

  const byName = useMemo(() => Object.fromEntries((data?.districts || []).map((d) => [norm(d.name), d])), [data])
  const priceOf = (name) => byName[norm(name)]
  // every district keeps its province colour. The palest tint means "no price yet"; priced ones run darker with the price.
  const rampColor = (v, lo, hi, prov) => {
    const ramp = rampOf(PROVINCE_COLORS[prov] || '#256b45')
    if (v == null) return ramp[0]
    const t = hi === lo ? 0.6 : (v - lo) / (hi - lo)
    return ramp[1 + Math.min(ramp.length - 2, Math.floor(t * (ramp.length - 1) * 0.999))]
  }
  const prices = (data?.districts || []).map((d) => d.avg).filter((v) => v != null)
  const lo = Math.min(...prices, Infinity)
  const hi = Math.max(...prices, -Infinity)

  // price for one small region: deals in that town, else the district average
  const regionStat = (name) => {
    const d = priceOf(picked)
    const hit = d?.places?.[norm(String(name).replace(/\s*region$/i, ''))]
    if (hit) return { ...hit, source: 'deals' }
    return d && d.avg != null ? { avg: d.avg, min: d.min, max: d.max, samples: d.samples, source: 'district' } : null
  }
  const regionAvgs = subGeo ? subGeo.features.map((f) => regionStat(f.properties.region)?.avg).filter((v) => v != null) : []
  const rLo = Math.min(...regionAvgs, Infinity)
  const rHi = Math.max(...regionAvgs, -Infinity)

  const current = region ? regionStat(region) : picked ? priceOf(picked) : null
  const price = useCountUp(current?.avg ?? null)
  const sig = `${picked}|${data?.updatedAt || ''}|${subGeo ? 'sub' : ''}`

  const style = (f) => {
    const name = f.properties.district
    const on = name === picked
    const split = on && subGeo
    return {
      fillColor: split ? '#e9f2ec' : rampColor(priceOf(name)?.avg, lo, hi, provinceOf(name)),
      fillOpacity: split ? 0.35 : subGeo ? 0.55 : 0.95,
      weight: on ? 3 : 1,
      color: on ? '#15201a' : '#ffffff',
    }
  }
  const onEach = (f, layer) => {
    const name = f.properties.district
    const p = priceOf(name)
    layer.bindTooltip(`<b>${label(name)}</b><br/>${p?.avg != null ? lkr(p.avg) : 'No price yet'}`, { sticky: true, direction: 'top' })
    layer.on({
      click: () => {
        setPicked(name)
        setRegion(null)
      },
      mouseover: () => layer.setStyle({ weight: 2.5, color: '#15201a' }),
      mouseout: () => layer.setStyle(style(f)),
    })
  }

  const subStyle = (f) => {
    const on = region === f.properties.region
    return { fillColor: rampColor(regionStat(f.properties.region)?.avg, rLo, rHi, provinceOf(picked)), fillOpacity: 0.97, weight: on ? 3.5 : 1.6, color: on ? '#15201a' : '#ffffff' }
  }
  const subEach = (f, layer) => {
    const name = f.properties.region
    const s = regionStat(name)
    layer.bindTooltip(`<b>${name}</b><br/>${s?.avg != null ? lkr(s.avg) : 'No price yet'}`, { sticky: true, direction: 'top' })
    layer.on({
      click: () => setRegion(region === name ? null : name),
      mouseover: () => layer.setStyle({ weight: 3, color: '#15201a' }),
      mouseout: () => layer.setStyle(subStyle(f)),
    })
  }

  const crumbs = [
    { text: 'Sri Lanka', go: () => { setPicked(null); setRegion(null) } },
    picked && (region ? { text: label(picked), go: () => setRegion(null) } : { text: label(picked) }),
    region && { text: region },
  ].filter(Boolean)

  const range = subGeo ? [rLo, rHi] : [lo, hi]
  const hasRange = Number.isFinite(range[0]) && Number.isFinite(range[1])
  const title = region || (picked ? label(picked) : '')

  return (
    <div className="pc">
      <div className="pc-map">
        <MapContainer center={[7.8, 80.7]} zoom={7} minZoom={6} maxZoom={11} zoomSnap={0.25} scrollWheelZoom={false} zoomControl={false} attributionControl={false} style={{ height: '100%', width: '100%', background: '#f1f6f3' }}>
          <GeoJSON key={sig} data={geo} style={style} onEachFeature={onEach} />
          {!subGeo && preview && <GeoJSON key="preview" data={preview} interactive={false} style={() => ({ fill: false, weight: 1.2, color: '#ffffff', opacity: 0.95, dashArray: '3 3' })} />}
          {subGeo && <GeoJSON key={`${sig}|${region}`} data={subGeo} style={subStyle} onEachFeature={subEach} />}
          <Fit geo={geo} focus={subGeo ? pickedKey : null} />
        </MapContainer>
        <div className="an-map-crumbs">
          {crumbs.map((c, i) => (
            <span key={i}>
              {i > 0 && <i>›</i>}
              {c.go && i < crumbs.length - 1 ? <button onClick={c.go}>{c.text}</button> : <b>{c.text}</b>}
            </span>
          ))}
        </div>
        <div className="pc-legend">
          <div className="pc-prov">
            {Object.entries(PROVINCE_COLORS).map(([n, c]) => (
              <span key={n}><i style={{ background: c }} />{n}</span>
            ))}
          </div>
          <div className="pc-ramp-l"><span>{hasRange ? `Darker = higher price (${lkr(range[0])} to ${lkr(range[1])}). Palest = no price yet` : 'Darker = higher price. Palest = no price yet'}</span></div>
        </div>
        {!picked && <div className="pc-hint">Tap a district to see its coconut price</div>}
        {subGeo && !region && <div className="pc-hint">{subGeo.features.length} regions in {label(picked)}. Tap one</div>}
      </div>

      <div className="pc-stage">
        {error && <div className="pc-note">Prices could not be loaded ({error}). Check that the backend is running and you are signed in.</div>}
        {!picked && !error && (
          <div className="pc-idle">
            <Coconut small />
            <p>Select a district on the map</p>
          </div>
        )}
        {picked && (
          <div className="pc-show" key={`${picked}|${region}`}>
            <Coconut />
            <div className="pc-info">
              <small>{region ? `Average coconut price · ${label(picked)}` : 'Average coconut price'}</small>
              <h3>{title}</h3>
              {current && current.avg != null ? (
                <>
                  <b className="pc-price"><i>LKR</i>{price.toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</b>
                  <span className="pc-per">per nut</span>
                  <div className="pc-chips">
                    <em>Low {lkr(current.min)}</em>
                    <em>High {lkr(current.max)}</em>
                    <em>
                      {current.source === 'deals'
                        ? `${current.samples} listings and deals`
                        : current.source === 'district'
                          ? 'District average, no deals here yet'
                          : 'Price band estimate'}
                    </em>
                  </div>
                </>
              ) : (
                <p className="pc-none">No price has been published for this district yet.</p>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

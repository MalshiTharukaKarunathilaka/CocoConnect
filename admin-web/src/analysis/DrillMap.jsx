import { useEffect, useMemo, useState } from 'react'
import { CircleMarker, GeoJSON, MapContainer, Marker, TileLayer, Tooltip, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { DISTRICTS, PROVINCE_COLORS, label, pointIn, provinceOf, rampOf } from './data'
import { glyphHtml, pinIcon } from './pins'
import ForestLayer, { COVER_2000, FIRST_YEAR, CURRENT_YEAR, IMAGERY, LAST_YEAR, PROJ_END } from './ForestLayer'

// The projection is a sample: each registered land is assumed to plant 8% of its area in new trees every year after 2026.
const GROWTH_PER_YEAR = 0.08

export const GREEN_SCALE = ['#e3f0e6', '#bcdcc6', '#86be9c', '#4f9a6f', '#256b45']
const OFF = '#e9eeec'
const colorFor = (v, max, scale, min = 0) => {
  if (!max || v <= 0) return scale[0]
  const span = max - min
  const t = min > 0 ? (span > 0 ? (v - min) / span : 0.5) : v / max
  const i = Math.min(scale.length - 1, Math.max(0, Math.floor(t * scale.length * 0.999)))
  return scale[i]
}

function Fitter({ geo, sel, padLeft = 16 }) {
  const map = useMap()
  useEffect(() => {
    map.invalidateSize()
    const feats = geo.features.filter((f) => (sel.district ? f.properties.district === sel.district : !sel.province || provinceOf(f.properties.district) === sel.province))
    const bounds = L.geoJSON({ type: 'FeatureCollection', features: feats }).getBounds()
    map.fitBounds(bounds, { paddingTopLeft: [padLeft, 16], paddingBottomRight: [16, 16], animate: true, maxZoom: sel.district ? 11 : 10 })
  }, [map, geo, sel.province, sel.district, padLeft])
  return null
}

// Districts that can be split further. Only Kurunegala for now: 10 CDO areas.
const SUB_FILES = { Kurunegala: '/geo/kurunegala-cdo.json' }
const subCache = {}
const loadSub = (district) => (subCache[district] ||= fetch(SUB_FILES[district]).then((r) => r.json()))
const ringArea = (ring) => Math.abs(ring.reduce((a, p, i) => a + (p[0] * ring[(i + 1) % ring.length][1] - ring[(i + 1) % ring.length][0] * p[1]), 0) / 2)
const jitter = (n) => 0.75 + ((Math.sin(n * 91.7) * 10000) % 1 + 1) % 1 * 0.5

/**
 * Sri Lanka choropleth that drills down: island -> province -> district.
 * `values` is {districtName: number}. `markers` are optional dots on top.
 */
export default function DrillMap({
  geo,
  values,
  fmt = (v) => String(v),
  unit = '',
  sel,
  onSel,
  scale = GREEN_SCALE,
  markers = [],
  markerKey,
  height = 520,
  legend = [],
  overlay = null,
  agg = 'sum', // 'avg' when the values are prices
  cdoValues = null, // optional {areaName: value} for the CDO areas
  badge = null, // { html: (value, name, index) => string }: a picture and the amount on every area
  noSub = false, // true: stop at the district, no CDO areas
  forest = false, // true: adds a satellite view with forest cover and a year slider
  onYear = null, // called with the selected timeline year
  greenery = false, // true: the timeline is worded as coconut land greenery instead of forest
  forestInfo = null, // (year, projected) => node shown in the timeline panel, e.g. carbon figures for that year
}) {
  const [tiles, setTiles] = useState(false)
  const [forestOn, setForestOn] = useState(false)
  const [year, setYear] = useState(CURRENT_YEAR)
  const [playing, setPlaying] = useState(false)
  const [forestErr, setForestErr] = useState(false)
  const sat = forest && forestOn
  useEffect(() => {
    if (!playing) return undefined
    const t = setInterval(() => setYear((y) => (y >= PROJ_END ? (setPlaying(false), PROJ_END) : y + 1)), 650)
    return () => clearInterval(t)
  }, [playing])
  const startPlay = () => {
    if (year >= PROJ_END) setYear(FIRST_YEAR)
    setPlaying(!playing)
  }
  useEffect(() => { if (onYear) onYear(year) }, [year]) // eslint-disable-line react-hooks/exhaustive-deps
  const projected = year > CURRENT_YEAR
  const grown = projected ? markers.filter((m) => !m.dim && m.acres) : []
  const newAcres = Math.round(grown.reduce((a, m) => a + m.acres, 0) * GROWTH_PER_YEAR * (year - CURRENT_YEAR))
  const level = sel.district ? 2 : sel.province ? 1 : 0
  const [legendOpen, setLegendOpen] = useState(true)
  useEffect(() => { setLegendOpen(level === 0) }, [level]) // zoomed in, the legend folds so it does not hide lands
  const [subGeo, setSubGeo] = useState(null)
  const region = sel.region || null
  const setRegion = (name) => onSel(name ? { province: sel.province, district: sel.district, region: name } : { province: sel.province, district: sel.district })
  const subDistrict = !noSub && sel.district && SUB_FILES[sel.district] ? sel.district : null
  useEffect(() => {
    if (!subDistrict) return setSubGeo(null)
    let live = true
    loadSub(subDistrict).then((g) => live && setSubGeo(g)).catch(() => live && setSubGeo(null))
    return () => { live = false }
  }, [subDistrict])

  // value of each region: its share of the district, from the pins inside it (or its area if there are none)
  const subCalc = useMemo(() => {
    if (!subGeo) return {}
    const total = values[subDistrict] || 0
    const feats = subGeo.features
    const counts = feats.map((f) => markers.filter((m) => pointIn(f.geometry.coordinates[0], m.lng, m.lat)).length)
    const useCounts = counts.some((c) => c > 0)
    const weights = feats.map((f, i) => (useCounts ? counts[i] : ringArea(f.geometry.coordinates[0]) * jitter(f.properties.id)))
    const sum = weights.reduce((a, b) => a + b, 0) || 1
    return Object.fromEntries(feats.map((f, i) => [f.properties.region, (total * weights[i]) / sum]))
  }, [subGeo, subDistrict, values, markers])
  const subValues = cdoValues || subCalc
  const subMax = Math.max(...Object.values(subValues), 0)

  const provTotals = useMemo(() => {
    const t = {}
    const n = {}
    for (const d of DISTRICTS) {
      t[d.province] = (t[d.province] || 0) + (values[d.name] || 0)
      if (values[d.name] > 0) n[d.province] = (n[d.province] || 0) + 1
    }
    if (agg === 'avg') for (const p of Object.keys(t)) t[p] = n[p] ? t[p] / n[p] : 0
    return t
  }, [values, agg])

  // One badge per area that is in view: provinces, then the districts of a province, then CDO areas.
  const badges = useMemo(() => {
    if (!badge) return []
    const centreOf = (feats) => {
      const cs = feats.map((f) => f.properties.c).filter(Boolean)
      const mid = [cs.reduce((a, c) => a + c[0], 0) / cs.length, cs.reduce((a, c) => a + c[1], 0) / cs.length]
      // the average of the centres can fall in a neighbouring province, so use the district centre nearest to it: the badge then sits inside its own province
      return cs.reduce((best, c) => (Math.hypot(c[0] - mid[0], c[1] - mid[1]) < Math.hypot(best[0] - mid[0], best[1] - mid[1]) ? c : best), cs[0])
    }
    const out = []
    if (level === 0) {
      Object.keys(PROVINCE_COLORS).forEach((p) => {
        const feats = geo.features.filter((f) => provinceOf(f.properties.district) === p)
        if (feats.length) out.push({ name: p, pos: centreOf(feats), value: provTotals[p] || 0, go: () => onSel({ province: p }) })
      })
    } else if (!sel.district) {
      geo.features.filter((f) => provinceOf(f.properties.district) === sel.province).forEach((f) => {
        const name = f.properties.district
        out.push({ name: label(name), pos: f.properties.c, value: values[name] || 0, go: () => onSel({ province: sel.province, district: name }) })
      })
    } else if (subGeo && !region) {
      subGeo.features.forEach((f) => {
        const name = f.properties.region
        out.push({ name, pos: f.properties.c, value: subValues[name] || 0, go: () => setRegion(name) })
      })
    } else if (subGeo && region) {
      const f = subGeo.features.find((x) => x.properties.region === region)
      if (f) out.push({ name: region, pos: f.properties.c, value: subValues[region] || 0, go: () => setRegion(null) })
    } else {
      const f = geo.features.find((x) => x.properties.district === sel.district)
      if (f) out.push({ name: label(sel.district), pos: f.properties.c, value: values[sel.district] || 0, go: () => {} })
    }
    return out.filter((b) => b.pos)
  }, [badge, level, geo, sel.province, sel.district, region, subGeo, values, subValues]) // eslint-disable-line

  const max = useMemo(() => {
    if (level === 0) return Math.max(...Object.values(provTotals), 0)
    return Math.max(...DISTRICTS.filter((d) => d.province === sel.province).map((d) => values[d.name] || 0), 0)
  }, [level, provTotals, values, sel.province])

  // For averages (prices) the values are all close together, so spread the colours between the lowest and highest.
  const lowest = (list) => {
    if (agg !== 'avg') return 0
    const v = list.filter((x) => x > 0)
    return v.length ? Math.min(...v) : 0
  }
  const min = level === 0 ? lowest(Object.values(provTotals)) : lowest(DISTRICTS.filter((d) => d.province === sel.province).map((d) => values[d.name] || 0))
  const subMin = lowest(Object.values(subValues))

  const sig = Object.values(values).join(',')
  const key = `${level}|${sel.province}|${sel.district}|${sig}|${tiles}|${sat}`
  const subKey = `${subDistrict}|${Object.values(subValues).join(',')}|${tiles}|${sat}`

  const rampFor = (prov) => rampOf(PROVINCE_COLORS[prov])
  // over the satellite picture the areas are only outlined, so the forest shows through
  const style = (f) => {
    const s = style0(f)
    return sat ? { ...s, fillOpacity: s.fillColor === OFF ? 0.45 : 0.04, color: '#ffffff', weight: s.weight < 1.2 ? 1.2 : s.weight } : s
  }
  const style0 = (f) => {
    const name = f.properties.district
    const prov = provinceOf(name)
    const base = { weight: 0.8, color: '#ffffff', fillOpacity: tiles ? 0.62 : 0.95 }
    if (level === 0) return { ...base, fillColor: colorFor(provTotals[prov], max, rampFor(prov), min) }
    if (prov !== sel.province) return { ...base, fillColor: OFF, fillOpacity: tiles ? 0.25 : 0.8 }
    const chosen = sel.district === name
    if (chosen && subGeo) return { ...base, fillColor: rampFor(prov)[0], fillOpacity: 0.3, weight: 2.5, color: '#15201a' }
    return {
      ...base,
      fillColor: PROVINCE_COLORS[prov], // the whole province in its own colour; the badges carry the values
      weight: chosen ? 3 : 1.2,
      color: chosen ? '#15201a' : '#ffffff',
    }
  }

  const onEach = (f, layer) => {
    const name = f.properties.district
    const prov = provinceOf(name)
    const showProv = level === 0 || prov !== sel.province
    const text = showProv
      ? `<b>${prov} Province</b><br/>${fmt(provTotals[prov] || 0)} ${unit}`
      : `<b>${label(name)}</b><br/>${fmt(values[name] || 0)} ${unit}`
    layer.bindTooltip(text, { sticky: true, direction: 'top' })
    layer.on({
      click: () => (showProv ? onSel({ province: prov }) : onSel({ province: prov, district: name })),
      mouseover: () => layer.setStyle({ weight: 2.5, color: '#15201a' }),
      mouseout: () => layer.setStyle(style(f)),
    })
  }

  const crumbs = [
    { text: 'Sri Lanka', go: () => onSel({}) },
    sel.province && { text: sel.province, go: () => onSel({ province: sel.province }) },
    sel.district && (region ? { text: label(sel.district), go: () => setRegion(null) } : { text: label(sel.district) }),
    region && { text: region },
  ].filter(Boolean)

  return (
    <div className="an-map" style={{ minHeight: height }}>
      <MapContainer
        center={[7.8, 80.7]}
        zoom={7}
        minZoom={6}
        maxZoom={11}
        zoomSnap={0.25}
        scrollWheelZoom={false}
        zoomControl={false}
        attributionControl={tiles || sat}
        style={{ height: '100%', width: '100%', background: sat ? '#10261a' : tiles ? '#dfe7e3' : '#f1f6f3' }}
      >
        {tiles && !sat && <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution="© OpenStreetMap" />}
        {sat && <TileLayer url={IMAGERY} maxNativeZoom={17} zIndex={1} />}
        {sat && <TileLayer url={COVER_2000} maxNativeZoom={12} zIndex={2} opacity={0.75} />}
        {sat && <ForestLayer year={Math.min(year, LAST_YEAR)} onError={() => setForestErr(true)} onReady={() => setForestErr(false)} />}
        {sat && grown.map((m, i) => (
          <CircleMarker
            key={`grow-${i}`} center={[m.lat, m.lng]} interactive={false}
            radius={((m.size || 24) / 2) * (0.25 + (0.75 * (year - CURRENT_YEAR)) / (PROJ_END - CURRENT_YEAR))}
            pathOptions={{ color: '#7dff9a', weight: 1.5, fillColor: '#3ddc6a', fillOpacity: 0.42 }}
          />
        ))}
        <GeoJSON key={key} data={geo} style={style} onEachFeature={onEach} />
        {subGeo && (
          <GeoJSON
            key={`${subKey}|${region}`}
            data={subGeo}
            style={(f) => {
              const on = region === f.properties.region
              return {
                weight: on ? 3.5 : 1.6,
                color: on ? '#15201a' : '#ffffff',
                fillOpacity: sat ? 0.08 : tiles ? 0.7 : 0.97,
                fillColor: colorFor(subValues[f.properties.region] || 0, subMax, rampFor(provinceOf(subDistrict)), subMin),
              }
            }}
            onEachFeature={(f, layer) => {
              const name = f.properties.region
              layer.bindTooltip(`<b>${name}</b><br/>${fmt(subValues[name] || 0)} ${unit}`, { sticky: true, direction: 'top' })
              layer.on({
                click: () => setRegion(region === name ? null : name),
                mouseover: () => layer.setStyle({ weight: 3, color: '#15201a' }),
                mouseout: () => layer.setStyle({ weight: region === name ? 3.5 : 1.6, color: region === name ? '#15201a' : '#ffffff' }),
              })
            }}
          />
        )}
        {/* each CDO area has its office, shown as a house at the area's centre */}
        {subGeo && subGeo.features.filter((f) => f.properties.c && (!region || f.properties.region === region)).map((f) => (
          <Marker
            key={`cdo-office-${f.properties.region}`}
            position={[f.properties.c[0] - 0.012, f.properties.c[1] + 0.012]}
            zIndexOffset={900}
            icon={pinIcon('house', '#b4531f', 30, false)}
            eventHandlers={{ click: () => setRegion(region === f.properties.region ? null : f.properties.region) }}
          >
            <Tooltip direction="top" offset={[0, -26]}><b>CDO office</b><br />{f.properties.region}</Tooltip>
          </Marker>
        ))}
        {badges.map((b, i) => (
          <Marker
            key={`badge-${level}-${b.name}-${i}`}
            position={b.pos}
            zIndexOffset={800}
            icon={L.divIcon({ html: `<div class="an-badge">${badge.html(b.value, b.name, i)}</div>`, className: 'an-badge-wrap', iconSize: [96, 90], iconAnchor: [48, 84] })}
            eventHandlers={{ click: b.go }}
          >
            <Tooltip direction="top" offset={[0, -78]}>{b.name}</Tooltip>
          </Marker>
        ))}
        {markers.map((m, i) => (
          <Marker
            key={`${markerKey}-${i}`}
            position={[m.lat, m.lng]}
            icon={pinIcon(m.icon || 'palm', m.color, m.size || 26, m.dim, m.label)}
            eventHandlers={m.onClick ? { click: m.onClick } : undefined}
          >
            <Tooltip direction="top" offset={[0, -12]}>{m.tip}</Tooltip>
          </Marker>
        ))}
        <Fitter geo={geo} sel={sel} padLeft={sat && forestInfo ? 350 : 16} />
      </MapContainer>

      <div className="an-map-crumbs">
        {crumbs.map((c, i) => (
          <span key={i}>
            {i > 0 && <i>›</i>}
            {c.go && i < crumbs.length - 1 ? <button onClick={c.go}>{c.text}</button> : <b>{c.text}</b>}
          </span>
        ))}
      </div>
      <button className={`an-map-tiles ${tiles ? 'on' : ''}`} onClick={() => setTiles(!tiles)}>
        {tiles ? 'Street map: on' : 'Street map'}
      </button>
      {forest && (
        <button className={`an-map-tiles an-map-forest ${sat ? 'on' : ''}`} onClick={() => { setForestOn(!forestOn); setPlaying(false) }}>
          {sat ? (greenery ? 'Coconut greenery: on' : 'Forest timeline: on') : (greenery ? 'Coconut greenery' : 'Forest timeline')}
        </button>
      )}
      {sat && (
        <div className={`an-forest ${forestInfo ? 'dock' : ''}`}>
          <div className="an-forest-l">
          <div className="an-forest-top">
            <button type="button" className="an-forest-play" onClick={startPlay} aria-label={playing ? 'Pause' : 'Play'}>{playing ? '❚❚' : '▶'}</button>
            <div>
              <b>{projected ? (greenery ? `Coconut land greenery by ${year}` : `Projected green by ${year}`) : (greenery ? `Greenery lost by ${year}` : `Tree cover lost by ${year}`)}</b>
              <span>{projected ? (greenery ? 'A projection for registered coconut lands, not satellite data' : 'A projection, not satellite data') : (greenery ? `Satellite view of all trees around the lands, 2001 to ${LAST_YEAR}` : `Satellite data, 2001 to ${LAST_YEAR}`)}</span>
            </div>
          </div>
          <input type="range" min={FIRST_YEAR} max={PROJ_END} step={1} value={year} onChange={(e) => { setPlaying(false); setYear(Number(e.target.value)) }} />
          <div className="an-forest-years"><span>{FIRST_YEAR}</span><span style={{ position: 'absolute', left: `${((CURRENT_YEAR - FIRST_YEAR) / (PROJ_END - FIRST_YEAR)) * 100}%`, transform: 'translateX(-50%)' }}>{CURRENT_YEAR} · now</span><span>{PROJ_END}</span></div>
          <div className="an-forest-key">
            <span><i style={{ background: '#00b300' }} />{greenery ? 'Green cover in 2000' : 'Forest in 2000'}</span>
            <span><i style={{ background: '#e83e28' }} />Lost by {Math.min(year, LAST_YEAR + 1) - 1}</span>
            <span><i style={{ background: '#ffd60a' }} />Lost in {Math.min(year, LAST_YEAR)}</span>
            {projected && <span><i style={{ background: '#3ddc6a' }} />{greenery ? 'New coconut planting on registered lands' : 'New planting on registered lands'}</span>}
          </div>
          {projected && (
            <p className="an-forest-proj">
              <b>+{newAcres.toLocaleString('en-US')} acres</b> of new {greenery ? 'coconut greenery' : 'green'} by {year}
              <small>Sample projection: each land in view plants 8% of its area in new trees every year after {CURRENT_YEAR}.</small>
            </p>
          )}
          </div>
          {forestInfo && forestInfo(year, projected)}
          {forestErr && <p className="an-forest-err">Could not load the forest layer. Check the internet connection.</p>}
        </div>
      )}
      {overlay}
      <div className="an-map-hint">
        {level === 0 ? 'Click a province to drill down' : level === 1 ? 'Click a district to pinpoint' : subGeo ? `${subGeo.features.length} CDO areas in ${label(subDistrict)}. Click an area to pinpoint` : 'Use the path at the top-left to go back'}
      </div>

      <div className="an-map-legend" style={sat ? { display: 'none' } : undefined}>
        <button type="button" className="an-leg-toggle" onClick={() => setLegendOpen(!legendOpen)} aria-expanded={legendOpen}>
          <b>Legend</b><span aria-hidden>{legendOpen ? '▾' : '▸'}</span>
        </button>
        {legendOpen && <>
        <div className="an-ramp">
          {(sel.province ? rampFor(sel.province) : ['#e6ebe8', '#c3cdc8', '#98a69f', '#6c7f76', '#43544c']).map((c) => (
            <span key={c} style={{ background: c }} />
          ))}
        </div>
        <div className="an-ramp-l">
          <span>Less</span>
          <span>{fmt(max)} {unit}</span>
        </div>
        <div className="an-prov-legend">
          {Object.entries(PROVINCE_COLORS).map(([p, c]) => (
            <button type="button" key={p} className={sel.province === p ? 'on' : ''} onClick={() => onSel(sel.province === p && !sel.district ? {} : { province: p })} title={`Show ${p} Province`}><i style={{ background: c }} />{p}</button>
          ))}
        </div>
        {legend.map((l) => (
          <div key={l.text} className="an-leg-row">
            {l.icon ? <span className="an-leg-ic" dangerouslySetInnerHTML={{ __html: glyphHtml(l.icon, l.color, 24) }} /> : <i style={{ background: l.color }} />} {l.text}
          </div>
        ))}
        {subGeo && subGeo.features.some((f) => f.properties.c) && (
          <div className="an-leg-row">
            <span className="an-leg-ic" dangerouslySetInnerHTML={{ __html: glyphHtml('house', '#b4531f', 24) }} /> CDO office
          </div>
        )}
        </>}
      </div>
    </div>
  )
}

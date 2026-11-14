import { useEffect, useMemo, useState } from 'react'
import { GeoJSON, MapContainer, Marker, TileLayer, Tooltip, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { DISTRICTS, PROVINCE_COLORS, label, pointIn, provinceOf, rampOf } from './data'
import { glyphHtml, pinIcon } from './pins'

export const GREEN_SCALE = ['#e3f0e6', '#bcdcc6', '#86be9c', '#4f9a6f', '#256b45']
const OFF = '#e9eeec'
const colorFor = (v, max, scale, min = 0) => {
  if (!max || v <= 0) return scale[0]
  const span = max - min
  const t = min > 0 ? (span > 0 ? (v - min) / span : 0.5) : v / max
  const i = Math.min(scale.length - 1, Math.max(0, Math.floor(t * scale.length * 0.999)))
  return scale[i]
}

function Fitter({ geo, sel }) {
  const map = useMap()
  useEffect(() => {
    map.invalidateSize()
    const feats = geo.features.filter((f) => (sel.district ? f.properties.district === sel.district : !sel.province || provinceOf(f.properties.district) === sel.province))
    const bounds = L.geoJSON({ type: 'FeatureCollection', features: feats }).getBounds()
    map.fitBounds(bounds, { padding: [16, 16], animate: true, maxZoom: sel.district ? 11 : 10 })
  }, [map, geo, sel.province, sel.district])
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
}) {
  const [tiles, setTiles] = useState(false)
  const level = sel.district ? 2 : sel.province ? 1 : 0
  const [subGeo, setSubGeo] = useState(null)
  const region = sel.region || null
  const setRegion = (name) => onSel(name ? { province: sel.province, district: sel.district, region: name } : { province: sel.province, district: sel.district })
  const subDistrict = sel.district && SUB_FILES[sel.district] ? sel.district : null
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
      return [cs.reduce((a, c) => a + c[0], 0) / cs.length, cs.reduce((a, c) => a + c[1], 0) / cs.length]
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
  const key = `${level}|${sel.province}|${sel.district}|${sig}|${tiles}`
  const subKey = `${subDistrict}|${Object.values(subValues).join(',')}|${tiles}`

  const rampFor = (prov) => rampOf(PROVINCE_COLORS[prov])
  const style = (f) => {
    const name = f.properties.district
    const prov = provinceOf(name)
    const base = { weight: 0.8, color: '#ffffff', fillOpacity: tiles ? 0.62 : 0.95 }
    if (level === 0) return { ...base, fillColor: colorFor(provTotals[prov], max, rampFor(prov), min) }
    if (prov !== sel.province) return { ...base, fillColor: OFF, fillOpacity: tiles ? 0.25 : 0.8 }
    const chosen = sel.district === name
    if (chosen && subGeo) return { ...base, fillColor: rampFor(prov)[0], fillOpacity: 0.3, weight: 2.5, color: '#15201a' }
    return {
      ...base,
      fillColor: colorFor(values[name] || 0, max, rampFor(prov), min),
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
        attributionControl={tiles}
        style={{ height: '100%', width: '100%', background: tiles ? '#dfe7e3' : '#f1f6f3' }}
      >
        {tiles && <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" attribution="© OpenStreetMap" />}
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
                fillOpacity: tiles ? 0.7 : 0.97,
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
        <Fitter geo={geo} sel={sel} />
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
      {overlay}
      <div className="an-map-hint">
        {level === 0 ? 'Click a province to drill down' : level === 1 ? 'Click a district to pinpoint' : subGeo ? `${subGeo.features.length} CDO areas in ${label(subDistrict)}. Click an area to pinpoint` : 'Use the path at the top-left to go back'}
      </div>

      <div className="an-map-legend">
        <div className="an-ramp">
          {(sel.province ? rampFor(sel.province) : ['#e6ebe8', '#c3cdc8', '#98a69f', '#6c7f76', '#43544c']).map((c) => (
            <span key={c} style={{ background: c }} />
          ))}
        </div>
        <div className="an-ramp-l">
          <span>Less</span>
          <span>{fmt(max)} {unit}</span>
        </div>
        {level === 0 && (
          <div className="an-prov-legend">
            {Object.entries(PROVINCE_COLORS).map(([p, c]) => (
              <span key={p}><i style={{ background: c }} />{p}</span>
            ))}
          </div>
        )}
        {legend.map((l) => (
          <div key={l.text} className="an-leg-row">
            {l.icon ? <span className="an-leg-ic" dangerouslySetInnerHTML={{ __html: glyphHtml(l.icon, l.color, 24) }} /> : <i style={{ background: l.color }} />} {l.text}
          </div>
        ))}
      </div>
    </div>
  )
}

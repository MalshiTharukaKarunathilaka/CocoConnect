import { useEffect, useMemo, useState } from 'react'
import { GeoJSON, MapContainer, Marker, TileLayer, Tooltip, useMap } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { DISTRICTS, PROVINCE_COLORS, label, provinceOf, rampOf } from './data'
import { glyphHtml, pinIcon } from './pins'

export const GREEN_SCALE = ['#e3f0e6', '#bcdcc6', '#86be9c', '#4f9a6f', '#256b45']
const OFF = '#e9eeec'
const colorFor = (v, max, scale) => {
  if (!max || v <= 0) return scale[0]
  const i = Math.min(scale.length - 1, Math.floor((v / max) * scale.length * 0.999))
  return scale[i]
}

function Fitter({ geo, sel }) {
  const map = useMap()
  useEffect(() => {
    map.invalidateSize()
    const feats = geo.features.filter((f) => !sel.province || provinceOf(f.properties.district) === sel.province)
    const bounds = L.geoJSON({ type: 'FeatureCollection', features: feats }).getBounds()
    map.fitBounds(bounds, { padding: [16, 16], animate: true, maxZoom: 10 })
  }, [map, geo, sel.province])
  return null
}

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
}) {
  const [tiles, setTiles] = useState(false)
  const level = sel.district ? 2 : sel.province ? 1 : 0

  const provTotals = useMemo(() => {
    const t = {}
    for (const d of DISTRICTS) t[d.province] = (t[d.province] || 0) + (values[d.name] || 0)
    return t
  }, [values])

  const max = useMemo(() => {
    if (level === 0) return Math.max(...Object.values(provTotals), 0)
    return Math.max(...DISTRICTS.filter((d) => d.province === sel.province).map((d) => values[d.name] || 0), 0)
  }, [level, provTotals, values, sel.province])

  const sig = Object.values(values).join(',')
  const key = `${level}|${sel.province}|${sel.district}|${sig}|${tiles}`

  const rampFor = (prov) => rampOf(PROVINCE_COLORS[prov])
  const style = (f) => {
    const name = f.properties.district
    const prov = provinceOf(name)
    const base = { weight: 0.8, color: '#ffffff', fillOpacity: tiles ? 0.62 : 0.95 }
    if (level === 0) return { ...base, fillColor: colorFor(provTotals[prov], max, rampFor(prov)) }
    if (prov !== sel.province) return { ...base, fillColor: OFF, fillOpacity: tiles ? 0.25 : 0.8 }
    const chosen = sel.district === name
    return {
      ...base,
      fillColor: colorFor(values[name] || 0, max, rampFor(prov)),
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
    sel.district && { text: label(sel.district) },
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
        {markers.map((m, i) => (
          <Marker
            key={`${markerKey}-${i}`}
            position={[m.lat, m.lng]}
            icon={pinIcon(m.icon || 'palm', m.color, m.size || 26, m.dim)}
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
      <div className="an-map-hint">
        {level === 0 ? 'Click a province to drill down' : level === 1 ? 'Click a district to pinpoint' : 'Use the path at the top-left to go back'}
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

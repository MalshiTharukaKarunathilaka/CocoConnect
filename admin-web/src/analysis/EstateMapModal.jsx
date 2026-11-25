import { useEffect, useMemo, useState } from 'react'
import { MapContainer, Marker, Polygon, Polyline, TileLayer, Tooltip, useMap, useMapEvents } from 'react-leaflet'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { IMAGERY } from './ForestLayer'
import { Modal, Segmented } from './ui'
import { label } from './data'

/**
 * The estate map an owner draws in the mobile app, shown to the admin as a popup: the real shape of the land,
 * a grid, and one mark per plant, with the same plant types, icons, age bands and severities as the app.
 * Sample layout: this dashboard's lands are sample data, so the shape and the marks are made up from the land's
 * id and size. When the apps' saved maps reach the dashboard, this reads those instead.
 */

// The same plant types, icons and groups as the mobile app (lib/models/estate_plants.dart).
const KINDS = [
  { id: 'coconut', name: 'Coconut tree', note: 'Tall coconut', group: 'crop', color: '#2f8a4f', img: '/plants/coconut.png', scale: 1.5 },
  { id: 'king', name: 'King coconut', note: 'Orange thambili', group: 'crop', color: '#d99a0b', img: '/plants/king.png', scale: 1 },
  { id: 'pepper', name: 'Pepper', note: 'Climbs the coconut trees', group: 'crop', color: '#9c2a23', img: '/plants/pepper.png', scale: 1 },
  { id: 'banana', name: 'Banana', note: 'Intercrop', group: 'crop', color: '#c9a800', img: '/plants/banana.png', scale: 1 },
  { id: 'cinnamon', name: 'Cinnamon', note: 'Spice tree', group: 'crop', color: '#8b5a2b', img: '/plants/cinnamon.png', scale: 1 },
  { id: 'cocoa', name: 'Cocoa', note: 'Shade-loving', group: 'crop', color: '#d2691e', img: '/plants/cocoa.png', scale: 1 },
  { id: 'guinea', name: 'Guinea grass', note: 'Spreads fast under coconut trees', group: 'invasive', color: '#6b8e23', img: '/plants/guinea.png', scale: 1 },
  { id: 'mana', name: 'Mana grass', note: 'Takes over open ground', group: 'invasive', color: '#7d9a1f', img: '/plants/mana.png', scale: 1 },
  { id: 'mite', name: 'Coconut mite', note: 'Scars and shrinks the nuts', group: 'pest', color: '#b08a3e', img: '/plants/mite.png', scale: 1 },
  { id: 'whitefly', name: 'Whitefly', note: 'White coating on the fronds', group: 'pest', color: '#c9a100', img: '/plants/whitefly.png', scale: 1 },
]
const KIND = Object.fromEntries(KINDS.map((k) => [k.id, k]))
const GROUPS = [['all', 'All'], ['crop', 'Trees and crops'], ['invasive', 'Invasive plants'], ['pest', 'Pests']]
// The same age bands as the admin's tree-age chart and the app.
const AGES = [
  ['0-5', 'Seedling'], ['6-15', 'Young tree'], ['16-25', 'Early bearing'], ['26-40', 'Prime bearing'],
  ['41-50', 'Mature'], ['51-60', 'Aged'], ['61+', 'Old tree'],
]
const SEV = { Low: '#6b8e23', Medium: '#e08a1e', High: '#c62828' }
const PENDING = 'Pending validation'
// The demo lands' coordinates fall in towns, so the satellite view shows houses and roads. Like the app's demo, the sample
// map is drawn over open green farmland instead, so the grid and the plants are easy to read.
const FARMLAND = { lat: 7.63287, lng: 79.93257 }

const rngOf = (seed) => {
  let a = seed | 0
  return () => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const inPoly = (pts, x, y) => {
  let inside = false
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j]
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside
  }
  return inside
}
const edgeDist = (pts, x, y) => {
  let best = Infinity
  for (let i = 0; i < pts.length; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[(i + 1) % pts.length]
    const dx = bx - ax, dy = by - ay
    const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)))
    best = Math.min(best, Math.hypot(x - (ax + t * dx), y - (ay + t * dy)))
  }
  return best
}
const areaOf = (pts) => {
  let s = 0
  for (let i = 0; i < pts.length; i++) { const [ax, ay] = pts[i], [bx, by] = pts[(i + 1) % pts.length]; s += ax * by - bx * ay }
  return Math.abs(s) / 2
}

/** Grid lines (metres) cut to the shape with a scanline, so the grid follows the real boundary. */
function gridLines(pts, step) {
  const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1])
  const [x0, x1, y0, y1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)]
  const out = []
  const cut = (fixed, axis) => {
    const hits = []
    for (let i = 0; i < pts.length; i++) {
      const a = pts[i], b = pts[(i + 1) % pts.length]
      const [pa, pb, qa, qb] = axis === 'x' ? [a[0], b[0], a[1], b[1]] : [a[1], b[1], a[0], b[0]]
      if ((pa > fixed) !== (pb > fixed)) hits.push(qa + ((fixed - pa) / (pb - pa)) * (qb - qa))
    }
    hits.sort((p, q) => p - q)
    for (let i = 0; i + 1 < hits.length; i += 2) out.push(axis === 'x' ? [[fixed, hits[i]], [fixed, hits[i + 1]]] : [[hits[i], fixed], [hits[i + 1], fixed]])
  }
  for (let x = Math.ceil(x0 / step) * step; x < x1; x += step) cut(x, 'x')
  for (let y = Math.ceil(y0 / step) * step; y < y1; y += step) cut(y, 'y')
  return out
}

const NOTES = { guinea: ['Spreading under the coconut trees', 'Cut back last month'], mana: ['Coming in from the track side'], mite: ['Nuts are scarred'], whitefly: ['White coating on the fronds'], pepper: ['Climbing the coconut tree'] }

function layoutOf(e) {
  const seed = Number(String(e.id).replace(/\D/g, '')) * 2654435 + 97
  const rnd = rngOf(seed)
  const jit = (a) => (rnd() - 0.5) * 2 * a
  const acres = Math.max(0.8, e.acres || 3)
  // an irregular shape of the right area
  const corners = 5 + Math.floor(rnd() * 3)
  const raw = Array.from({ length: corners }, (_, i) => {
    const ang = ((i + 0.15 * jit(1)) / corners) * Math.PI * 2
    return [Math.cos(ang) * (0.78 + rnd() * 0.4), Math.sin(ang) * (0.78 + rnd() * 0.4) * (0.8 + rnd() * 0.3)]
  })
  const k = Math.sqrt((acres * 4046.86) / areaOf(raw))
  const outline = raw.map(([x, y]) => [x * k, y * k])
  const xs = outline.map((p) => p[0]), ys = outline.map((p) => p[1])
  const span = Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys))
  const step = [5, 10, 20, 25, 50, 100, 200, 500].find((s) => s >= span / 6) || 500
  const base = new Date(e.registeredOn || '2025-06-01').getTime()
  const marks = []
  const place = (kind, cx, cy, n, r, gap, extra = {}) => {
    const placed = []
    for (let t = 0; t < n * 40 && placed.length < n; t++) {
      const a = rnd() * Math.PI * 2, d = Math.sqrt(rnd()) * r
      const x = cx + Math.cos(a) * d, y = cy + Math.sin(a) * d
      if (placed.some(([px, py]) => Math.hypot(px - x, py - y) < gap)) continue
      if (!inPoly(outline, x, y) || edgeDist(outline, x, y) < gap * 0.6) continue
      placed.push([x, y])
      const notes = NOTES[kind]
      marks.push({ kind, x, y, note: notes && rnd() < 0.35 ? notes[Math.floor(rnd() * notes.length)] : '', updated: new Date(base + Math.floor(rnd() * 400) * 86400000), ...extra })
    }
    return placed
  }
  const R = span / 2
  const gap = 8 // a coconut tree needs about 8 m, as in a real estate
  const cocoTotal = Math.max(10, Math.min(80, Math.round(acres * 2.4)))
  const blocks = [[-0.45, 0.35, 0.36, '41-50'], [0.4, 0.4, 0.28, '26-40'], [-0.2, -0.45, 0.22, '16-25'], [0.45, -0.3, 0.14, '6-15']]
  let first = []
  blocks.forEach(([bx, by, share, age], i) => {
    const placed = place('coconut', bx * R, by * R, Math.round(cocoTotal * share), R * 0.4, gap, { age })
    if (i === 0) first = placed
  })
  first.slice(0, Math.max(2, Math.round(cocoTotal / 9))).forEach(([x, y]) => marks.push({ kind: 'pepper', x: x + 3, y: y + 2, age: '6-15', note: 'Climbing the coconut tree', updated: new Date(base + 90 * 86400000) }))
  if (rnd() < 0.8) place('king', R * 0.15, -R * 0.1, 3 + Math.floor(rnd() * 5), R * 0.2, gap, { age: '16-25' })
  place('banana', jit(R * 0.5), -R * 0.55, 4 + Math.floor(rnd() * 4), R * 0.2, 4, { age: '0-5' })
  if (rnd() < 0.5) place('cinnamon', R * 0.5, R * 0.1, 3, R * 0.18, 5, { age: '6-15' })
  if (rnd() < 0.4) place('cocoa', -R * 0.5, -R * 0.1, 3, R * 0.18, 5, { age: '6-15' })
  const patches = 2 + Math.floor(rnd() * 3)
  for (let i = 0; i < patches; i++) place('guinea', jit(R * 0.7), jit(R * 0.7), 3 + Math.floor(rnd() * 4), R * 0.22, 5, { sev: ['Low', 'Medium', 'High'][Math.floor(rnd() * 3)] })
  if (rnd() < 0.6) place('mana', jit(R * 0.6), jit(R * 0.6), 2 + Math.floor(rnd() * 2), R * 0.18, 5, { sev: ['Medium', 'High'][Math.floor(rnd() * 2)] })
  if (rnd() < 0.75) place('mite', jit(R * 0.5), jit(R * 0.5), 1 + Math.floor(rnd() * 2), R * 0.2, gap, { sev: 'High' })
  if (rnd() < 0.55) place('whitefly', jit(R * 0.5), jit(R * 0.5), 1 + Math.floor(rnd() * 2), R * 0.2, gap, { sev: 'Low' })
  const [bx0, bx1, by0, by1] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)]
  const gx0 = Math.floor(bx0 / step) * step, gy1 = Math.ceil(by1 / step) * step
  const cols = Math.ceil((bx1 - gx0) / step), rows = Math.ceil((gy1 - by0) / step)
  marks.forEach((m, i) => {
    m.id = `M${String(i + 1).padStart(3, '0')}`
    m.status = PENDING
    m.sq = `${String.fromCharCode(65 + Math.max(0, Math.floor((m.x - gx0) / step)) % 26)}${Math.max(0, Math.floor((gy1 - m.y) / step)) + 1}` // column letter, row number
  })
  return { outline, step, marks, span, gx0, gy1, cols, rows, box: [bx0, bx1, by0, by1] }
}

function Fit({ bounds }) {
  const map = useMap()
  useEffect(() => { map.fitBounds(bounds, { padding: [24, 24] }); map.invalidateSize() }, [map, bounds])
  return null
}

const pinCache = {}
function pinFor(kind, px) {
  const k = KIND[kind]
  const key = `${kind}|${px}`
  if (!pinCache[key]) {
    const w = Math.round(px * k.scale)
    pinCache[key] = L.divIcon({
      className: 'an-em-pinwrap',
      html: `<div class="an-em-pin" style="width:${w}px;height:${w}px"><img src="${k.img}" alt="" draggable="false">${k.group !== 'crop' ? `<i style="font-size:${Math.max(8, Math.round(px * 0.4))}px">!</i>` : ''}</div>`,
      iconSize: [w, w],
      iconAnchor: [w / 2, w * 0.9],
    })
  }
  return pinCache[key]
}

/** Plants drawn about as big as a real tree: they grow when you zoom in, the way they do in the app. */
function Marks({ marks, lat }) {
  const map = useMap()
  const [zoom, setZoom] = useState(map.getZoom())
  useMapEvents({ zoomend: () => setZoom(map.getZoom()) })
  const mpp = (156543.03 * Math.cos((lat * Math.PI) / 180)) / 2 ** zoom
  const px = Math.round(Math.max(16, Math.min(54, 7 / mpp)))
  return marks.map((m) => {
    const k = KIND[m.kind]
    return (
      <Marker key={m.id} position={[m.lat, m.lng]} icon={pinFor(m.kind, px)}>
        <Tooltip direction="top" offset={[0, -px * 0.6]}>
          <b>{k.name}</b>{m.age ? ` · ${m.age} yrs` : ''}{m.sev ? ` · ${m.sev}` : ''}
          <br /><span style={{ color: '#9a6a00' }}>{PENDING}</span>
        </Tooltip>
      </Marker>
    )
  })
}

function Panel({ title, sat, geo, marks, lat, tall, labels, step }) {
  const bounds = useMemo(() => L.latLngBounds(geo.ring), [geo])
  return (
    <div className="an-em-panel">
      {title && <b>{title}</b>}
      <div className={`an-em-map${tall ? ' tall' : ''}`}>
        <MapContainer bounds={bounds} zoomControl style={{ height: '100%', width: '100%', background: sat ? '#2c4a2a' : '#f3f1e8' }} scrollWheelZoom={false} attributionControl={false} zoomSnap={0.25} zoomDelta={0.5}>
          {sat && <TileLayer url={IMAGERY} maxNativeZoom={18} maxZoom={21} />}
          <Fit bounds={bounds} />
          <Polygon positions={geo.ring} pathOptions={{ color: sat ? '#fff' : '#2f6f45', weight: 3, fillColor: sat ? '#2f8a4f' : '#c9e6d1', fillOpacity: sat ? 0.1 : 0.6 }} />
          {geo.grid.map((g, i) => <Polyline key={i} positions={g} pathOptions={{ color: sat ? '#fff' : '#7ba58b', weight: 1, opacity: sat ? 0.5 : 0.75 }} interactive={false} />)}
          {labels.map((l, i) => <Marker key={`gl${i}`} position={l.p} interactive={false} icon={L.divIcon({ className: 'an-em-gl', html: `<span class="${sat ? 'sat' : ''}">${l.t}</span>`, iconSize: [20, 20], iconAnchor: [10, 10] })} />)}
          <Marks marks={marks} lat={lat} />
        </MapContainer>
        <div className={`an-em-scale${sat ? ' sat' : ''}`}>
          <i /> Each square is {step} m × {step} m <small>({((step * step) / 4046.86).toFixed(step >= 50 ? 1 : 2)} acres)</small>
        </div>
      </div>
    </div>
  )
}

// A coconut tree that grows with the age band, from a seedling to an old tree.
const STAGE = [[18, '#7fcf95'], [30, '#58bb76'], [44, '#35a05a'], [58, '#26864b'], [72, '#1c6f3e'], [78, '#6f9a2e'], [86, '#a9ad2c']]
function PalmStage({ i }) {
  const [h, c] = STAGE[i]
  const lean = i >= 5 ? (i === 5 ? 3 : 6) : 0
  const top = 100 - h
  return (
    <svg viewBox="0 0 100 100" width="92" height="92" aria-hidden>
      <ellipse cx="50" cy="94" rx="16" ry="3.4" fill="#000" opacity=".12" />
      <path d={`M50 94 Q${50 + lean * 0.4} ${(94 + top) / 2} ${50 + lean} ${top + 6}`} stroke="#8b4a1c" strokeWidth={2.2 + h / 30} strokeLinecap="round" fill="none" />
      <g stroke={c} strokeWidth={2 + h / 22} strokeLinecap="round" fill="none" transform={`translate(${50 + lean} ${top + 6})`}>
        {[[-1, -0.1], [-0.7, -0.55], [0, -0.75], [0.7, -0.55], [1, -0.1], [-0.55, 0.3], [0.55, 0.3]].map(([dx, dy], k) => (
          <path key={k} d={`M0 0 Q${dx * h * 0.28} ${dy * h * 0.42 - h * 0.1} ${dx * h * 0.42} ${dy * h * 0.3 + h * 0.12}`} />
        ))}
      </g>
    </svg>
  )
}

const day = (d) => d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' })

export default function EstateMapModal({ e, onClose }) {
  const [view, setView] = useState('both')
  const [group, setGroup] = useState('all')
  const [shown, setShown] = useState(8)
  const data = useMemo(() => {
    const L0 = layoutOf(e)
    const mLng = 111320 * Math.cos((FARMLAND.lat * Math.PI) / 180)
    const nudge = L0.span > 200 ? L0.span * 0.14 : 0 // a big estate drifts south-east, away from the few buildings north-west of the farmland
    const at = ([x, y]) => [FARMLAND.lat + (y - nudge) / 111320, FARMLAND.lng + (x + nudge) / mLng]
    return {
      step: L0.step,
      labels: [
        ...Array.from({ length: L0.cols }, (_, i) => ({ t: String.fromCharCode(65 + (i % 26)), p: at([L0.gx0 + (i + 0.5) * L0.step, L0.box[3] + L0.step * 0.22]) })),
        ...Array.from({ length: L0.rows }, (_, i) => ({ t: String(i + 1), p: at([L0.box[0] - L0.step * 0.22, L0.gy1 - (i + 0.5) * L0.step]) })),
      ],
      geo: { ring: L0.outline.map(at), grid: gridLines(L0.outline, L0.step).map((s) => s.map(at)) },
      marks: L0.marks.map((m) => { const [lat, lng] = at([m.x, m.y]); return { ...m, lat, lng } }),
    }
  }, [e])
  const marks = data.marks
  const crops = marks.filter((m) => KIND[m.kind].group === 'crop')
  const threats = marks.filter((m) => KIND[m.kind].group !== 'crop')
  const countOf = (id) => marks.filter((m) => m.kind === id).length
  const present = KINDS.filter((k) => countOf(k.id) > 0)
  const maxKind = Math.max(1, ...present.map((k) => countOf(k.id)))
  const palms = marks.filter((m) => m.age && ['coconut', 'king'].includes(m.kind))
  const ageRows = AGES.map(([id, stage]) => [id, stage, palms.filter((m) => m.age === id).length])
  const maxAge = Math.max(1, ...ageRows.map((r) => r[2]))
  const list = marks.filter((m) => group === 'all' || KIND[m.kind].group === group)
  const lat = FARMLAND.lat

  return (
    <Modal title={`${e.name} · estate map`} sub={`${e.id} · ${e.owner} · ${e.acres} acres · ${label(e.district)}${e.region ? ` · ${e.region}` : ''}`} onClose={onClose}>
      <div className="an-modal-body an-em">
        <div className="an-em-stats">
          <div><span className="ic g"><img src="/plants/coconut.png" alt="" /></span><b>{crops.length}</b><span>trees and crops marked</span></div>
          <div className="bad"><span className="ic r"><img src="/plants/mite.png" alt="" /></span><b>{threats.length}</b><span>pest and weed spots</span></div>
          <div className="wait"><span className="ic a"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#9a6a00" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M6 3h12M6 21h12M7 3c0 5 5 5 5 9s-5 4-5 9M17 3c0 5-5 5-5 9s5 4 5 9" /></svg></span><b>{marks.length}</b><span>waiting for CDO check</span></div>
          <div><span className="ic b"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="#2c6a96" strokeWidth="2" strokeLinecap="round"><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M9 3v18M15 3v18M3 9h18M3 15h18" /></svg></span><b>{data.step} m</b><span>each grid square</span></div>
        </div>

        <div className="an-em-main">
          <section className="an-em-left">
            <div className="an-em-bar">
              <Segmented value={view} onChange={setView} options={[['both', 'Both views'], ['sat', 'Satellite'], ['plan', 'Plan']]} />
              <small>Hover a plant for details · zoom to see them bigger</small>
            </div>
            <div className={`an-em-panels ${view === 'both' ? 'two' : ''}`}>
              {(view === 'both' || view === 'sat') && <Panel key={`sat-${view}`} title={view === 'both' ? 'Satellite view' : null} sat geo={data.geo} marks={marks} lat={lat} tall={view !== 'both'} labels={data.labels} step={data.step} />}
              {(view === 'both' || view === 'plan') && <Panel key={`plan-${view}`} title={view === 'both' ? 'Plan view' : null} geo={data.geo} marks={marks} lat={lat} tall={view !== 'both'} labels={data.labels} step={data.step} />}
            </div>
          </section>

          <aside className="an-em-side">
            <div className="an-em-card">
              <h4>What grows here</h4>
              {present.map((k) => (
                <div key={k.id} className="an-em-row">
                  <img src={k.img} alt="" />
                  <div><span>{k.name}{k.group !== 'crop' && <em className={k.group}>{k.group === 'pest' ? 'Pest' : 'Invasive'}</em>}</span>
                    <i><u style={{ width: `${(countOf(k.id) / maxKind) * 100}%`, background: k.color }} /></i></div>
                  <b>{countOf(k.id)}</b>
                </div>
              ))}
            </div>
            {threats.length > 0 && (
              <div className="an-em-card">
                <h4>Threats by severity</h4>
                {['High', 'Medium', 'Low'].map((s) => (
                  <div key={s} className="an-em-sev"><i style={{ background: SEV[s] }} />{s}<b>{threats.filter((m) => m.sev === s).length}</b></div>
                ))}
              </div>
            )}
          </aside>
        </div>

        <div className="an-em-card an-em-ages">
          <h4>Coconut tree ages <small>coconut and king coconut · share of {palms.length} trees</small></h4>
          <div className="an-em-palms">
            {ageRows.map(([id, stage, n], i) => (
              <div key={id} className={n ? '' : 'none'}>
                <PalmStage i={i} />
                <b>{stage}</b>
                <small>{id} yrs</small>
                <strong>{palms.length ? Math.round((n / palms.length) * 100) : 0}%</strong>
                <em>{n} {n === 1 ? 'tree' : 'trees'}</em>
              </div>
            ))}
          </div>
        </div>

        <div className="an-em-card an-em-records">
          <div className="an-em-rhead">
            <h4>Records <small>{list.length} marks, one row per plant</small></h4>
            <Segmented value={group} onChange={(g) => { setGroup(g); setShown(8) }} options={GROUPS} />
          </div>
          <div className="an-em-tablewrap">
            <table>
              <thead><tr><th>Plant</th><th>Square</th><th>Age or severity</th><th>Note</th><th>Updated</th><th>Status</th></tr></thead>
              <tbody>
                {list.slice(0, shown).map((m) => (
                  <tr key={m.id}>
                    <td><span className="pl"><img src={KIND[m.kind].img} alt="" />{KIND[m.kind].name}</span></td>
                    <td><span className="sq">{m.sq}</span></td>
                    <td>{m.age ? `${m.age} yrs · ${AGES.find((a) => a[0] === m.age)?.[1]}` : <span className="sev" style={{ background: `${SEV[m.sev]}22`, color: SEV[m.sev] }}>{m.sev}</span>}</td>
                    <td>{m.note || '-'}</td>
                    <td>{day(m.updated)}</td>
                    <td><span className="pend">{m.status}</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {list.length > shown && <button type="button" className="an-more" onClick={() => setShown(shown + 12)}>Show more ({list.length - shown} left)</button>}
        </div>

        <p className="an-prof-note">Sample layout. It shows how the map an owner draws in the app will look here; the shape and marks are made up for this demo land.</p>
      </div>
    </Modal>
  )
}

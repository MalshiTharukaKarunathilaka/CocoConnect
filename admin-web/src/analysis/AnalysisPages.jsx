import { useEffect, useMemo, useState } from 'react'
import { Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Legend, Line, LineChart, Pie, PieChart, XAxis, YAxis } from 'recharts'
import DrillMap, { GREEN_SCALE } from './DrillMap'
import { renderToStaticMarkup } from 'react-dom/server'
import { Character, DrawnCharacter, Pair } from './People'
import { glyphHtml } from './pins'
import PriceMap, { Coconut } from './PriceMap'
import LandTopic, { LAND_TOPICS } from './LandTopics'
import { api } from '../api'
import { loadRegions, regionFigures } from './regions'
import {
  AGE_GROUPS, BOOKING_STATUSES, DISTRICTS, ESTATE_TYPES, FERT_TYPES, FERT_YEARS, GENDERS, JOB_CATEGORIES,
  MACHINE_TYPES, MONTHS, PRODUCTS, PROVINCE_COLORS, PROVINCE_NAMES, byDistrict, pointIn, compact, districtsOf, inScope, kgText, label,
  num, pct, provinceOf, rs, scopeName, sumBy, ym,
} from './data'
import { Card, Chart, Chips, DataTable, GradDefs, Icon, Kpi, Loading, Modal, PALETTE, PageHead, RegionSlot, Segmented, gid, tipEl, useData } from './ui'

const ax = { tick: { fontSize: 11, fill: '#66736c' }, axisLine: false, tickLine: false }
const BLUE = ['#e4eff5', '#bad7e6', '#86b6cf', '#4f8fb0', '#25607f']
const AMBER = ['#fbf0d9', '#f3d9a0', '#e8bb5e', '#cf9526', '#8f610d']
const TERRA = ['#f6e8df', '#e8c5ad', '#d49a73', '#b46a3f', '#7d3f1c']

// ---- chart pieces ----------------------------------------------------------
/** A round-cornered photo in front of each category name. */
function PhotoTick({ x, y, payload, photos, nameWidth, thumb }) {
  const file = photos[payload.value]
  const id = `pt-${String(payload.value).replace(/\W/g, '')}`
  const left = -nameWidth
  return (
    <g transform={`translate(${x},${y})`}>
      <defs>
        <clipPath id={id}>
          <rect x={left} y={-thumb / 2} width={thumb} height={thumb} rx={thumb * 0.3} />
        </clipPath>
      </defs>
      {file && <image href={`/photos/${file}.jpg`} x={left} y={-thumb / 2} width={thumb} height={thumb} preserveAspectRatio="xMidYMid slice" clipPath={`url(#${id})`} />}
      <rect x={left} y={-thumb / 2} width={thumb} height={thumb} rx={thumb * 0.3} fill="none" stroke="#ffffff" strokeWidth="2" />
      <text x={left + thumb + 8} y={0} dy="0.32em" textAnchor="start" fontSize="11" fill="#55625a">{payload.value}</text>
    </g>
  )
}

function Bars({ data, keys = ['value'], colors = PALETTE, horizontal, height = 240, fmt = compact, axisFmt, stacked, single, nameWidth = 112, onPick, photos, thumb = 30 }) {
  return (
    <Chart height={height}>
      <BarChart data={data} layout={horizontal ? 'vertical' : 'horizontal'} margin={{ left: horizontal ? 4 : -8, right: horizontal ? 34 : 14, top: 6 }}>
        <GradDefs horizontal={horizontal} colors={[...colors, ...data.map((d) => d.color)]} />
        <CartesianGrid stroke="#dfe5df" strokeDasharray="2 5" vertical={horizontal} horizontal={!horizontal} />
        {horizontal ? (
          <>
            <XAxis type="number" {...ax} tickFormatter={axisFmt || fmt} />
            <YAxis type="category" dataKey="name" width={nameWidth} {...ax} tick={photos ? <PhotoTick photos={photos} nameWidth={nameWidth} thumb={thumb} /> : ax.tick} />
          </>
        ) : (
          <>
            <XAxis dataKey="name" {...ax} interval={0} />
            <YAxis {...ax} tickFormatter={axisFmt || fmt} />
          </>
        )}
        {tipEl(fmt)}
        {keys.map((k, i) => (
          <Bar key={k} isAnimationActive={false} shape={<Bar3D clickable={!!onPick} />} onClick={onPick ? (d) => onPick(d?.payload?.name ?? d?.name) : undefined} dataKey={k} stackId={stacked ? 's' : undefined} fill={stacked ? colors[i % colors.length] : `url(#${gid(colors[i % colors.length])})`} radius={stacked ? 0 : horizontal ? [0, 10, 10, 0] : [10, 10, 4, 4]} maxBarSize={34}>
            {single && data.map((d, j) => <Cell key={j} fill={`url(#${gid(d.color || colors[0])})`} />)}
          </Bar>
        ))}
        {keys.length > 1 && <Legend iconType="circle" wrapperStyle={{ fontSize: 11 }} />}
      </BarChart>
    </Chart>
  )
}

/** A bar drawn with a lit top and a shaded side, so it reads as a solid block. */
function Bar3D(props) {
  const { x, y, width, height, fill } = props
  if (!(width > 0) || !(height > 0) || x == null) return null
  const d = Math.max(3, Math.min(9, width * 0.28, height * 0.4))
  const w = width - d
  const h = height - d
  const top = `${x},${y + d} ${x + d},${y} ${x + width},${y} ${x + w},${y + d}`
  const side = `${x + w},${y + d} ${x + width},${y} ${x + width},${y + h} ${x + w},${y + height}`
  return (
    <g style={{ cursor: props.clickable ? 'pointer' : 'default' }}>
      <rect x={x} y={y + d} width={w} height={h} fill={fill} />
      <polygon points={top} fill={fill} />
      <polygon points={top} fill="#ffffff" opacity="0.42" />
      <polygon points={side} fill={fill} />
      <polygon points={side} fill="#0b1a10" opacity="0.28" />
    </g>
  )
}

const shade = (hex, f) => {
  const n = parseInt(String(hex).replace('#', ''), 16)
  const c = (v) => Math.max(0, Math.min(255, Math.round(v * f)))
  return `rgb(${c((n >> 16) & 255)},${c((n >> 8) & 255)},${c(n & 255)})`
}

/** Tilted, thick donut drawn as stacked ellipses. Hover or click a slice to read it. */
function Donut({ data, height = 190, fmt = num, pick = -1, onPick, legend = true }) {
  const [hot, setHot] = useState(-1)
  const total = sumBy(data, (d) => d.value) || 1
  const W = 300
  const H = Math.max(150, height)
  const cx = W / 2
  const rx = 112
  const ry = 60
  const cy = H / 2 - 14
  const DEPTH = 15
  let acc = -Math.PI / 2
  const arcs = data.map((d, i) => {
    const sweep = Math.min((d.value / total) * Math.PI * 2, Math.PI * 2 - 0.0001)
    const a0 = acc
    const a1 = acc + sweep
    acc += (d.value / total) * Math.PI * 2
    const pt = (a, k) => `${cx + rx * k * Math.cos(a)},${cy + ry * k * Math.sin(a)}`
    const big = sweep > Math.PI ? 1 : 0
    const path = `M${pt(a0, 1)} A${rx},${ry} 0 ${big} 1 ${pt(a1, 1)} L${pt(a1, 0.56)} A${rx * 0.56},${ry * 0.56} 0 ${big} 0 ${pt(a0, 0.56)} Z`
    return { path, color: d.color || PALETTE[i % PALETTE.length], mid: (a0 + a1) / 2 }
  })
  const idx = hot >= 0 ? hot : pick
  const shown = idx >= 0 ? data[idx] : null
  return (
    <div className={`an-donut ${legend ? '' : 'solo'}`}>
      <svg viewBox={`0 0 ${W} ${H}`} className="an-donut3d" role="img">
        {Array.from({ length: DEPTH }, (_, k) => DEPTH - k).map((k) => (
          <g key={k} transform={`translate(0 ${k})`}>
            {arcs.map((a, i) => (
              <path key={i} d={a.path} fill={shade(a.color, 0.58)} />
            ))}
          </g>
        ))}
        {arcs.map((a, i) => (
          <path
            key={i}
            d={a.path}
            fill={a.color}
            stroke="#ffffff"
            strokeWidth="1.2"
            style={{ transform: hot === i || pick === i ? `translate(${Math.cos(a.mid) * 5}px, ${Math.sin(a.mid) * 3 - 3}px)` : 'none', transition: 'transform .15s', cursor: 'pointer' }}
            onMouseEnter={() => setHot(i)}
            onMouseLeave={() => setHot(-1)}
            onClick={() => onPick && onPick(i)}
          />
        ))}
        {arcs.map((a, i) =>
          data[i].glyph && data[i].value / total >= 0.04 ? (
            <foreignObject key={`g${i}`} x={cx + rx * 0.8 * Math.cos(a.mid) - 30} y={cy + ry * 0.8 * Math.sin(a.mid) - 50} width="60" height="60" style={{ overflow: 'visible', pointerEvents: 'none' }}>
              <div style={{ width: 60, height: 60, display: 'flex', alignItems: 'flex-end', justifyContent: 'center', filter: 'drop-shadow(0 0 1.5px #fff) drop-shadow(0 0 1.5px #fff) drop-shadow(0 3px 2px rgba(0,0,0,.3))' }} dangerouslySetInnerHTML={{ __html: glyphHtml(data[i].glyph, data[i].color, 54) }} />
            </foreignObject>
          ) : null,
        )}
        {arcs.map((a, i) =>
          data[i].value / total >= 0.06 ? (
            <text key={`l${i}`} x={cx + rx * 0.78 * Math.cos(a.mid)} y={cy + ry * 0.78 * Math.sin(a.mid) + 4.5} textAnchor="middle" className="an-slice-label">
              {pct(data[i].value, total)}
            </text>
          ) : null,
        )}
        {shown && (
          <>
            <text x={cx} y={cy + 2} textAnchor="middle" className="an-donut-small">{shown.name}</text>
            <text x={cx} y={cy + 15} textAnchor="middle" className="an-donut-small">{fmt(shown.value)}</text>
          </>
        )}
      </svg>
      {legend && (
        <ul>
          {data.map((d, i) => (
            <li key={d.name} className={hot === i || pick === i ? 'hot' : ''} onMouseEnter={() => setHot(i)} onMouseLeave={() => setHot(-1)} onClick={() => onPick && onPick(i)}>
              {d.glyph ? <span className="an-leg-glyph" dangerouslySetInnerHTML={{ __html: glyphHtml(d.glyph, d.color, 20) }} /> : <i style={{ background: d.color || PALETTE[i % PALETTE.length] }} />}
              <span>{d.name}</span>
              <b>{pct(d.value, total)}</b>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

function GenderCard({ gender, title = 'Gender' }) {
  const total = sumBy(gender, (g) => g.value) || 1
  const [pick, setPick] = useState(0)
  return (
    <Card title={title} sub="Tap a person or a slice">
      <div className="an-gender">
        <div className="an-gender-left">
          <Donut data={gender} height={160} legend={false} pick={pick} onPick={setPick} />
        </div>
        <div className="an-folks">
          {gender.map((g, i) => (
            <button key={g.name} className={`an-folk ${pick === i ? 'on' : ''}`} onClick={() => setPick(i)}>
              <span className="an-bubble" style={{ background: g.color }}>{pct(g.value, total)}</span>
              <Character gender={i === 0 ? 'M' : 'F'} stage={1} height={Math.round(140 + (g.value / total) * 60)} active={pick === i} delay={i * 0.4} />
              <small><b>{g.name}</b> · {num(g.value)}</small>
            </button>
          ))}
        </div>
      </div>
    </Card>
  )
}

function AgeCard({ age, title = 'Age', noun = 'workers' }) {
  const total = sumBy(age, (a) => a.value) || 1
  const [pick, setPick] = useState(1)
  const data = age.map((a, i) => ({ ...a, color: i === pick ? '#256b45' : '#a9cdb7' }))
  return (
    <Card title={title} sub="Tap an age group to meet them">
      <div className="an-age">
        <div className="an-age-left">
          <Bars data={data} height={190} fmt={num} single />
          <div className="an-gchips">
            {age.map((a, i) => (
              <button key={a.name} className={pick === i ? 'on' : ''} onClick={() => setPick(i)} style={pick === i ? { background: '#256b45' } : undefined}>{a.name}</button>
            ))}
          </div>
        </div>
        <div className="an-age-right" key={pick}>
          <Pair stage={pick} height={165} />
          <div>
            <b>{pct(age[pick].value, total)}</b>
            <span>{age[pick].name} years</span>
            <small>{num(age[pick].value)} {noun}</small>
          </div>
        </div>
      </div>
    </Card>
  )
}

function Trend({ data, keys, colors = PALETTE, fmt = compact, axisFmt, height = 240, area, tight }) {
  const Ch = area ? AreaChart : LineChart
  return (
    <div className="an-trend">
    <Chart height={height}>
      <Ch data={data} margin={{ left: -8, right: 14, top: 6 }}>
        <CartesianGrid stroke="#dfe5df" strokeDasharray="2 5" vertical={false} />
        <XAxis dataKey="name" {...ax} />
        <YAxis {...ax} tickFormatter={axisFmt || fmt} domain={tight ? [(m) => Math.floor(m - 3), (m) => Math.ceil(m + 3)] : undefined} />
        {tipEl(fmt)}
        {keys.map((k, i) =>
          area ? (
            <Area key={k} isAnimationActive={false} type="monotone" dataKey={k} stroke={colors[i]} fill={colors[i]} fillOpacity={0.15} strokeWidth={2.4} />
          ) : (
            <Line key={k} isAnimationActive={false} type="monotone" dataKey={k} stroke={colors[i % colors.length]} strokeWidth={2.4} dot={false} />
          ),
        )}
        {keys.length > 1 && <Legend iconType="circle" wrapperStyle={{ fontSize: 11 }} />}
      </Ch>
    </Chart>
    </div>
  )
}

/** Bars for the current level: provinces on the island view, districts once a province is open. */
function areaBars(sel, byD, color = '#5fa47b') {
  if (!sel.province) {
    return PROVINCE_NAMES.map((p) => ({ name: p, value: sumBy(districtsOf(p), (d) => byD[d.name] || 0), color: PROVINCE_COLORS[p] }))
      .sort((a, b) => b.value - a.value)
  }
  return districtsOf(sel.province)
    .map((d) => ({ name: label(d.name), value: byD[d.name] || 0, color: sel.district === d.name ? '#15201a' : PROVINCE_COLORS[sel.province] }))
    .sort((a, b) => b.value - a.value)
}

const ESTATE_PHOTOS = ['rotary', 'koku_nagula', 'slasher', 'disc_plough', 'trailer']
const estatePhoto = (e) => `/photos/${ESTATE_PHOTOS[Number(e.id.slice(2)) % ESTATE_PHOTOS.length]}.jpg`

function EstateCard({ e }) {
  return (
    <article className="an-estate">
      <div className="an-estate-img" style={{ backgroundImage: `url(${estatePhoto(e)})` }}>
        <span className={`an-plan ${e.plan.split(' ')[0].toLowerCase()}`}>{e.plan}</span>
      </div>
      <div className="an-estate-body">
        <b>{e.name}</b>
        <small>{e.owner} · {label(e.district)}</small>
        <div className="an-estate-meta">
          <span><i>{e.acres}</i> acres</span>
          <span><i>{num(e.palms)}</i> palms</span>
          <span>since <i>{e.registeredOn.slice(0, 7)}</i></span>
        </div>
      </div>
    </article>
  )
}

function EstateCards({ estates, title, sub }) {
  const [all, setAll] = useState(false)
  const shown = [...estates].reverse().slice(0, all ? 24 : 8)
  return (
    <Card title={title} sub={sub} right={estates.length > 8 && (
      <button className="an-more an-noprint" onClick={() => setAll(!all)}>{all ? 'Show fewer' : `Show more`}</button>
    )}>
      <div className="an-estates">
        {shown.map((e) => <EstateCard key={e.id} e={e} />)}
      </div>
      {!estates.length && <p className="an-empty">No lands registered here yet.</p>}
    </Card>
  )
}

/** All nine provinces side by side, always island-wide. Folded away until asked for. */
function ProvinceStrip({ byD, fmt, unit, sel, setSel, title = 'Province comparison', rows: rowsIn, noun = 'provinces', where = 'island-wide', onPick, picked, back, startOpen }) {
  const [open, setOpen] = useState(() => !!startOpen || window.location.hash.includes('provinces'))
  const rows = rowsIn || PROVINCE_NAMES.map((p) => ({ name: p, value: sumBy(districtsOf(p), (d) => byD[d.name] || 0) }))
  const colorOf = (r) => r.color || PROVINCE_COLORS[r.name]
  const imgOf = (r) => (rowsIn ? r.img : `/provinces/${r.name.toLowerCase().replaceAll(' ', '-')}.png`)
  const pick = (r) => (onPick ? onPick(r.name) : setSel(sel.province === r.name && !sel.district ? {} : { province: r.name }))
  const isOn = (r) => (picked !== undefined ? picked === r.name : sel.province === r.name)
  const total = sumBy(rows, (r) => r.value)
  const max = Math.max(...rows.map((r) => r.value), 1)
  const avg = total / rows.length
  const ranked = [...rows].sort((a, b) => b.value - a.value)
  // an even grid: 9 provinces -> 3 x 3, 10 CDO areas -> 5 x 2, and so on
  const cols = Math.min(rows.length, [5, 4, 3].find((c) => rows.length % c === 0) || 4)
  const best = ranked[0]
  const low = ranked[ranked.length - 1]
  return (
    <Card
      title={title}
      sub={open ? `All ${noun} ${where} \u00b7 ${fmt(total)} ${unit} in total. Click one to open it.` : `${best.name} leads with ${fmt(best.value)} \u00b7 ${low.name} is lowest with ${fmt(low.value)}`}
      className="an-strip-card"
      right={<span className="an-strip-actions">{back && <button className="an-more an-noprint" onClick={back.go}>{'\u2039'} {back.text}</button>}<button className="an-more an-noprint" onClick={() => setOpen(!open)}>{open ? `Hide ${noun} \u25b4` : `View all ${noun} \u25be`}</button></span>}
    >
      {!open && (
        <div className="an-strip-mini" title="Share of the total by province">
          {ranked.map((r) => (
            <span key={r.name} style={{ flexGrow: Math.max(r.value, total * 0.01), background: colorOf(r) }} title={`${r.name}: ${fmt(r.value)}`} />
          ))}
        </div>
      )}
      {open && (
        <div className="an-strip an-slide" style={{ '--cols': cols }}>
          {ranked.map((r, i) => {
            const diff = avg ? Math.round(((r.value - avg) / avg) * 100) : 0
            return (
              <button
                key={r.name}
                className={`an-prov ${isOn(r) ? 'on' : ''} ${imgOf(r) ? 'pic' : ''}`}
                style={{ '--c': colorOf(r), ...(imgOf(r) ? { '--img': `url(${imgOf(r)})` } : {}) }}
                onClick={() => pick(r)}
              >
                <span className="an-prov-top">
                  <i className="an-prov-dot" style={{ background: colorOf(r) }} />
                  <b>{r.name}</b>
                  <span className="an-prov-rank">#{i + 1}</span>
                </span>
                <span className="an-prov-mid">
                  <strong>{fmt(r.value)}</strong>
                  <span className="an-prov-share">{pct(r.value, total)}</span>
                </span>
                <span className="an-prov-bar"><i style={{ width: `${(r.value / max) * 100}%`, background: colorOf(r) }} /></span>
                <small>
                  <em className={diff >= 0 ? 'up' : 'down'}>{diff >= 0 ? '▲' : '▼'} {Math.abs(diff)}% vs average</em>
                </small>
              </button>
            )
          })}
        </div>
      )}
    </Card>
  )
}

const JOB_INFO = {
  'Manual work': { photo: 'husking', text: 'Hand work on the estate such as weeding, husking, fertilizing and clearing.' },
  'Nut Gatherer': { photo: 'koku_nagula', text: 'Gathering fallen and plucked nuts and bringing them together for collection.' },
  'Machine work': { photo: 'rotary', text: 'Operating tractors, hand tractors and other machines on the estate.' },
}

const EST_PHOTOS = {
  'Non-systematic plantation': 'disc_plough',
  'Systematic plantation': 'rotary',
  'Corporate plantation': 'slasher',
}
const jobPhotos = () => Object.fromEntries(Object.entries(JOB_INFO).map(([k, v]) => [k, v.photo]))

function JobSpotlight({ d, cat, sel, onClose }) {
  const info = JOB_INFO[cat]
  const mine = d.workers.filter((w) => w.category === cat && inScope(sel, w.district))
  const everyone = d.workers.filter((w) => inScope(sel, w.district))
  const total = sumBy(mine, (w) => w.total)
  const women = sumBy(mine, (w) => w.gender[1])
  const age = AGE_GROUPS.map((a, i) => ({ name: a, v: sumBy(mine, (w) => w.age[i]) })).sort((a, b) => b.v - a.v)[0]
  const est = ESTATE_TYPES.map((e, i) => ({ name: e.split(' (')[0], v: sumBy(mine, (w) => w.estate[i]) })).sort((a, b) => b.v - a.v)[0]
  const area = areaBars(sel, byDistrict(mine, (w) => w.total))[0]
  return (
    <div className="an-spot">
      <div className="an-spot-img" style={{ backgroundImage: `url(/photos/${info.photo}.jpg)` }}>
        <span>{cat}</span>
      </div>
      <div className="an-spot-body">
        <div className="an-spot-head">
          <div>
            <h3>{cat}</h3>
            <p>{info.text}</p>
          </div>
          <button className="an-more an-noprint" onClick={onClose}>Close</button>
        </div>
        <div className="an-spot-stats">
          <div><small>Workers</small><b>{num(total)}</b></div>
          <div><small>Share of all day work</small><b>{pct(total, sumBy(everyone, (w) => w.total))}</b></div>
          <div><small>Women</small><b>{pct(women, total)}</b></div>
          <div><small>Biggest age group</small><b>{age?.name}</b></div>
          <div><small>Works mostly in</small><b>{est?.name}</b></div>
          <div><small>{sel.province ? 'Top district' : 'Top province'}</small><b>{area?.name || '\u2014'}</b></div>
        </div>
      </div>
    </div>
  )
}

const FLEET = {
  Tractor: { key: 'TRACTOR', photo: 'rotary', pos: '50% 60%' },
  Backhoe: { key: 'BACKHOE', photo: 'backhoe', pos: '50% 50%' },
  'Hand tractor': { key: 'HAND_TRACTOR', photo: 'hand_tractor', pos: '72% 50%' },
}

function FleetCard({ typeMix, machines }) {
  const [pick, setPick] = useState(0)
  const total = sumBy(typeMix, (t) => t.value) || 1
  return (
    <Card title="Fleet mix" sub="Tap a machine to see its details">
      <div className="an-fleet">
        <Donut data={typeMix} height={150} legend={false} pick={pick} onPick={setPick} />
        <div className="an-fleet-cards">
          {typeMix.map((t, i) => {
            const f = FLEET[t.name]
            const mine = machines.filter((m) => m.type === f.key)
            const free = mine.filter((m) => m.available).length
            const from = mine.length ? Math.min(...mine.map((m) => m.rate)) : 0
            return (
              <button key={t.name} className={`an-mach ${pick === i ? 'on' : ''}`} onClick={() => setPick(i)} style={{ '--c': t.color }}>
                <span className="an-bubble" style={{ background: t.color }}>{pct(t.value, total)}</span>
                <span className="an-mach-img" style={{ backgroundImage: `url(/photos/${f.photo}.jpg)`, backgroundPosition: f.pos }} />
                <b>{t.name}</b>
                <small>{t.value} machines</small>
                {pick === i && <em>{free} available{from ? ` · from Rs. ${num(from)}` : ''}</em>}
              </button>
            )
          })}
        </div>
      </div>
    </Card>
  )
}

function Split({ map, side }) {
  return (
    <div className="an-split">
      <div className="an-split-map">{map}</div>
      <div className="an-split-side">{side}</div>
    </div>
  )
}

function Insight({ children }) {
  return <div className="an-insight">{children}</div>
}

// =============================================================================
// 1. Overview + estate footprint
// =============================================================================
function growthOf(estates) {
  const byMonth = {}
  estates.forEach((e) => {
    const k = e.registeredOn.slice(0, 7)
    byMonth[k] = (byMonth[k] || 0) + 1
  })
  let run = 0
  const out = []
  for (let y = 2024; y <= 2026; y++)
    for (let m = 1; m <= 12; m++) {
      if (y === 2024 && m < 2) continue
      if (y === 2026 && m > 10) break
      run += byMonth[`${y}-${String(m).padStart(2, '0')}`] || 0
      out.push({ name: ym(y, m), Lands: run })
    }
  return out
}

/** Island-wide subscription growth. Shown on the User management page. */
export function SubscriptionGrowth() {
  const { data } = useData()
  const growth = useMemo(() => (data ? growthOf(data.estates) : []), [data])
  if (!data) return null
  return (
    <div className="an-root an-solo">
      <Card title="Subscription growth" sub={`Cumulative registered lands \u00b7 ${data.estates.length} so far`}>
        <Trend data={growth} keys={['Lands']} colors={['#256b45']} area fmt={num} height={210} />
      </Card>
    </div>
  )
}

const CROPS = {
  Coconut: { icon: 'palm', color: '#2f8a4f' },
  Pepper: { icon: 'pepper', color: '#9c2a23' },
  Pineapple: { icon: 'pineapple', color: '#d99a0b' },
}
const CROP_LEGEND = Object.entries(CROPS).map(([text, c]) => ({ icon: c.icon, color: c.color, text }))

const MACHINE_KIND = { TRACTOR: 'tractor', BACKHOE: 'backhoe', HAND_TRACTOR: 'hand' }

/** The machine picker on the machine maps: all machines, or one kind at a time. value is a label or ''. */
function MachineCard({ value, onChange, list }) {
  return (
    <div className="an-crop-card an-noprint">
      <b>Machine</b>
      <button className={!value ? 'on' : ''} onClick={() => onChange('')}>
        <i className="all" />
        <span>All machines</span>
        <em>{list.length}</em>
      </button>
      {Object.entries(MACHINE_TYPES).map(([k, t]) => (
        <button key={k} className={value === t.label ? 'on' : ''} onClick={() => onChange(value === t.label ? '' : t.label)}>
          <span className="an-crop-ic wide" dangerouslySetInnerHTML={{ __html: glyphHtml(MACHINE_KIND[k], t.color, 26) }} />
          <span>{t.label}</span>
          <em>{list.filter((m) => m.type === k).length}</em>
        </button>
      ))}
    </div>
  )
}

/** The crop picker that sits on the land maps. */
function CropCard({ crop, setCrop, estates }) {
  return (
    <div className="an-crop-card an-noprint">
      <b>Crop</b>
      {['All', ...Object.keys(CROPS)].map((c) => {
        const mine = estates.filter((e) => c === 'All' || e.crop === c)
        return (
          <button key={c} className={crop === c ? 'on' : ''} onClick={() => setCrop(c)}>
            {c === 'All' ? <i className="all" /> : <span className="an-crop-ic" dangerouslySetInnerHTML={{ __html: glyphHtml(CROPS[c].icon, CROPS[c].color, 20) }} />}
            <span>{c === 'All' ? 'All crops' : c}</span>
            <em>{mine.length}</em>
          </button>
        )
      })}
    </div>
  )
}

/** The part of a district's recorded figures that one CDO area gets (1 when no area is picked). */
function areaShare(d, district, region) {
  if (!region || !d.cdo) return 1
  const f = regionFigures(d.cdo, region, d.estates.filter((e) => e.district === district), d.machines.filter((m) => m.district === district))
  return f ? f.share : 1
}

const hashStr = (t) => [...String(t)].reduce((a, c) => (a * 31 + c.charCodeAt(0)) % 100003, 7)
/** Sample gender and age split for n people. male is the base share of men; ageW the base weight of each age group. */
function peopleMix(key, n, male, ageW) {
  const j = (i) => 0.88 + ((hashStr(key + i) % 1000) / 1000) * 0.24
  const men = Math.round(n * Math.min(0.97, male * j('g')))
  const w = ageW.map((x, i) => x * j(`a${i}`))
  const ws = sumBy(w, (x) => x) || 1
  const age = w.map((x) => Math.round((n * x) / ws))
  age[2] += n - sumBy(age, (x) => x)
  return {
    gender: [{ name: 'Male', value: men, color: '#256b45' }, { name: 'Female', value: n - men, color: '#d9741a' }],
    age: AGE_GROUPS.map((a, i) => ({ name: a, value: Math.max(0, age[i]) })),
  }
}

const slugOf = (name) => String(name || '').toLowerCase().replaceAll(' ', '-')

/** One flat band of figures with a 3D picture beside each number. items: [name, value, sub, figure] */
function FigTiles({ items }) {
  return (
    <div className="sb" style={{ '--n': items.length }}>
      {items.map(([name, val, sub, fig]) => (
        <div key={name} className="sb-item">
          <div className="sb-text">
            <small>{name}</small>
            <b style={String(val).length > 12 ? { fontSize: '1.2rem' } : undefined}>{val}</b>
            <em>{sub}</em>
          </div>
          <div className="sb-fig">{fig}</div>
        </div>
      ))}
    </div>
  )
}

/** The photo stat cards that open a page. items: [photo, icon, tone, label, value, sub] */
function PhotoRow({ items }) {
  return (
    <div className="an-kpis an-kpis-auto">
      {items.map(([photo, icon, tone, label, value, sub]) => (
        <Kpi key={label} photo={photo} icon={icon} tone={tone || 'green'} label={label} value={value} sub={sub} />
      ))}
    </div>
  )
}

/** Map badges: a man and a woman with the number of workers, or a sack with the amount of fertilizer. */
const PERSON_SVG = {}
const personBadge = (fmt) => ({
  html: (v) => {
    PERSON_SVG.M ||= renderToStaticMarkup(<DrawnCharacter gender="M" stage={2} height={62} />)
    PERSON_SVG.F ||= renderToStaticMarkup(<DrawnCharacter gender="F" stage={2} height={62} />)
    return `<span class="an-badge-fig pair">${PERSON_SVG.M}${PERSON_SVG.F}</span><b>${fmt(v)}</b>`
  },
})
const sackBadge = (fmt) => ({ html: (v) => `<span class="an-badge-fig sack">${glyphHtml('sack', '#a5651e', 46)}</span><b>${fmt(v)}</b>` })

/** Machines that sit inside one CDO area of Kurunegala. */
const machinesIn = (d, name, list = d.machines) => {
  const f = d.cdo?.features.find((x) => x.properties.region === name)
  return f ? list.filter((m) => m.district === 'Kurunegala' && pointIn(f.geometry.coordinates[0], m.lng, m.lat)).length : 0
}

/** Props for the comparison strip: provinces, then the districts of one province, then CDO areas. */
function landStrip(d, sel, setSel, perD, what = 'Lands', cdoValue) {
  const cdoNames = d.cdo ? d.cdo.features.map((f) => f.properties.region) : []
  if (sel.district && sel.district === 'Kurunegala' && cdoNames.length) {
    const prov = provinceOf(sel.district)
    return {
      title: `${what} by CDO area \u00b7 ${label(sel.district)}`, noun: 'CDO areas', where: `in ${label(sel.district)}`,
      rows: cdoNames.map((n) => ({ name: n, value: cdoValue ? cdoValue(n) : d.estates.filter((e) => e.region === n).length, color: PROVINCE_COLORS[prov] })),
      picked: sel.region || null,
      onPick: (n) => setSel(sel.region === n ? { province: sel.province, district: sel.district } : { province: sel.province, district: sel.district, region: n }),
      back: { text: 'Districts', go: () => setSel({ province: sel.province }) },
    }
  }
  if (sel.province) {
    return {
      title: `${what} by district \u00b7 ${sel.province}`, noun: 'districts', where: `in ${sel.province}`,
      rows: districtsOf(sel.province).map((x) => ({ name: label(x.name), key: x.name, value: perD[x.name] || 0, color: PROVINCE_COLORS[sel.province] })),
      picked: sel.district ? label(sel.district) : null,
      onPick: (n) => { const x = districtsOf(sel.province).find((y) => label(y.name) === n); setSel(sel.district === x.name ? { province: sel.province } : { province: sel.province, district: x.name }) },
      back: { text: 'Provinces', go: () => setSel({}) },
    }
  }
  return { title: `${what} by province` }
}

function Overview({ d, sel, setSel, extra }) {
  const [crop, setCrop] = useState('All')
  const estates = useMemo(() => d.estates.filter((e) => inScope(sel, e.district) && (!sel.region || e.region === sel.region)), [d, sel])
  const perD = useMemo(() => byDistrict(d.estates, () => 1), [d])
  const plans = ['Non-systematic plantation', 'Systematic plantation', 'Corporate plantation'].map((p, i) => ({ name: p, value: estates.filter((e) => e.plan === p).length, color: ['#9fd0b0', '#5fa47b', '#256b45'][i] }))
  const markers = d.estates.filter((e) => crop === 'All' || e.crop === crop).map((e) => ({
    lat: e.lat, lng: e.lng, icon: CROPS[e.crop].icon, size: 24 + Math.min(12, Math.round(e.acres / 9)),
    dim: !inScope(sel, e.district) || (!!sel.region && e.region !== sel.region), color: CROPS[e.crop].color,
    tip: <div className="an-tip"><img src={estatePhoto(e)} alt="" /><b>{e.name}</b><br />{e.crop} · {e.owner} · {e.acres} acres<br />{label(e.district)}{e.region ? ` · ${e.region}` : ''} · {e.plan}</div>,
  }))
  const cropCard = <CropCard crop={crop} setCrop={setCrop} estates={estates} />
  const rows = [...estates].reverse().map((e) => [e.id, e.name, e.owner, label(e.district), e.province, e.acres, num(e.palms), e.plan, e.registeredOn])


  const sections = () => [
    { title: `Registered lands - ${scopeName(sel)}`, columns: ['ID', 'Land', 'Owner', 'District', 'Province', 'Acres', 'Palms', 'Plan', 'Registered'], rows },
    { title: 'Lands by area', columns: ['Area', 'Lands'], rows: areaBars(sel, perD).map((r) => [r.name, r.value]) },
  ]

  return (
    <PageHead title="Cultivation footprint" sub="Every registered land and what it brings to the platform" name="Estate overview" sel={sel} onSel={setSel} sections={sections}>
      {(
        <div className="an-kpis an-kpis-auto">
          <Kpi photo="rotary" icon="palm" label="Registered lands" value={num(estates.length)} sub={`${num(sumBy(estates, (e) => e.acres))} acres in total`} />
          <Kpi photo="koku_nagula" icon="palm" tone="brown" label="Coconut palms" value={compact(sumBy(estates, (e) => e.palms))} sub={`${num(estates.filter((e) => e.crop === 'Coconut').length)} coconut lands`} />
          <Kpi photo="slasher" icon="users" tone="amber" label="Land owners" value={num(estates.length)} sub={`${pct(estates.filter((e) => e.ownerGender === 1).length, estates.length)} women`} />
          <Kpi photo="disc_plough" icon="pin" tone="blue" label="Average land size" value={`${(sumBy(estates, (e) => e.acres) / (estates.length || 1)).toFixed(1)} ac`} sub={`largest ${Math.max(0, ...estates.map((e) => e.acres))} acres`} />
        </div>
      )}
      <ProvinceStrip startOpen byD={perD} fmt={num} unit="lands" sel={sel} setSel={setSel} {...landStrip(d, sel, setSel, perD)} />
      <Split
        map={
          <Card title="Land footprint" sub="Each pin is a registered land; a taller pin means a bigger land." className="an-card-map">
            <DrillMap
              geo={d.geo} values={perD} fmt={num} unit="lands" sel={sel} onSel={setSel} markers={markers} markerKey={`land-${crop}`}
              overlay={cropCard}
              legend={CROP_LEGEND} height={560}
            />
          </Card>
        }
        side={
          <>
            <Card title="Land types" sub={`${estates.length} lands in ${scopeName(sel)}`}>
              <Donut data={plans} height={170} />
            </Card>
            <Card title="Land by crop" sub="Share of lands for each crop">
              <Donut data={['Coconut', 'Pepper', 'Pineapple'].map((c, i) => ({ name: c, value: estates.filter((e) => e.crop === c).length, color: ['#2f8a4f', '#9c2a23', '#d99a0b'][i], glyph: ['palm', 'pepper', 'pineapple'][i] }))} height={190} />
            </Card>
          </>
        }
      />
      <Card title={`Registered lands · ${scopeName(sel)}`} sub={`${estates.length} lands, newest first`}>
        <DataTable columns={['ID', 'Land', 'Owner', 'District', 'Province', 'Acres', 'Palms', 'Plan', 'Registered']} rows={rows} />
      </Card>
    </PageHead>
  )
}

function Owners({ d, sel, setSel }) {
  const [crop, setCrop] = useState('All')
  const estates = useMemo(() => d.estates.filter((e) => inScope(sel, e.district) && (!sel.region || e.region === sel.region)), [d, sel])
  const perD = useMemo(() => byDistrict(d.estates, () => 1), [d])
  const markers = d.estates.filter((e) => crop === 'All' || e.crop === crop).map((e) => ({
    lat: e.lat, lng: e.lng, icon: CROPS[e.crop].icon, size: 24, color: CROPS[e.crop].color,
    dim: !inScope(sel, e.district) || (!!sel.region && e.region !== sel.region),
    tip: <div className="an-tip"><b>{e.owner}</b><br />{GENDERS[e.ownerGender]} · age {AGE_GROUPS[e.ownerAge]}<br />{e.crop} · {e.name} · {e.acres} acres<br />{label(e.district)}{e.region ? ` · ${e.region}` : ''}</div>,
  }))
  const ownerAge = AGE_GROUPS.map((a, i) => ({ name: a, value: estates.filter((e) => e.ownerAge === i).length }))
  const ownerGender = GENDERS.slice(0, 2).map((g, i) => ({ name: g, value: estates.filter((e) => e.ownerGender === i).length, color: ['#256b45', '#d9741a'][i] }))
  const ageByGender = AGE_GROUPS.map((a, i) => ({
    name: a,
    Male: estates.filter((e) => e.ownerAge === i && e.ownerGender === 0).length,
    Female: estates.filter((e) => e.ownerAge === i && e.ownerGender === 1).length,
  }))
  const wRows = d.workers.filter((w) => inScope(sel, w.district))
  const workerAgeTotal = sumBy(wRows, (w) => w.total) || 1
  const ownerTotal = estates.length || 1
  const ownersVsWorkers = AGE_GROUPS.map((a, i) => ({
    name: a,
    Owners: Math.round((ownerAge[i].value / ownerTotal) * 1000) / 10,
    'Day workers': Math.round((sumBy(wRows, (w) => w.age[i]) / workerAgeTotal) * 1000) / 10,
  }))
  const women = ownerGender[1].value

  const topAge = [...ownerAge].sort((a, b) => b.value - a.value)[0]
  const rows = [...estates].reverse().map((e) => [e.owner, GENDERS[e.ownerGender], AGE_GROUPS[e.ownerAge], e.name, label(e.district), e.region || '-', e.acres])
  const sections = () => [
    { title: `Land owners - ${scopeName(sel)}`, columns: ['Owner', 'Gender', 'Age group', 'Land', 'District', 'CDO area', 'Acres'], rows },
    { title: 'Land owners by age and gender', columns: ['Age group', 'Male', 'Female'], rows: ageByGender.map((r) => [r.name, r.Male, r.Female]) },
  ]
  return (
    <PageHead title="Owner demography" sub="Who owns the registered land" name="Owner demography" sel={sel} onSel={setSel} sections={sections}>
      <PhotoRow
        items={[
          ['rotary', 'users', 'green', 'Land owners', num(estates.length), `${num(sumBy(estates, (e) => e.acres))} acres in total`],
          ['koku_nagula', 'palm', 'brown', 'Coconut land owners', num(estates.filter((e) => e.crop === 'Coconut').length), 'growing coconut'],
          ['disc_plough', 'pin', 'blue', 'Average land size', `${(sumBy(estates, (e) => e.acres) / (estates.length || 1)).toFixed(1)} ac`, `largest ${Math.max(0, ...estates.map((e) => e.acres))} acres`],
          ['slasher', 'trophy', 'amber', 'Corporate plantations', num(estates.filter((e) => e.plan === 'Corporate plantation').length), 'over 25 acres'],
        ]}
      />
      <FigTiles
        items={[
          ['Women', pct(women, estates.length), `${num(women)} owners`, <Character gender="F" stage={2} height={150} />],
          ['Men', pct(estates.length - women, estates.length), `${num(estates.length - women)} owners`, <Character gender="M" stage={2} height={150} />],
          ['Most common age', topAge && topAge.value ? topAge.name : '-', topAge && topAge.value ? `${num(topAge.value)} owners` : '', <Pair stage={Math.max(0, ownerAge.indexOf(topAge))} height={150} />],
        ]}
      />
      <ProvinceStrip startOpen byD={perD} fmt={num} unit="owners" sel={sel} setSel={setSel} {...landStrip(d, sel, setSel, perD, 'Land owners')} />
      <Card title="Where the owners are" sub="Each pin is a land owner, shown by the crop on their land. Click a province or district to drill down." className="an-card-map">
        <DrillMap
          geo={d.geo} values={perD} fmt={num} unit="owners" sel={sel} onSel={setSel} markers={markers} markerKey={`own-${crop}`}
          overlay={<CropCard crop={crop} setCrop={setCrop} estates={estates} />}
          legend={CROP_LEGEND} height={520}
        />
      </Card>
      <div className="an-grid2">
        <AgeCard age={ownerAge} title="Land owners by age" noun="owners" />
        <GenderCard gender={ownerGender} title="Land owners by gender" />
      </div>
      <Card title="Age and gender compared" sub={`${estates.length} owners \u00b7 ${pct(women, estates.length)} women`}>
        <Bars data={ageByGender} keys={['Male', 'Female']} colors={['#256b45', '#d9741a']} height={240} fmt={num} />
      </Card>
      <Card title={`Land owners \u00b7 ${scopeName(sel)}`} sub={`${estates.length} owners, newest first`}>
        <DataTable columns={['Owner', 'Gender', 'Age group', 'Land', 'District', 'CDO area', 'Acres']} rows={rows} />
      </Card>
    </PageHead>
  )
}

// =============================================================================
// Supplier demography: machinery suppliers and fertilizer suppliers
// =============================================================================
const glyphRow = (kinds, colors, size = 54) => (
  <span className="an-own-glyphs" dangerouslySetInnerHTML={{ __html: kinds.map((k, i) => glyphHtml(k, colors[i], Math.round(size * 2.5))).join('') }} />
)

function Suppliers({ d, sel, setSel }) {
  const [kind, setKind] = useState('machinery')
  const bar = (
    <div className="an-filterbar">
      <span>Show</span>
      <Segmented value={kind} onChange={setKind} options={[['machinery', 'Machinery suppliers'], ['fertilizer', 'Fertilizer suppliers']]} />
    </div>
  )
  return kind === 'machinery' ? <MachinerySuppliers d={d} sel={sel} setSel={setSel} bar={bar} /> : <FertilizerSuppliers d={d} sel={sel} setSel={setSel} bar={bar} />
}

function Clients({ d, sel, setSel }) {
  const bar = null
  const share = areaShare(d, sel.district, sel.region)
  const sc = (n) => Math.round(n * share)
  const base = useMemo(() => d.sales.filter((s) => s.year === 2026), [d])
  const scoped = base.filter((s) => inScope(sel, s.district))
  const orders = sc(sumBy(scoped, (s) => s.orders))
  const revenue = sc(sumBy(scoped, (s) => s.revenue))
  const qty = sc(sumBy(scoped, (s) => s.qty))
  const perD = useMemo(() => byDistrict(base, (s) => s.orders), [base])
  const cdoVals = (n) => Math.round((perD[sel.district] || 0) * areaShare(d, sel.district, n))
  const prod = PRODUCTS.map((p) => ({ name: p, color: SALE_CATS[p].color, value: sc(sumBy(scoped.filter((s) => s.product === p), (s) => s.revenue)), orders: sc(sumBy(scoped.filter((s) => s.product === p), (s) => s.orders)) }))
  const topProd = [...prod].sort((a, b) => b.value - a.value)[0]
  const monthly = MONTHS.slice(0, 10).map((m, i) => ({ name: m, Orders: sc(sumBy(scoped.filter((s) => s.month === i + 1), (s) => s.orders)) }))
  const byArea = areaBars(sel, perD)
  const topArea = sel.region ? { name: sel.region, value: orders } : byArea[0]
  const rows = prod.map((p) => [p.name, num(p.orders), rs(p.value), pct(p.value, revenue)])
  const buyers = Math.round(orders / 3.4)
  const mix = peopleMix(`client|${scopeName(sel)}|${sel.region || ''}`, buyers, 0.72, [8, 28, 34, 21, 9])
  const sections = () => [
    { title: `Buyers - ${scopeName(sel)} (2026, Jan-Oct)`, columns: ['Product', 'Orders', 'Revenue', 'Share'], rows },
    { title: 'Orders per month', columns: ['Month', 'Orders'], rows: monthly.map((m) => [m.name, m.Orders]) },
    { title: 'Orders by area', columns: ['Area', 'Orders'], rows: byArea.map((r) => [r.name, r.value]) },
    { title: 'Buyers by gender', columns: ['Gender', 'Buyers'], rows: mix.gender.map((g) => [g.name, g.value]) },
    { title: 'Buyers by age', columns: ['Age', 'Buyers'], rows: mix.age.map((a) => [a.name, a.value]) },
  ]
  return (
    <PageHead title="Client demography" sub="Who buys what the land owners produce" name="Clients" sel={sel} onSel={setSel} sections={sections}>
      {bar}
      <PhotoRow
        items={[
          ['trailer', 'receipt', 'green', 'Buyer orders', num(orders), 'Jan – Oct 2026'],
          ['copra', 'wallet', 'purple', 'Bought for', rs(revenue), `${compact(qty)} items and kg`],
          ['koku_nagula', 'users', 'amber', 'Average order', rs(orders ? revenue / orders : 0), 'value of one order'],
          ['husking', 'trophy', 'brown', 'Most bought', topProd ? topProd.name : '-', topProd ? `${pct(topProd.value, revenue)} of the value` : ''],
        ]}
      />
      <FigTiles
        items={[
          ['Buyers', num(buyers), `${pct(mix.gender[1].value, buyers)} women \u00b7 ${pct(mix.gender[0].value, buyers)} men`, <Pair stage={Math.max(0, mix.age.indexOf([...mix.age].sort((a, b) => b.value - a.value)[0]))} height={96} />],
          [sel.region ? 'CDO area' : sel.province ? 'Top district' : 'Top province', topArea ? topArea.name : '-', `${num(topArea?.value)} orders`, glyphRow(['sack'], ['#d9a441'], 62)],
        ]}
      />
      <ProvinceStrip startOpen byD={perD} fmt={num} unit="orders" sel={sel} setSel={setSel} {...landStrip(d, sel, setSel, perD, 'Buyer orders', cdoVals)} />
      <Card title="Where the buyers are" sub="Buyers who placed orders in 2026. Click a province or district to drill down." className="an-card-map">
        <DrillMap
          geo={d.geo} values={Object.fromEntries(Object.entries(perD).map(([k, v]) => [k, Math.round(v / 3.4)]))} cdoValues={Object.fromEntries((d.cdo ? d.cdo.features.map((x) => x.properties.region) : []).map((n) => [n, Math.round(cdoVals(n) / 3.4)]))}
          fmt={num} unit="buyers" sel={sel} onSel={setSel} scale={AMBER} height={500} badge={personBadge(num)}
        />
      </Card>
      <div className="an-grid2">
        <AgeCard age={mix.age} title="Buyers by age" noun="buyers" />
        <GenderCard gender={mix.gender} title="Buyers by gender" />
      </div>
      <div className="an-grid2">
        <Card title="Orders per month" sub="Jan – Oct 2026">
          <Trend data={monthly} keys={['Orders']} colors={['#d9a441']} area fmt={num} height={220} />
        </Card>
        <Card title="What they buy" sub="Share of the value bought">
          <Donut data={prod} height={190} fmt={rs} />
        </Card>
      </div>
      <Card title={`Buyers \u00b7 ${scopeName(sel)}`} sub="2026, by product">
        <DataTable columns={['Product', 'Orders', 'Bought for', 'Share']} rows={rows} />
      </Card>
    </PageHead>
  )
}

function MachinerySuppliers({ d, sel, setSel, bar }) {
  const [mtype, setMtype] = useState('')
  const ring = sel.region && d.cdo ? d.cdo.features.find((f) => f.properties.region === sel.region)?.geometry.coordinates[0] : null
  const inArea = (m) => inScope(sel, m.district) && (!ring || pointIn(ring, m.lng, m.lat))
  const scoped = useMemo(() => d.machines.filter(inArea), [d, sel])
  const perD = useMemo(() => byDistrict(d.machines, () => 1), [d])
  const cdoCount = (n) => {
    const f = d.cdo?.features.find((x) => x.properties.region === n)
    return f ? d.machines.filter((m) => m.district === 'Kurunegala' && pointIn(f.geometry.coordinates[0], m.lng, m.lat)).length : 0
  }
  const ids = new Set(scoped.map((m) => m.id))
  const bookings = d.bookings.filter((b) => ids.has(b.machine))
  const tl = (t) => MACHINE_TYPES[t].label

  const suppliers = useMemo(() => {
    const by = {}
    scoped.forEach((m) => {
      const s = (by[m.provider] ||= { name: m.provider, machines: 0, available: 0, rate: 0, rating: 0, districts: new Set(), bookings: 0 })
      s.machines += 1
      s.available += m.available ? 1 : 0
      s.rate += m.rate
      s.rating += m.rating
      s.districts.add(m.district)
    })
    bookings.forEach((b) => {
      const m = d.machines.find((x) => x.id === b.machine)
      if (m && by[m.provider]) by[m.provider].bookings += 1
    })
    return Object.values(by).sort((a, b) => b.machines - a.machines)
  }, [scoped, bookings, d])
  const avgRating = scoped.length ? sumBy(scoped, (m) => m.rating) / scoped.length : 0
  const typeMix = Object.keys(MACHINE_TYPES).map((k) => ({ name: tl(k), value: scoped.filter((m) => m.type === k).length, color: MACHINE_TYPES[k].color, glyph: MACHINE_KIND[k] }))
  const staff = Math.round(scoped.length * 1.8)
  const mix = peopleMix(`msup|${scopeName(sel)}|${sel.region || ''}`, staff, 0.9, [6, 30, 36, 20, 8])
  const markers = d.machines.filter((m) => !mtype || tl(m.type) === mtype).map((m) => ({
    lat: m.lat, lng: m.lng, icon: m.type === 'BACKHOE' ? 'backhoe' : m.type === 'HAND_TRACTOR' ? 'hand' : 'tractor', size: 34,
    dim: !inArea(m), color: MACHINE_TYPES[m.type].color,
    tip: <div className="an-tip"><b>{tl(m.type)} · {m.id}</b><br />{m.provider}<br />{label(m.district)} · Rs. {num(m.rate)} · {m.rating}★<br />{m.available ? 'Available' : 'Busy'}</div>,
  }))
  const rows = suppliers.map((s) => [s.name, s.machines, `${s.available} available`, s.districts.size, `Rs. ${num(s.rate / s.machines)}`, (s.rating / s.machines).toFixed(1), s.bookings])
  const sections = () => [
    { title: `Machinery suppliers - ${scopeName(sel)}`, columns: ['Supplier', 'Machines', 'Available', 'Districts', 'Avg rate', 'Rating', 'Bookings'], rows },
    { title: 'Machine types', columns: ['Type', 'Machines'], rows: typeMix.map((t) => [t.name, t.value]) },
  ]
  const top = suppliers[0]
  return (
    <PageHead title="Supplier demography" sub="Who supplies machinery to the land owners" name="Machinery suppliers" sel={sel} onSel={setSel} sections={sections}>
      {bar}
      <PhotoRow
        items={[
          ['backhoe', 'tractor', 'brown', 'Machinery suppliers', num(suppliers.length), 'service providers'],
          ['rotary', 'tractor', 'green', 'Machines listed', num(scoped.length), scopeName(sel)],
          ['hand_tractor', 'check', 'blue', 'Available now', num(scoped.filter((m) => m.available).length), `${pct(scoped.filter((m) => m.available).length, scoped.length)} of the machines`],
          ['disc_plough', 'calendar', 'amber', 'Bookings', num(bookings.length), 'Nov 2025 – Dec 2026'],
          ['trailer', 'tag', 'purple', 'Average rate', rs(scoped.length ? sumBy(scoped, (m) => m.rate) / scoped.length : 0), 'per day or job'],
        ]}
      />
      <FigTiles
        items={[
          ['Average rating', avgRating ? `${avgRating.toFixed(1)} / 5` : '-', 'from the owners who booked', <Pair stage={2} height={150} />],
          ['Biggest supplier', top ? top.name : '-', top ? `${top.machines} machines` : '', glyphRow(['backhoe'], ['#8e44ad'], 60)],
          ['Machine kinds', '3', 'tractor, backhoe, hand tractor', glyphRow(['tractor'], ['#0288d1'], 52)],
        ]}
      />
      <ProvinceStrip startOpen byD={perD} fmt={num} unit="machines" sel={sel} setSel={setSel} {...landStrip(d, sel, setSel, perD, 'Machines', cdoCount)} />
      <Card title="Where the machines are" sub="Each pin is a machine, coloured by type" className="an-card-map">
        <DrillMap
          geo={d.geo} values={perD} fmt={num} unit="machines" sel={sel} onSel={setSel} markers={markers} markerKey={`sup-m-${mtype}`} scale={TERRA} height={500}
          overlay={<MachineCard value={mtype} onChange={setMtype} list={scoped} />}
          legend={Object.keys(MACHINE_TYPES).map((k) => ({ icon: k === 'BACKHOE' ? 'backhoe' : k === 'HAND_TRACTOR' ? 'hand' : 'tractor', color: MACHINE_TYPES[k].color, text: tl(k) }))}
        />
      </Card>
      <div className="an-grid2">
        <AgeCard age={mix.age} title="Owners and operators by age" noun="people" />
        <GenderCard gender={mix.gender} title="Owners and operators by gender" />
      </div>
      <div className="an-grid2">
        <Card title="Machines by supplier" sub={scopeName(sel)}>
          <Bars data={suppliers.slice(0, 10).map((s) => ({ name: s.name, value: s.machines }))} horizontal single height={Math.max(200, Math.min(10, suppliers.length) * 32)} nameWidth={150} fmt={num} />
        </Card>
        <Card title="Machine types" sub="What the suppliers offer">
          <Donut data={typeMix} height={210} />
        </Card>
      </div>
      <Card title={`Machinery suppliers \u00b7 ${scopeName(sel)}`} sub={`${suppliers.length} suppliers`}>
        <DataTable columns={['Supplier', 'Machines', 'Available', 'Districts', 'Avg rate', 'Rating', 'Bookings']} rows={rows} />
      </Card>
    </PageHead>
  )
}

function FertilizerSuppliers({ d, sel, setSel, bar }) {
  const share = areaShare(d, sel.district, sel.region)
  // what each donor gave to the places in view
  const donors = useMemo(
    () =>
      d.donations
        .map((x) => {
          const here = x.areas.filter((a) => inScope(sel, a.district))
          const kg = Math.round(sumBy(here, (a) => a.kg) * share)
          return { ...x, kgHere: kg, reach: here.length, farmers: Math.round(sumBy(here, (a) => a.farmers) * share) }
        })
        .filter((x) => x.kgHere > 0)
        .sort((a, b) => b.kgHere - a.kgHere),
    [d, sel, share],
  )
  const perD = useMemo(() => {
    const rows = []
    d.donations.forEach((x) => x.areas.forEach((a) => rows.push({ district: a.district, kg: a.kg })))
    return byDistrict(rows, (r) => r.kg)
  }, [d])
  const cdoVals = (n) => Math.round((perD[sel.district] || 0) * areaShare(d, sel.district, n))
  const total = sumBy(donors, (x) => x.kgHere)
  const types = FERT_TYPES.map((t, i) => ({ name: t, value: sumBy(donors.filter((x) => x.type === t), (x) => x.kgHere), color: PALETTE[i % PALETTE.length] })).filter((t) => t.value > 0)
  const farmers = sumBy(donors, (x) => x.farmers)
  const staff = Math.round(sumBy(donors, (x) => x.reach) * 3.2)
  const mix = peopleMix(`fsup|${scopeName(sel)}|${sel.region || ''}`, staff, 0.68, [10, 34, 32, 18, 6])
  const rows = donors.map((x) => [x.donor, x.type, x.date, kgText(x.kg), kgText(x.kgHere), `${x.reach} districts`])
  const sections = () => [
    { title: `Fertilizer suppliers - ${scopeName(sel)}`, columns: ['Supplier', 'Fertilizer', 'Date', 'Donated', 'Delivered here', 'Reach'], rows },
    { title: 'Fertilizer types', columns: ['Type', 'Kg'], rows: types.map((t) => [t.name, t.value]) },
  ]
  const top = donors[0]
  return (
    <PageHead title="Supplier demography" sub="Who supplies fertilizer to the land owners" name="Fertilizer suppliers" sel={sel} onSel={setSel} sections={sections}>
      {bar}
      <PhotoRow
        items={[
          ['disc_plough', 'gift', 'blue', 'Fertilizer suppliers', num(donors.length), 'donors reaching here'],
          ['trailer', 'truck', 'green', 'Fertilizer delivered', kgText(total), scopeName(sel)],
          ['koku_nagula', 'users', 'purple', 'Farmers reached', num(farmers), farmers ? `${Math.round(total / farmers)} kg per farmer` : ''],
          ['copra', 'flask', 'amber', 'Fertilizer types', num(types.length), types[0] ? `most: ${[...types].sort((a, b) => b.value - a.value)[0].name}` : ''],
        ]}
      />
      <FigTiles
        items={[
          ['Biggest supplier', top ? top.donor : '-', top ? kgText(top.kgHere) : '', glyphRow(['sack'], ['#256b45'], 64)],
          ['Main fertilizer', types.length ? [...types].sort((a, b) => b.value - a.value)[0].name : '-', 'given the most', glyphRow(['sack'], ['#5fa47b'], 54)],
        ]}
      />
      <ProvinceStrip startOpen byD={perD} fmt={kgText} unit="" sel={sel} setSel={setSel} {...landStrip(d, sel, setSel, perD, 'Fertilizer', cdoVals)} />
      <Card title="Where the fertilizer went" sub="Delivered by all suppliers. Click a province or district to drill down." className="an-card-map">
        <DrillMap geo={d.geo} values={perD} fmt={kgText} unit="" sel={sel} onSel={setSel} scale={BLUE} height={500} badge={sackBadge(kgText)} />
      </Card>
      <div className="an-grid2">
        <AgeCard age={mix.age} title="Supplier field staff by age" noun="people" />
        <GenderCard gender={mix.gender} title="Supplier field staff by gender" />
      </div>
      <div className="an-grid2">
        <Card title="Fertilizer by supplier" sub={scopeName(sel)}>
          <Bars data={donors.slice(0, 10).map((x) => ({ name: x.donor, value: x.kgHere }))} horizontal single height={Math.max(200, Math.min(10, donors.length) * 32)} nameWidth={170} fmt={kgText} />
        </Card>
        <Card title="Fertilizer types" sub="What the suppliers gave">
          <Donut data={types} height={190} fmt={kgText} />
        </Card>
      </div>
      <Card title={`Fertilizer suppliers \u00b7 ${scopeName(sel)}`} sub={`${donors.length} suppliers`}>
        <DataTable columns={['Supplier', 'Fertilizer', 'Date', 'Donated', 'Delivered here', 'Reach']} rows={rows} />
      </Card>
    </PageHead>
  )
}

// =============================================================================
// 2. Day workers
// =============================================================================
function Workers({ d, sel, setSel, extra }) {
  const [cat, setCat] = useState(extra && JOB_CATEGORIES.some((c) => c.name === extra) ? extra : '')
  const all = useMemo(() => d.workers.filter((w) => !cat || w.category === cat), [d, cat])
  const rows = useMemo(() => all.filter((w) => inScope(sel, w.district)), [all, sel])
  const perD = useMemo(() => byDistrict(all, (w) => w.total), [all])

  // A CDO area gets a share of its district's recorded workers.
  const share = areaShare(d, sel.district, sel.region)
  const sc = (n) => Math.round(n * share)
  const cdoNames = d.cdo ? d.cdo.features.map((f) => f.properties.region) : []
  const cdoLevel = sel.district === 'Kurunegala' && cdoNames.length > 0
  const districtTotal = cdoLevel ? sumBy(all.filter((w) => w.district === sel.district), (w) => w.total) : 0
  const cdoVals = cdoLevel ? Object.fromEntries(cdoNames.map((n) => [n, Math.round(districtTotal * areaShare(d, sel.district, n))])) : {}

  const total = sc(sumBy(rows, (w) => w.total))
  const age = AGE_GROUPS.map((a, i) => ({ name: a, value: sc(sumBy(rows, (w) => w.age[i])) }))
  const gender = GENDERS.slice(0, 2).map((g, i) => ({ name: g, value: sc(sumBy(rows, (w) => w.gender[i])), color: ['#256b45', '#d9741a', '#8e44ad'][i] }))
  const est = ESTATE_TYPES.map((e, i) => ({ name: e.split(' (')[0], full: e, value: sc(sumBy(rows, (w) => w.estate[i])) }))
  const cats = JOB_CATEGORIES.map((c) => ({
    name: c.name, value: sc(sumBy(d.workers.filter((w) => w.category === c.name && inScope(sel, w.district)), (w) => w.total)),
    color: cat === c.name ? '#15201a' : '#5fa47b',
  })).sort((a, b) => b.value - a.value)

  const topAge = [...age].sort((a, b) => b.value - a.value)[0]
  const women = gender[1].value
  const byArea = cdoLevel
    ? Object.entries(cdoVals).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value)
    : areaBars(sel, perD)
  const topDistrict = sel.region ? { name: sel.region, value: total } : byArea[0]
  const topProvince = sel.province || topDistrict?.name
  const topLabel = sel.region ? 'CDO area' : cdoLevel ? 'Top CDO area' : sel.province ? 'Top district' : 'Top province'

  const sections = () => [
    { title: `Day workers by category - ${scopeName(sel)}`, columns: ['Category', 'Workers'], rows: cats.map((c) => [c.name, c.value]) },
    { title: `Age groups${cat ? ` - ${cat}` : ''}`, columns: ['Age group', 'Workers'], rows: age.map((a) => [a.name, a.value]) },
    { title: 'Gender', columns: ['Gender', 'Workers'], rows: gender.map((g) => [g.name, g.value]) },
    { title: 'Estate type they want to work in', columns: ['Estate type', 'Workers'], rows: est.map((e) => [e.full, e.value]) },
    { title: 'By area', columns: ['Area', 'Workers'], rows: byArea.map((r) => [r.name, r.value]) },
  ]

  return (
    <PageHead title="Employee demography" sub="The day workers available to the land owners" name="Day workers" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-filterbar">
        <span>Job category</span>
        <Chips value={cat} onChange={setCat} options={JOB_CATEGORIES.map((c) => c.name)} all="All jobs" />
      </div>
      <PhotoRow
        items={[
          ['koku_nagula', 'users', 'green', cat ? `${cat} workers` : 'Day workers', num(total), scopeName(sel) + (sel.region ? ` · ${sel.region}` : '')],
          ['husking', 'users', 'amber', 'Manual work', num(cats.find((c) => c.name === 'Manual work')?.value || 0), 'weeding, husking, clearing'],
          ['slasher', 'users', 'brown', 'Nut gatherers', num(cats.find((c) => c.name === 'Nut Gatherer')?.value || 0), 'gathering fallen nuts'],
          ['rotary', 'tractor', 'blue', 'Machine work', num(cats.find((c) => c.name === 'Machine work')?.value || 0), 'tractors and machines'],
        ]}
      />
      <FigTiles
        items={[
          ['Women / Men', `${pct(women, total)} / ${pct(gender[0].value, total)}`, `${num(women)} women · ${num(gender[0].value)} men`, <Pair stage={1} height={150} />],
          ['Biggest age group', topAge?.name, `${pct(topAge?.value, total)} of workers`, <Pair stage={Math.max(0, age.indexOf(topAge))} height={150} />],
          [topLabel, topDistrict?.name || '-', `${num(topDistrict?.value)} workers`, topProvince && PROVINCE_NAMES.includes(topProvince) ? <img className="an-own-land" src={`/provinces/${slugOf(topProvince)}.png`} alt="" /> : <Character gender="M" stage={3} height={150} />],
        ]}
      />
      <ProvinceStrip startOpen byD={perD} fmt={num} unit="workers" sel={sel} setSel={setSel} {...landStrip(d, sel, setSel, perD, 'Day workers', (n) => cdoVals[n] || 0)} />
      <Split
        map={
          <Card title="Where the workers are" sub={cat ? `Showing ${cat} only` : 'All job categories'} className="an-card-map">
            <DrillMap geo={d.geo} values={perD} fmt={num} unit="workers" sel={sel} onSel={setSel} scale={AMBER} height={540} badge={personBadge(num)} />
          </Card>
        }
        side={
          <>
            <AgeCard age={age} />
            <GenderCard gender={gender} />
          </>
        }
      />
      {cat && (
        <Card className="an-spot-card">
          <JobSpotlight d={d} cat={cat} sel={sel} onClose={() => setCat('')} />
        </Card>
      )}
      <div className="an-grid2">
        <Card title="Job categories" sub="What they do. Click a bar to see the job and filter everything">
          <Bars data={cats} horizontal single height={360} nameWidth={205} thumb={32} photos={jobPhotos()} fmt={num} onPick={(n) => setCat(cat === n ? '' : n)} />
        </Card>
        <Card title="Which estates they want to work in" sub="Size and type of workplace">
          <Bars data={est} horizontal height={360} nameWidth={215} thumb={48} photos={EST_PHOTOS} fmt={num} colors={['#d9741a']} />
        </Card>
      </div>
      <Card title={cdoLevel ? 'By CDO area' : sel.province ? 'By district' : 'By province'} sub="Workers available">
        <DataTable columns={['Area', 'Workers', 'Share']} rows={byArea.map((r) => [r.name, num(r.value), pct(r.value, sumBy(byArea, (x) => x.value))])} />
      </Card>
    </PageHead>
  )
}

// =============================================================================
// 3. Fertilizer
// =============================================================================
const FERT_METRICS = {
  don: { name: 'Donation', label: 'Donated', val: (r) => r.alloc, fmt: kgText, color: '#2f7396', note: 'What donors gave for this area' },
  dist: { name: 'Distribution', label: 'Distributed', val: (r) => r.kg, fmt: kgText, color: '#256b45', note: 'What actually reached farmers' },
  pend: { name: 'Yet to distribute', label: 'Yet to distribute', val: (r) => Math.max(0, r.alloc - r.kg), fmt: kgText, color: '#d08a1f', note: 'Donated but still waiting for delivery' },
  farm: { name: 'Farmers reached', label: 'Farmers reached', val: (r) => r.farmers, fmt: num, color: '#7a4fb0', note: 'Farmers who received fertilizer' },
}

const FERT_TABS = [['overview', 'Overview'], ['donations', 'By donation']]
function Fertilizer({ d, sel, setSel, extra }) {
  const [tab, setTab] = useState(extra === 'donations' ? 'donations' : 'overview')
  const [year, setYear] = useState(2025)
  const [type, setType] = useState('')
  const [metric, setMetric] = useState('dist')
  const [open, setOpen] = useState(extra === 'open')
  const island = !sel.province
  const M = FERT_METRICS[metric]
  const fertYear = useMemo(() => d.fert.filter((f) => f.year === year && (!type || f.type === type)), [d, year, type])
  const areaK = areaShare(d, sel.district, sel.region)
  const scoped = fertYear.filter((f) => inScope(sel, f.district)).map((f) => (sel.region ? { ...f, kg: f.kg * areaK, alloc: f.alloc * areaK, farmers: f.farmers * areaK } : f))
  const perD = useMemo(() => byDistrict(fertYear, FERT_METRICS[metric].val), [fertYear, metric])
  const tot = (k) => sumBy(scoped, FERT_METRICS[k].val)

  const donatedIsland = sumBy(d.donated.filter((x) => x.year === year && (!type || x.type === type)), (x) => x.kg)
  const distributedAll = sumBy(fertYear, (f) => f.kg)
  const farmers = tot('farm')
  const choose = (k) => {
    setMetric(k)
    setOpen(true)
  }

  const yearly = FERT_YEARS.map((y) => ({
    name: String(y),
    Donated: sumBy(d.donated.filter((x) => x.year === y && (!type || x.type === type)), (x) => x.kg),
    Distributed: sumBy(d.fert.filter((f) => f.year === y && (!type || f.type === type) && inScope(sel, f.district)), (f) => f.kg) * areaK,
  }))
  const monthly = MONTHS.map((m, i) => ({ name: m, [M.label]: sumBy(scoped.filter((f) => f.month === i + 1), M.val) }))
  const types = FERT_TYPES.map((t) => ({ name: t, value: sumBy(d.fert.filter((f) => f.year === year && f.type === t && inScope(sel, f.district)), M.val) * areaK }))
  const byArea = areaBars(sel, perD)
  // what each estate got: its district's figure, split by area of land (inside CDO areas for Kurunegala)
  const estVal = useMemo(() => {
    const acres = {}
    const key = (e) => `${e.district}|${e.region || ''}`
    d.estates.forEach((e) => (acres[key(e)] = (acres[key(e)] || 0) + e.acres))
    return Object.fromEntries(d.estates.map((e) => [e.id, (perD[e.district] || 0) * (e.region ? areaShare(d, e.district, e.region) : 1) * (e.acres / (acres[key(e)] || 1))]))
  }, [d, perD])
  const cdoVal = Object.fromEntries((d.cdo ? d.cdo.features.map((f) => f.properties.region) : []).map((n) => [n, (perD.Kurunegala || 0) * areaShare(d, 'Kurunegala', n)]))
  const estHere = d.estates.filter((e) => inScope(sel, e.district) && (!sel.region || e.region === sel.region))
  const estMax = Math.max(1, ...estHere.map((e) => estVal[e.id]))
  const estMarkers = sel.province ? estHere.map((e) => ({
    lat: e.lat, lng: e.lng, icon: 'sack', color: M.color, size: Math.round(20 + (estVal[e.id] / estMax) * 10), label: sel.region || estHere.length <= 14 ? M.fmt(estVal[e.id]) : undefined,
    tip: <div className="an-tip"><b>{e.name}</b><br />{M.label}: {M.fmt(estVal[e.id])}<br />{label(e.district)}{e.region ? ` · ${e.region}` : ''} · {e.acres} acres</div>,
  })) : []
  const top = byArea[0]
  const areaSum = sumBy(byArea, (x) => x.value)

  // every measure for each area, for the table and the report
  const every = Object.fromEntries(
    Object.keys(FERT_METRICS).map((k) => [k, Object.fromEntries(areaBars(sel, byDistrict(fertYear, FERT_METRICS[k].val)).map((r) => [r.name, r.value]))]),
  )
  const areaRows = byArea.map((r) => [r.name, every.don[r.name], every.dist[r.name], every.pend[r.name], every.farm[r.name]])

  const sections = () => [
    { title: `Donated vs distributed by year${island ? '' : ' (distributed in ' + scopeName(sel) + ')'}`, columns: ['Year', 'Donated (kg)', 'Distributed (kg)'], rows: yearly.map((y) => [y.name, island ? y.Donated : 'island-wide only', y.Distributed]) },
    { title: `By area - ${year}`, columns: ['Area', 'Donated (kg)', 'Distributed (kg)', 'Yet to distribute (kg)', 'Farmers reached'], rows: areaRows },
    { title: `By fertilizer type - ${year} (${M.name})`, columns: ['Type', M.name], rows: types.map((t) => [t.name, t.value]) },
    { title: `Monthly - ${year} (${M.name})`, columns: ['Month', M.name], rows: monthly.map((m) => [m.name, m[M.label]]) },
  ]

  if (tab === 'donations') return <Donations d={d} sel={sel} setSel={setSel} tabs={<Segmented value={tab} onChange={setTab} options={FERT_TABS} />} />

  return (
    <PageHead title="Fertilizer" sub="What donors gave, and where it went" name="Fertilizer" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-kpis">
        <Kpi photo="disc_plough" icon="gift" tone="blue" label={`Donation ${year}`} value={kgText(tot('don'))} sub={island ? 'given by donors, island-wide' : scopeName(sel)} onClick={() => choose('don')} active={metric === 'don'} />
        <Kpi photo="trailer" icon="truck" label="Distribution" value={kgText(tot('dist'))} sub={`${pct(tot('dist'), tot('don'))} of the donation delivered`} onClick={() => choose('dist')} active={metric === 'dist'} />
        <Kpi photo="copra" icon="clock" tone="amber" label="Yet to distribute" value={kgText(tot('pend'))} sub="donated, still waiting" onClick={() => choose('pend')} active={metric === 'pend'} />
        <Kpi photo="koku_nagula" icon="users" tone="purple" label="Farmers reached" value={num(farmers)} sub={farmers ? `${Math.round(tot('dist') / farmers)} kg per farmer` : scopeName(sel)} onClick={() => choose('farm')} active={metric === 'farm'} />
        <Kpi photo="rotary" icon="trophy" tone="brown" label={sel.province ? 'Top district' : 'Top province'} value={top?.name || '\u2014'} sub={M.fmt(top?.value)} />
      </div>
      <div className="an-filterbar">
        <Segmented value={tab} onChange={setTab} options={FERT_TABS} />
        <span>Year</span>
        <Segmented value={year} onChange={setYear} options={FERT_YEARS.map((y) => [y, y === 2025 ? '2025 · last year' : y === 2026 ? '2026 · so far' : String(y)])} />
        <span>Type</span>
        <Chips value={type} onChange={setType} options={FERT_TYPES} all="All types" />
      </div>
      <ProvinceStrip startOpen byD={perD} fmt={M.fmt} unit={M.label.toLowerCase()} sel={sel} setSel={setSel} {...landStrip(d, sel, setSel, perD, M.name, (n) => Math.round((perD[sel.district] || 0) * areaShare(d, sel.district, n)))} />
      {top && (
        <Insight>
          In {year}, donors gave <b>{kgText(donatedIsland)}</b> and <b>{pct(distributedAll, donatedIsland)}</b> of it reached {type ? type.toLowerCase() + ' recipients' : 'farmers'} across the island.{' '}
          <b>{top.name}</b> leads on <b>{M.name.toLowerCase()}</b> ({M.fmt(top.value)}, {pct(top.value, areaSum)} of {sel.province ? sel.province : 'the total'}). Click a card above to open its details.
        </Insight>
      )}
      <Split
        map={
          <Card
            title={`${M.name} · ${year}`}
            sub={M.note}
            className="an-card-map"
            right={<button className="an-more an-noprint" onClick={() => setOpen(true)}>Open details</button>}
          >
            <DrillMap
              geo={d.geo} values={perD} cdoValues={cdoVal} fmt={M.fmt} sel={sel} onSel={setSel} height={540} badge={sackBadge(M.fmt)}
              markers={estMarkers} markerKey={`fert-${metric}-${year}-${type}`}
              legend={sel.province ? [{ icon: 'sack', color: M.color, text: `Estate (hover or open a CDO area to see its ${M.label.toLowerCase()})` }] : undefined}
            />
          </Card>
        }
        side={
          <>
            <Card title="Donated vs distributed" sub={island ? 'Each year' : `Distributed in ${scopeName(sel)}`}>
              <Bars data={yearly} keys={island ? ['Donated', 'Distributed'] : ['Distributed']} colors={['#a9cadd', '#2f7396']} height={230} fmt={kgText} />
            </Card>
            <Card title="By fertilizer type" sub={`${M.name} · ${year}`}>
              <Donut data={types} height={160} fmt={M.fmt} />
            </Card>
          </>
        }
      />
      <div className="an-grid2">
        <Card title={`Month by month · ${year}`} sub={`${M.name}. It follows the planting seasons`}>
          <Trend data={monthly} keys={[M.label]} colors={[M.color]} area fmt={M.fmt} height={240} />
        </Card>
        <Card title={sel.province ? 'By district' : 'By province'} sub={`${M.name} · ${year}`}>
          <Bars data={byArea} horizontal single height={Math.max(240, byArea.length * 28)} fmt={M.fmt} axisFmt={metric === 'farm' ? compact : (v) => compact(v / 1000) + 't'} />
        </Card>
      </div>
      <Card title="Everything by area" sub={String(year)}>
        <DataTable
          columns={['Area', 'Donated', 'Distributed', 'Yet to distribute', 'Farmers']}
          rows={areaRows.map((r) => [r[0], kgText(r[1]), kgText(r[2]), kgText(r[3]), num(r[4])])}
        />
      </Card>

      {open && (
        <Modal title={`${M.name} · ${year}`} sub={`${scopeName(sel)}${type ? ' · ' + type : ''}`} onClose={() => setOpen(false)}>
          <Segmented value={metric} onChange={setMetric} options={Object.entries(FERT_METRICS).map(([k, m]) => [k, m.name])} />
          <div className="an-modal-hero">
            <b style={{ color: M.color }}>{M.fmt(tot(metric))}</b>
            <span>{M.note}</span>
          </div>
          <div className="an-modal-stats">
            <div><small>Donated</small><b>{kgText(tot('don'))}</b></div>
            <div><small>Distributed</small><b>{kgText(tot('dist'))}</b></div>
            <div><small>Yet to distribute</small><b>{kgText(tot('pend'))}</b></div>
            <div><small>Farmers</small><b>{num(farmers)}</b></div>
          </div>
          <div className="an-grid2">
            <Card title="Month by month">
              <Trend data={monthly} keys={[M.label]} colors={[M.color]} area fmt={M.fmt} height={210} />
            </Card>
            <Card title="By fertilizer type">
              <Donut data={types} height={160} fmt={M.fmt} />
            </Card>
          </div>
          <Card title={sel.province ? 'Top districts' : 'Top provinces'}>
            <Bars data={byArea.slice(0, 6)} horizontal single height={Math.max(150, Math.min(6, byArea.length) * 30)} fmt={M.fmt} axisFmt={metric === 'farm' ? compact : (v) => compact(v / 1000) + 't'} />
          </Card>
        </Modal>
      )}
    </PageHead>
  )
}

// ---- one donation at a time: where its fertilizer went ---------------------
const SACK = '#a5651e'
function Donations({ d, sel, setSel, tabs }) {
  const [type, setType] = useState('')
  const list = useMemo(() => d.donations.filter((x) => !type || x.type === type), [d, type])
  const [picked, setPicked] = useState(d.donations[0]?.id)
  const don = list.find((x) => x.id === picked) || list[0]

  const rows = useMemo(() => (don ? don.areas : []), [don])
  const perD = useMemo(() => byDistrict(rows, (r) => r.kg), [rows])
  const inArea = rows.filter((r) => inScope(sel, r.district))
  const delivered = sumBy(inArea, (r) => r.kg)
  const farmers = sumBy(inArea, (r) => r.farmers)
  const island = !sel.province
  const left = don ? don.kg - don.delivered : 0
  const maxKg = Math.max(...rows.map((r) => r.kg), 1)
  const byArea = areaBars(sel, perD)

  const markers = inArea.map((r) => {
    const [lat, lng] = d.shapes[r.district].c
    return {
      lat, lng, icon: 'sack', color: SACK, size: Math.round(24 + (r.kg / maxKg) * 14),
      tip: <div><b>{label(r.district)}</b><br />{kgText(r.kg)} delivered<br />{num(r.farmers)} farmers</div>,
    }
  })

  const sections = () => don && [
    { title: `${don.donor} · ${don.type} · ${don.date}`, columns: ['Donated (kg)', 'Distributed (kg)', 'Yet to distribute (kg)', 'Districts reached'], rows: [[don.kg, don.delivered, left, rows.length]] },
    { title: 'Where it was distributed', columns: ['District', 'Province', 'Distributed (kg)', 'Farmers'], rows: [...rows].sort((a, b) => b.kg - a.kg).map((r) => [label(r.district), r.province, r.kg, r.farmers]) },
  ]

  return (
    <PageHead title="Fertilizer" sub="Pick a donation to see where it went" name="Fertilizer donations" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-filterbar">
        {tabs}
        <span>Type</span>
        <Chips value={type} onChange={setType} options={FERT_TYPES} all="All types" />
      </div>
      <div className="an-don-list">
        {list.map((x) => (
          <button key={x.id} className={`an-don ${don?.id === x.id ? 'on' : ''}`} onClick={() => setPicked(x.id)}>
            <span className="an-don-sack" dangerouslySetInnerHTML={{ __html: glyphHtml('sack', SACK, 26) }} />
            <b>{x.donor}</b>
            <small>{x.type} · {kgText(x.kg)}</small>
            <small>{x.date}</small>
            <i><u style={{ width: `${(x.delivered / x.kg) * 100}%` }} /></i>
            <small>{pct(x.delivered, x.kg)} distributed</small>
          </button>
        ))}
        {!list.length && <p className="an-empty">No donations of this type yet.</p>}
      </div>
      {don && (
        <>
          <div className="an-kpis">
            <Kpi photo="disc_plough" icon="gift" tone="blue" label="Donated" value={kgText(don.kg)} sub={`${don.donor} · ${don.type}`} />
            <Kpi photo="trailer" icon="truck" label="Distributed" value={kgText(island ? don.delivered : delivered)} sub={island ? `${pct(don.delivered, don.kg)} of this donation` : scopeName(sel)} />
            <Kpi photo="copra" icon="clock" tone="amber" label="Yet to distribute" value={kgText(left)} sub={`${pct(left, don.kg)} still waiting`} />
            <Kpi photo="koku_nagula" icon="users" tone="purple" label="Farmers reached" value={num(farmers)} sub={farmers ? `${Math.round(delivered / farmers)} kg per farmer` : scopeName(sel)} />
            <Kpi photo="rotary" icon="pin" tone="brown" label="Districts reached" value={`${island ? rows.length : inArea.length} of ${island ? DISTRICTS.length : districtsOf(sel.province).length}`} sub={island ? 'across the island' : scopeName(sel)} />
          </div>
          <Split
            map={
              <Card title={`Where ${don.donor}'s ${don.type.toLowerCase()} went`} sub="Each sack marks a district that received it. Bigger sack, more fertilizer" className="an-card-map">
                <DrillMap
                  geo={d.geo} values={perD} fmt={kgText} unit="delivered" sel={sel} onSel={setSel} markers={markers} markerKey={`don-${don.id}`} height={540}
                  legend={[{ icon: 'sack', color: SACK, text: 'Received this donation' }]}
                />
              </Card>
            }
            side={
              <>
                <Card title="Distributed vs remaining" sub={`${don.donor} · ${kgText(don.kg)} donated`}>
                  <Donut data={[{ name: 'Distributed', value: don.delivered, color: '#256b45' }, { name: 'Yet to distribute', value: left, color: '#e0b45a' }]} height={170} fmt={kgText} />
                </Card>
                <Card title={sel.province ? 'By district' : 'By province'} sub="Fertilizer delivered">
                  <Bars data={byArea} horizontal single height={Math.max(200, byArea.length * 28)} fmt={kgText} axisFmt={(v) => compact(v / 1000) + 't'} />
                </Card>
              </>
            }
          />
          <Card title="Districts that received it" sub={`${don.donor} · ${don.date}`}>
            <DataTable columns={['District', 'Province', 'Distributed', 'Farmers', 'Share']} rows={[...inArea].sort((a, b) => b.kg - a.kg).map((r) => [label(r.district), r.province, kgText(r.kg), num(r.farmers), pct(r.kg, don.delivered)])} />
          </Card>
        </>
      )}
    </PageHead>
  )
}

// =============================================================================
// 4. Machinery
// =============================================================================
function Machinery({ d, sel, setSel, extra }) {
  const [type, setType] = useState('')
  const typeLabel = (t) => MACHINE_TYPES[t].label
  const machines = useMemo(() => d.machines.filter((m) => !type || m.type === Object.keys(MACHINE_TYPES).find((k) => typeLabel(k) === type)), [d, type])
  const ring = sel.region && d.cdo ? d.cdo.features.find((f) => f.properties.region === sel.region)?.geometry.coordinates[0] : null
  const scoped = machines.filter((m) => inScope(sel, m.district) && (!ring || pointIn(ring, m.lng, m.lat)))
  const allScoped = d.machines.filter((m) => inScope(sel, m.district) && (!ring || pointIn(ring, m.lng, m.lat)))
  const ids = new Set(scoped.map((m) => m.id))
  const bookings = d.bookings.filter((b) => ids.has(b.machine))
  const perD = useMemo(() => byDistrict(machines, () => 1), [machines])

  const live = bookings.filter((b) => b.status !== 'Cancelled')
  const listV = sumBy(live, (b) => b.list)
  const agreedV = sumBy(live, (b) => b.agreed)
  const available = scoped.filter((m) => m.available).length

  const typeMix = Object.keys(MACHINE_TYPES).map((k) => ({ name: typeLabel(k), value: scoped.filter((m) => m.type === k).length, color: MACHINE_TYPES[k].color }))
  const status = BOOKING_STATUSES.map((s, i) => ({ name: s, value: bookings.filter((b) => b.status === s).length, color: ['#256b45', '#0288d1', '#d9a441', '#c0392b'][i] }))
  const months = []
  for (let i = 0; i < 14; i++) {
    const dt = new Date(2025, 10 + i, 1)
    const k = dt.toISOString().slice(0, 7)
    months.push({ name: ym(dt.getFullYear(), dt.getMonth() + 1), ...Object.fromEntries(Object.keys(MACHINE_TYPES).map((t) => [typeLabel(t), bookings.filter((b) => b.date.startsWith(k) && b.type === t).length])) })
  }
  const svc = {}
  bookings.forEach((b) => (svc[b.service] = (svc[b.service] || 0) + 1))
  const services = Object.entries(svc).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value).slice(0, 7)
  const byArea = areaBars(sel, perD, '#8b4a1c')
  const markers = machines.map((m) => ({
    lat: m.lat, lng: m.lng, icon: m.type === 'BACKHOE' ? 'backhoe' : m.type === 'HAND_TRACTOR' ? 'hand' : 'tractor', size: 36,
    dim: !inScope(sel, m.district), color: MACHINE_TYPES[m.type].color,
    tip: <div className="an-tip"><img src={`/photos/${m.type === 'BACKHOE' ? 'backhoe' : m.type === 'HAND_TRACTOR' ? 'hand_tractor' : 'rotary'}.jpg`} alt="" /><b>{typeLabel(m.type)} · {m.id}</b><br />{m.provider}<br />{label(m.district)} · {m.available ? 'Available' : 'Busy'}<br />Rs. {num(m.rate)} / {m.type === 'BACKHOE' ? 'hr' : m.type === 'TRACTOR' ? 'acre' : 'day'}</div>,
  }))
  const rows = scoped.map((m) => [m.id, typeLabel(m.type), m.provider, label(m.district), `Rs. ${num(m.rate)}`, m.rating, m.available ? 'Available' : 'Busy'])

  const sections = () => [
    { title: `Machines - ${scopeName(sel)}`, columns: ['ID', 'Type', 'Provider', 'District', 'Rate', 'Rating', 'Status'], rows },
    { title: 'Machines by area', columns: ['Area', 'Machines'], rows: byArea.map((r) => [r.name, r.value]) },
    { title: 'Bookings by status', columns: ['Status', 'Bookings'], rows: status.map((s) => [s.name, s.value]) },
    { title: 'Bookings per month', columns: ['Month', ...Object.values(MACHINE_TYPES).map((t) => t.label)], rows: months.map((m) => [m.name, ...Object.values(MACHINE_TYPES).map((t) => m[t.label])]) },
  ]

  return (
    <PageHead title="Machinery" sub="Where machines are, and how they are booked" name="Machinery" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-kpis">
        <Kpi photo="backhoe" icon="tractor" tone="brown" label="Machines listed" value={num(scoped.length)} sub={scopeName(sel)} />
        <Kpi photo="rotary" icon="check" label="Available now" value={num(available)} sub={pct(available, scoped.length) + ' of fleet'} />
        <Kpi photo="hand_tractor" icon="calendar" tone="blue" label="Bookings" value={num(bookings.length)} sub="Nov 2025 – Dec 2026" />
        <Kpi photo="disc_plough" icon="tag" tone="amber" label="Saved by negotiating" value={listV ? pct(listV - agreedV, listV) : '—'} sub={`${rs(listV - agreedV)} off list price`} />
        <Kpi photo="trailer" icon="wallet" tone="purple" label="Booking value" value={rs(agreedV)} sub="agreed prices" />
      </div>
      <div className="an-filterbar">
        <span>Machine</span>
        <Chips value={type} onChange={setType} options={Object.values(MACHINE_TYPES).map((t) => t.label)} all="All machines" />
      </div>
      <ProvinceStrip startOpen byD={perD} fmt={num} unit="machines" sel={sel} setSel={setSel} color="#8b4a1c" {...landStrip(d, sel, setSel, perD, 'Machines', (n) => machinesIn(d, n, machines))} />
      <Split
        map={
          <Card title="Where the machines are" sub="One icon per machine. The shading shows how many per area." className="an-card-map">
            <DrillMap
              geo={d.geo} values={perD} fmt={num} unit="machines" sel={sel} onSel={setSel} scale={TERRA} markers={markers} markerKey={`mc-${type}`} height={560}
              overlay={<MachineCard value={type} onChange={setType} list={allScoped} />}
              legend={Object.entries(MACHINE_TYPES).map(([k, t]) => ({ icon: k === 'BACKHOE' ? 'backhoe' : k === 'HAND_TRACTOR' ? 'hand' : 'tractor', color: t.color, text: t.label }))}
            />
          </Card>
        }
        side={
          <>
            <FleetCard typeMix={typeMix} machines={scoped} />
            <Card title={sel.province ? 'Machines by district' : 'Machines by province'}>
              <Bars data={byArea} horizontal single height={Math.max(180, byArea.length * 28)} fmt={num} />
            </Card>
          </>
        }
      />
      <Card title="Bookings made through the app" sub="Each month, by machine type. Includes upcoming jobs">
        <Bars data={months} keys={Object.values(MACHINE_TYPES).map((t) => t.label)} colors={Object.values(MACHINE_TYPES).map((t) => t.color)} stacked height={250} fmt={num} />
      </Card>
      <div className="an-grid2">
        <Card title="Booking status" sub="From negotiation to completed job">
          <Donut data={status} height={180} />
        </Card>
        <Card title="What owners book" sub="Most requested services">
          <Bars data={services} horizontal height={230} nameWidth={140} fmt={num} colors={['#8b4a1c']} />
        </Card>
      </div>
      <Card title="Machine list" sub={`${scoped.length} machines`}>
        <DataTable columns={['ID', 'Type', 'Provider', 'District', 'Rate', 'Rating', 'Status']} rows={rows} limit={10} />
      </Card>
    </PageHead>
  )
}

// =============================================================================
// 5. Sales
// =============================================================================
const SALE_CATS = {
  'Raw coconuts': { photo: 'koku_nagula', color: '#256b45', unit: 'nuts', note: 'Whole nuts, husk intact' },
  'Dehusked coconuts': { photo: 'trailer', color: '#d08a1f', unit: 'nuts', note: 'Husk fully removed' },
  'Coconut husks': { photo: 'husking', color: '#8b4a1c', unit: 'kg', note: 'Husk sold on its own' },
}

function Sales({ d, sel, setSel, extra }) {
  const [product, setProduct] = useState('')
  const base = useMemo(() => d.sales.filter((s) => !product || s.product === product), [d, product])
  const areaK = areaShare(d, sel.district, sel.region)
  const scoped = base.filter((s) => inScope(sel, s.district)).map((s) => (sel.region ? { ...s, qty: s.qty * areaK, revenue: s.revenue * areaK, orders: s.orders * areaK } : s))
  const y26 = scoped.filter((s) => s.year === 2026)
  const y25ytd = scoped.filter((s) => s.year === 2025 && s.month <= 10)
  const rev26 = sumBy(y26, (s) => s.revenue)
  const rev25 = sumBy(y25ytd, (s) => s.revenue)
  const perD = useMemo(() => byDistrict(base.filter((s) => s.year === 2026), (s) => s.revenue), [base])

  const monthly = MONTHS.map((m, i) => ({
    name: m,
    ...Object.fromEntries([2024, 2025, 2026].map((y) => [String(y), sumBy(scoped.filter((s) => s.year === y && s.month === i + 1), (s) => s.revenue) || null])),
  }))
  const prod = PRODUCTS.map((p) => ({ name: p, color: SALE_CATS[p].color, value: sumBy(d.sales.filter((s) => s.year === 2026 && s.product === p && inScope(sel, s.district)), (s) => s.revenue) }))
  const yearly = [2024, 2025, 2026].map((y) => ({ name: y === 2026 ? '2026 (Jan–Oct)' : String(y), Revenue: sumBy(scoped.filter((s) => s.year === y), (s) => s.revenue) }))
  const orders = sumBy(y26, (s) => s.orders)
  const growth = rev25 ? Math.round(((rev26 - rev25) / rev25) * 100) : 0
  const byArea = areaBars(sel, perD, '#7a4fb0')
  const topProd = [...prod].sort((a, b) => b.value - a.value)[0]

  const sections = () => [
    { title: `Revenue by year - ${scopeName(sel)}`, columns: ['Year', 'Revenue (Rs)'], rows: yearly.map((y) => [y.name, y.Revenue]) },
    { title: 'Monthly revenue', columns: ['Month', '2024', '2025', '2026'], rows: monthly.map((m) => [m.name, m['2024'] ?? '', m['2025'] ?? '', m['2026'] ?? '']) },
    { title: '2026 revenue by product', columns: ['Product', 'Revenue (Rs)'], rows: prod.map((p) => [p.name, p.value]) },
    { title: '2026 revenue by area', columns: ['Area', 'Revenue (Rs)'], rows: byArea.map((r) => [r.name, r.value]) },
  ]

  return (
    <PageHead title="Sales" sub="Raw coconuts, dehusked coconuts and husks sold through the app" name="Sales" sel={sel} onSel={setSel} sections={sections}>
      <Card title="Coconut price by district" sub="Average price per nut from live listings and deals. Pick a district">
        <PriceMap geo={d.geo} />
      </Card>
      <div className="an-cats">
        {PRODUCTS.map((p) => {
          const c = SALE_CATS[p]
          const rows2026 = d.sales.filter((x) => x.year === 2026 && x.product === p && inScope(sel, x.district))
          const revenue = sumBy(rows2026, (x) => x.revenue)
          const qty = sumBy(rows2026, (x) => x.qty)
          const all2026 = sumBy(d.sales.filter((x) => x.year === 2026 && inScope(sel, x.district)), (x) => x.revenue)
          return (
            <button key={p} className={`an-cat ${product === p ? 'on' : ''}`} onClick={() => setProduct(product === p ? '' : p)} style={{ '--c': c.color }}>
              <span className="an-cat-img" style={{ backgroundImage: `url(/photos/${c.photo}.jpg)` }}>
                <span className="an-cat-share" style={{ background: c.color }}>{pct(revenue, all2026)}</span>
              </span>
              <span className="an-cat-body">
                <b>{p}</b>
                <small>{c.note}</small>
                <strong>{rs(revenue)}</strong>
                <em>{compact(qty)} {c.unit} sold in 2026</em>
              </span>
            </button>
          )
        })}
      </div>
      <ProvinceStrip startOpen byD={perD} fmt={rs} unit="revenue" sel={sel} setSel={setSel} color="#7a4fb0" {...landStrip(d, sel, setSel, perD, 'Sales', (n) => Math.round((perD[sel.district] || 0) * areaShare(d, sel.district, n)))} />
      <div className="an-kpis">
        <Kpi photo="trailer" icon="wallet" tone="purple" label="Revenue 2026" value={rs(rev26)} sub="Jan – Oct" />
        <Kpi photo="copra" icon="trend" label="vs same months 2025" value={`${growth >= 0 ? '+' : ''}${growth}%`} sub={rs(rev25) + ' last year'} />
        <Kpi photo="husking" icon="receipt" tone="blue" label="Orders" value={num(orders)} sub={scopeName(sel)} />
        <Kpi photo="koku_nagula" icon="trophy" tone="amber" label="Best seller" value={topProd?.name || '—'} sub={rs(topProd?.value)} />
        <Kpi photo="rotary" icon="pin" tone="brown" label={sel.province ? 'Top district' : 'Top province'} value={byArea[0]?.name || '—'} sub={rs(byArea[0]?.value)} />
      </div>
      <Split
        map={
          <Card title="Where sales happen" sub="2026 revenue by area" className="an-card-map">
            <DrillMap geo={d.geo} values={perD} fmt={rs} sel={sel} onSel={setSel} scale={['#efe7f7', '#d4bfe9', '#b392d7', '#8c5fbf', '#5d2f93']} height={540} />
          </Card>
        }
        side={
          <>
            <Card title="Revenue by year">
              <Bars data={yearly} keys={['Revenue']} colors={['#7a4fb0']} height={190} fmt={rs} axisFmt={compact} />
            </Card>
            <Card title="Product mix" sub="2026">
              <Donut data={prod} height={160} fmt={rs} />
            </Card>
          </>
        }
      />
      <SalesCalendar rows={scoped} />
      <div className="an-grid2">
        <Card title="Revenue through the year" sub="Compare 2024, 2025 and 2026 month by month">
          <Trend data={monthly} keys={['2024', '2025', '2026']} colors={['#c9b3e3', '#8c5fbf', '#3d1e6d']} fmt={rs} axisFmt={compact} height={250} />
        </Card>
        <Card title={sel.province ? 'By district' : 'By province'} sub="2026 revenue">
          <Bars data={byArea} horizontal single height={Math.max(250, byArea.length * 28)} fmt={rs} axisFmt={compact} />
        </Card>
      </div>
      <Card title="Product table" sub="2026">
        <DataTable columns={['Product', 'Revenue', 'Share']} rows={prod.map((p) => [p.name, `Rs. ${num(p.value)}`, pct(p.value, sumBy(prod, (x) => x.value))])} />
      </Card>
    </PageHead>
  )
}

// ---- sales calendar: revenue day by day ------------------------------------
const dayWeight = (y, m, day) => {
  const x = Math.sin(y * 374.7 + m * 91.3 + day * 17.9) * 10000
  const wd = new Date(y, m - 1, day).getDay()
  return (0.55 + (x - Math.floor(x))) * (wd === 0 ? 0.6 : wd === 6 ? 1.25 : 1)
}
// A small amber star that marks a holiday on the calendar.
function HolidayStar({ label }) {
  return (
    <svg className="an-star" viewBox="0 0 24 24" width="13" height="13" role="img" aria-label={label || 'Holiday'}>
      <path d="M12 2.5l2.9 6.1 6.6.8-4.9 4.6 1.3 6.6L12 17.3 6.1 20.6l1.3-6.6L2.5 9.4l6.6-.8L12 2.5z" fill="#e0a030" stroke="#b9770e" strokeWidth="1" strokeLinejoin="round" />
    </svg>
  )
}
function SalesCalendar({ rows }) {
  const [now, setNow] = useState(() => new Date())
  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 30000) // keeps today's figure moving
    return () => clearInterval(t)
  }, [])
  const ty = now.getFullYear()
  const tm = now.getMonth() + 1
  const td = now.getDate()
  const maxYM = ty * 12 + tm > 2026 * 12 + 10 ? [ty, tm] : [2026, 10]
  const [ym, setYm] = useState(maxYM)
  const [day, setDay] = useState(null)
  const [y, m] = ym
  const [hol, setHol] = useState({})
  useEffect(() => {
    let live = true
    api(`/admin/holidays?year=${y}`)
      .then((r) => {
        if (!live) return
        const map = {}
        for (const h of r.holidays || []) if (!map[h.date] || h.type === 'public') map[h.date] = h
        setHol(map)
      })
      .catch(() => live && setHol({}))
    return () => {
      live = false
    }
  }, [y])
  const holOf = (d) => hol[`${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`]
  const isCur = y === ty && m === tm
  const days = new Date(y, m, 0).getDate()
  const lead = (new Date(y, m - 1, 1).getDay() + 6) % 7 // weeks start on Monday

  // A month with no records yet (the current one) is projected from the last full month.
  const own = rows.filter((r) => r.year === y && r.month === m)
  const src = own.length ? own : rows.filter((r) => r.year === 2026 && r.month === 10)
  const rev = sumBy(src, (r) => r.revenue)
  const ord = sumBy(src, (r) => r.orders)
  const w = Array.from({ length: days }, (_, i) => dayWeight(y, m, i + 1))
  const wSum = sumBy(w, (v) => v)
  const frac = Math.min(1, Math.max(0.03, (now.getHours() * 60 + now.getMinutes()) / 1440))
  const daily = w.map((v, i) => {
    const d = i + 1
    if (isCur && d > td) return null // the future
    const f = isCur && d === td ? frac : 1
    return { rev: Math.round(((rev * v) / wSum) * f), ord: Math.round(((ord * v) / wSum) * f) }
  })
  const seen = daily.filter(Boolean)
  const max = Math.max(...seen.map((x) => x.rev), 1)
  const shownRev = sumBy(seen, (x) => x.rev)
  const shownOrd = sumBy(seen, (x) => x.ord)
  const step = (n) => {
    const t = new Date(y, m - 1 + n, 1)
    const next = [t.getFullYear(), t.getMonth() + 1]
    if (next[0] < 2024 || next[0] * 12 + next[1] > maxYM[0] * 12 + maxYM[1]) return
    setYm(next)
    setDay(null)
  }
  const sel = day ? daily[day - 1] : null
  const bestDay = seen.length ? daily.reduce((b, x, i) => (x && x.rev > (daily[b]?.rev || 0) ? i : b), 0) : 0
  const mix = (p) => {
    const v = sumBy(src.filter((r) => r.product === p), (r) => r.revenue)
    return Math.round(v * ((sel ? sel.rev : shownRev) / (rev || 1)))
  }
  return (
    <Card title="Sales calendar" sub={`Revenue day by day · today is ${now.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}`}>
      <div className="an-cal-wrap">
        <div>
          <div className="an-cal-nav">
            <button onClick={() => step(-1)} disabled={y === 2024 && m === 1} aria-label="Previous month">‹</button>
            <b>{MONTHS[m - 1]} {y}</b>
            <button onClick={() => step(1)} disabled={y * 12 + m >= maxYM[0] * 12 + maxYM[1]} aria-label="Next month">›</button>
          </div>
          <div className="an-cal">
            {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((n) => <div key={n} className="an-cal-h">{n}</div>)}
            {Array.from({ length: lead }, (_, i) => <div key={`b${i}`} className="an-cal-blank" />)}
            {daily.map((x, i) => {
              const d = i + 1
              const today = isCur && d === td
              const h = holOf(d)
              return (
                <button key={d} disabled={!x} title={h ? `${h.name} · ${h.type === 'public' ? 'Public holiday' : 'Observance'}` : undefined} className={`an-cal-d ${day === d ? 'on' : ''} ${today ? 'today' : ''} ${x ? '' : 'future'} ${h ? 'holiday' : ''}`} onClick={() => setDay(day === d ? null : d)}>
                  <span>{h && <HolidayStar label={h.name} />}{today && <em>Today</em>}{d}</span>
                  <strong>{x ? rs(x.rev) : '–'}</strong>
                  <i><u style={{ width: x ? `${(x.rev / max) * 100}%` : 0 }} /></i>
                </button>
              )
            })}
          </div>
          <p className="an-cal-key"><HolidayStar /> Sri Lankan holiday (Google public calendar)</p>
        </div>
        <div className="an-cal-side">
          <h4>{day ? `${day} ${MONTHS[m - 1]} ${y}` : isCur ? `${MONTHS[m - 1]} so far` : `${MONTHS[m - 1]} ${y}`}</h4>
          {day && holOf(day) && <p className="an-cal-hol"><HolidayStar /> {holOf(day).name} · {holOf(day).type === 'public' ? 'Public holiday' : 'Observance'}</p>}
          <b className="big">{rs(sel ? sel.rev : shownRev)}</b>
          <div><span>Orders</span><strong>{num(sel ? sel.ord : shownOrd)}</strong></div>
          {!sel && seen.length > 0 && <div><span>Best day</span><strong>{bestDay + 1} {MONTHS[m - 1]} · {rs(daily[bestDay]?.rev)}</strong></div>}
          {PRODUCTS.map((p) => <div key={p}><span>{p}</span><strong>{rs(mix(p))}</strong></div>)}
        </div>
      </div>
    </Card>
  )
}

// =============================================================================
// ---- statistics for one small region of a district -------------------------
function RegionStats({ d, sel }) {
  const [geo, setGeo] = useState(null)
  useEffect(() => {
    let live = true
    loadRegions().then((g) => live && setGeo(g)).catch(() => {})
    return () => {
      live = false
    }
  }, [])
  const district = sel.district
  const f = useMemo(
    () => (geo ? regionFigures(geo, sel.region, d.estates.filter((e) => e.district === district), d.machines.filter((m) => m.district === district)) : null),
    [geo, d, sel.region, district],
  )
  if (!f) return null
  const workers = sumBy(d.workers.filter((w) => w.district === district), (w) => w.total) * f.share
  const fert = sumBy(d.fert.filter((x) => x.year === 2025 && x.district === district), (x) => x.kg) * f.share
  const sales = sumBy(d.sales.filter((x) => x.year === 2026 && x.district === district), (x) => x.revenue) * f.share
  return (
    <div className="an-area">
      <div className="an-area-head">
        <span className="an-area-pin"><Icon name="pin" size={18} /></span>
        <div>
          <h3>{sel.region}</h3>
          <p>{label(district)} district · figures for this area only</p>
        </div>
        <span className="an-area-chip">{Math.round(f.share * 100)}% of {label(district)}</span>
      </div>
      <div className="an-kpis an-kpis-auto">
        <Kpi photo="rotary" icon="palm" label="Lands" value={num(f.estates.length)} sub={`${num(f.acres)} acres`} />
        <Kpi photo="koku_nagula" icon="palm" tone="brown" label="Palms" value={compact(f.palms)} sub="on coconut land" />
        <Kpi photo="backhoe" icon="tractor" tone="blue" label="Machines" value={num(f.machines)} sub="listed in this area" />
        <Kpi photo="husking" icon="users" tone="amber" label="Day workers" value={num(workers)} sub="estimated share" />
        <Kpi photo="disc_plough" icon="flask" tone="purple" label="Fertilizer (2025)" value={kgText(fert)} sub="estimated share" />
        <Kpi photo="trailer" icon="wallet" label="Sales (2026)" value={rs(sales)} sub="estimated share" />
      </div>
      <p className="an-region-note">Lands, palms and machines are counted from their map positions inside the area. Workers, fertilizer and sales are recorded per district, so this area gets about {Math.round(f.share * 100)}% of {label(district)}.</p>
    </div>
  )
}


// =============================================================================
// Coconut price through the marketplace: Orders -> Deals -> Transactions
// =============================================================================
const STEPS = [
  ['orders', 'Order', 'asked in the order'],
  ['deal', 'Deal', 'agreed in the deal'],
  ['transactions', 'Transaction', 'finally paid'],
]
const lkr2 = (n) => `Rs. ${Number(n).toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`

export function MarketPrices({ stage }) {
  const { data: d } = useData()
  const [sel, setSel] = useState({})
  const [landId, setLandId] = useState(null)
  const [tick, setTick] = useState(0)
  useEffect(() => {
    const t = setInterval(() => setTick((x) => x + 1), 2500)
    return () => clearInterval(t)
  }, [])
  const lands = useMemo(() => (d ? d.estates.filter((e) => e.price) : []), [d])
  if (!d) return <Loading />
  const inArea = (e) => inScope(sel, e.district) && (!sel.region || e.region === sel.region)
  const scoped = lands.filter(inArea)
  const avgOf = (rows, st = stage) => (rows.length ? sumBy(rows, (e) => e.price[st]) / rows.length : 0)
  const perD = Object.fromEntries(DISTRICTS.map((x) => [x.name, avgOf(lands.filter((e) => e.district === x.name))]))
  const cdoNames = d.cdo ? d.cdo.features.map((f) => f.properties.region) : []
  const cdoValues = Object.fromEntries(cdoNames.map((n) => [n, avgOf(lands.filter((e) => e.region === n))]))
  const land = landId ? lands.find((e) => e.id === landId) : null
  // the live price drifts a little, like a market feed
  const live = (e, st) => Math.round(e.price[st] * (1 + 0.011 * Math.sin(tick * 0.9 + Number(e.id.slice(2)))) * 100) / 100
  const stepVal = (st) => (land ? live(land, st) : scoped.length ? avgOf(scoped, st) : null)
  const here = stepVal(stage)
  const low = scoped.length ? Math.min(...scoped.map((e) => e.price[stage])) : null
  const high = scoped.length ? Math.max(...scoped.map((e) => e.price[stage])) : null
  const place = land ? land.name : sel.region || (sel.district ? label(sel.district) : sel.province ? `${sel.province} Province` : 'Sri Lanka')
  const markers = lands.map((e) => ({
    lat: e.lat, lng: e.lng, icon: 'palm', size: e.id === landId ? 34 : 24, color: '#2f8a4f',
    dim: !inArea(e) || (!!landId && e.id !== landId),
    onClick: () => setLandId(e.id === landId ? null : e.id),
    tip: <div className="an-tip"><b>{e.name}</b><br />{label(e.district)} · {lkr2(e.price[stage])}<br />Click to see the live price</div>,
  }))
  const pick = (s) => { setLandId(null); setSel(s) }
  const badge = { html: (v) => `<b class="solo">${v ? 'Rs. ' + Number(v).toFixed(0) : '-'}</b>` }
  const rows = land ? [land] : [...scoped].sort((a, b) => b.price[stage] - a.price[stage]).slice(0, 8)
  const stepName = STEPS.find((x) => x[0] === stage)
  const season = [0.97, 0.98, 1, 1.02, 1.04, 1.03, 1.01, 0.99, 0.98, 0.99, 1.01, 1.02]
  const priceRows = land ? [land] : scoped
  const priceSeries = MONTHS.map((m, i) => ({ name: m, ...Object.fromEntries(STEPS.map(([k, name]) => [name, avgOf(priceRows, k) * season[i]])) }))
  const priceBars = land
    ? STEPS.map(([k, name]) => ({ name, value: land.price[k] }))
    : sel.province
      ? districtsOf(sel.province).filter((x) => perD[x.name] > 0).map((x) => ({ name: label(x.name), value: perD[x.name], color: PROVINCE_COLORS[sel.province] })).sort((a, b) => b.value - a.value)
      : PROVINCE_NAMES.map((p) => {
          const v = districtsOf(p).map((x) => perD[x.name]).filter((x) => x > 0)
          return { name: p, value: v.length ? sumBy(v, (x) => x) / v.length : 0, color: PROVINCE_COLORS[p] }
        }).filter((r) => r.value > 0).sort((a, b) => b.value - a.value)

  return (
    <div className="an-card mp">
      <header>
        <div>
          <h3>Coconut price · {stepName[1]} step</h3>
          <p>Raw coconut, per nut. Pick a province, district or area for the average price, then pick a land for its live price</p>
        </div>
      </header>
      <div className="mp-steps">
        {STEPS.map(([k, name, note], i) => (
          <span key={k} className={`mp-step ${k === stage ? 'on' : ''}`}>
            <i>{i + 1}</i>
            <b>{name}</b>
            <small>{note}</small>
          </span>
        ))}
      </div>
      <div className="pc">
        <div className="pc-map" style={{ position: 'relative' }}>
          <DrillMap
            geo={d.geo} values={perD} agg="avg" cdoValues={cdoValues} fmt={(v) => lkr2(v)} unit="per nut" sel={sel} onSel={pick}
            scale={AMBER} markers={markers} markerKey={`mp-${stage}-${landId}`} badge={badge} height={460}
            legend={[{ icon: 'palm', color: '#2f8a4f', text: 'Coconut land' }]}
          />
        </div>
        <div className="pc-stage mp-stage">
          <div className="pc-show" key={`${place}|${landId}|${stage}`}>
            <Coconut />
            <div className="pc-info">
              <small>{land ? <><span className="mp-live" /> Live price · {label(land.district)}</> : 'Average price'}</small>
              <h3>{place}</h3>
              {here != null ? (
                <>
                  <b className="pc-price"><i>LKR</i>{here.toLocaleString('en-LK', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</b>
                  <span className="pc-per">per nut {land ? '· updates every few seconds' : `· ${scoped.length} coconut lands`}</span>
                  {!land && low != null && (
                    <div className="pc-chips"><em>Low {lkr2(low)}</em><em>High {lkr2(high)}</em></div>
                  )}
                  <div className="mp-ladder">
                    {STEPS.map(([k, name]) => (
                      <div key={k} className={k === stage ? 'on' : ''}>
                        <small>{name}</small>
                        <b>{stepVal(k) != null ? lkr2(stepVal(k)) : '-'}</b>
                      </div>
                    ))}
                  </div>
                </>
              ) : (
                <p className="pc-none">No coconut lands here yet.</p>
              )}
            </div>
          </div>
        </div>
      </div>
      <div className="an-grid2 mv-graphs">
        <div className="mv-graph">
          <b>Price each month · {place}</b>
          <small>Rupees per nut at each step. Sample figures; a little higher in the dry months</small>
          <Trend data={priceSeries} keys={STEPS.map((x) => x[1])} colors={['#2f8a4f', '#d99a0b', '#0288d1']} fmt={(v) => `Rs. ${v.toFixed(0)}`} height={230} tight />
        </div>
        <div className="mv-graph">
          <b>{land ? 'Price at each step' : sel.province ? `Average price by district · ${sel.province}` : 'Average price by province'}</b>
          <small>{land ? 'This land, rupees per nut' : `${STEPS.find((x) => x[0] === stage)[1]} step, rupees per nut`}</small>
          <Bars data={priceBars} horizontal single height={Math.max(230, priceBars.length * 26)} fmt={(v) => `Rs. ${v.toFixed(0)}`} colors={['#cf9526']} />
        </div>
      </div>
      <div className="mp-lands">
        <b>{land ? 'Selected land' : `Lands in ${place}`}</b>
        <div>
          {rows.map((e) => (
            <button key={e.id} className={e.id === landId ? 'on' : ''} onClick={() => setLandId(e.id === landId ? null : e.id)}>
              <span>{e.name}</span>
              <em>{label(e.district)}</em>
              <strong>{lkr2(live(e, stage))}</strong>
            </button>
          ))}
          {!rows.length && <p className="pc-none">No coconut lands here yet.</p>}
        </div>
      </div>
    </div>
  )
}

/** Sales figures that sit with the marketplace steps (shown on the Transactions page). */
const VSTEPS = { orders: 'listed in orders', deal: 'agreed in deals', transactions: 'sold in transactions' }
const nuts = (n) => `${Math.round(n).toLocaleString('en-US')} nuts`

export function MarketVolumes({ stage }) {
  const { data: d } = useData()
  const [sel, setSel] = useState({})
  const [landId, setLandId] = useState(null)
  const lands = useMemo(() => (d ? d.estates.filter((e) => e.volume) : []), [d])
  if (!d) return <Loading />
  const inArea = (e) => inScope(sel, e.district) && (!sel.region || e.region === sel.region)
  const scoped = lands.filter(inArea)
  const vol = (e, st = stage) => e.volume[st]
  const total = (rows, st = stage) => sumBy(rows, (e) => vol(e, st))
  const perD = Object.fromEntries(DISTRICTS.map((x) => [x.name, total(lands.filter((e) => e.district === x.name))]))
  const cdoNames = d.cdo ? d.cdo.features.map((f) => f.properties.region) : []
  const cdoValues = Object.fromEntries(cdoNames.map((n) => [n, total(lands.filter((e) => e.region === n))]))
  const land = landId ? lands.find((e) => e.id === landId) : null
  const place = land ? land.name : sel.region || (sel.district ? label(sel.district) : sel.province ? `${sel.province} Province` : 'Sri Lanka')
  const rowsHere = land ? [land] : scoped
  const here = total(rowsHere)
  const biggest = [...rowsHere].sort((a, b) => vol(b) - vol(a))[0]
  const markers = lands.map((e) => ({
    lat: e.lat, lng: e.lng, icon: 'palm', size: e.id === landId ? 34 : 18 + Math.min(14, Math.round(vol(e) / 450)), color: '#2f8a4f',
    dim: !inArea(e) || (!!landId && e.id !== landId),
    onClick: () => setLandId(e.id === landId ? null : e.id),
    tip: <div className="an-tip"><b>{e.name}</b><br />{label(e.district)} · {nuts(vol(e))} a month<br />Click to see its volume</div>,
  }))
  const pick = (s) => { setLandId(null); setSel(s) }
  const badge = { html: (v) => `<b>${v >= 1000 ? (v / 1000).toFixed(v >= 10000 ? 0 : 1) + 'k' : Math.round(v || 0)}</b>` }
  const rows = land ? [land] : [...scoped].sort((a, b) => vol(b) - vol(a)).slice(0, 8)
  const season = [0.9, 0.85, 0.95, 1, 1.1, 1.1, 1.05, 1, 1, 1.05, 1, 0.95]
  const seasonSum = sumBy(season, (w) => w)
  const monthSeries = MONTHS.map((m, i) => ({ name: m, ...Object.fromEntries(STEPS.map(([k, name]) => [name, (total(rowsHere, k) * season[i]) / seasonSum])) }))

  return (
    <div className="an-card mp">
      <header>
        <div>
          <h3>Coconut volume · {STEPS.find((x) => x[0] === stage)[1]} step</h3>
          <p>Nuts a month {VSTEPS[stage]}. Pick a province, district or area for the total, then pick a land for its own volume</p>
        </div>
      </header>
      <div className="pc">
        <div className="pc-map" style={{ position: 'relative' }}>
          <DrillMap
            geo={d.geo} values={perD} cdoValues={cdoValues} fmt={(v) => nuts(v)} unit="a month" sel={sel} onSel={pick}
            scale={BLUE} markers={markers} markerKey={`mv-${stage}-${landId}`} badge={badge} height={460}
            legend={[{ icon: 'palm', color: '#2f8a4f', text: 'Coconut land (bigger pin, more nuts)' }]}
          />
        </div>
        <div className="pc-stage mp-stage">
          <div className="pc-show" key={`${place}|${landId}|${stage}`}>
            <img className="mv-pile" src="/crops/coconut-pile.png" alt="" />
            <div className="pc-info">
              <small>{land ? `Selected land · ${label(land.district)}` : 'Total volume'}</small>
              <h3>{place}</h3>
              {rowsHere.length ? (
                <>
                  <b className="pc-price">{Math.round(here).toLocaleString('en-US')}<i> nuts</i></b>
                  <span className="pc-per">a month {VSTEPS[stage]}{land ? '' : ` · ${rowsHere.length} coconut lands`}</span>
                  {!land && (
                    <div className="pc-chips">
                      <em>Average {nuts(here / rowsHere.length)} a land</em>
                      {biggest && <em>Biggest {biggest.name} {nuts(vol(biggest))}</em>}
                    </div>
                  )}
                  <div className="mp-ladder">
                    {STEPS.map(([k, name]) => (
                      <div key={k} className={k === stage ? 'on' : ''}>
                        <small>{name}</small>
                        <b>{compact(total(rowsHere, k))}</b>
                      </div>
                    ))}
                  </div>
                </>
              ) : (
                <p className="pc-none">No coconut lands here yet.</p>
              )}
            </div>
          </div>
        </div>
      </div>
      <div className="an-grid2 mv-graphs">
        <div className="mv-graph">
          <b>Volume each month · {place}</b>
          <small>Nuts a month at each step. Sample figures; peaks in the dry months</small>
          <Trend data={monthSeries} keys={STEPS.map((x) => x[1])} colors={['#2f8a4f', '#d99a0b', '#0288d1']} fmt={compact} height={230} />
        </div>
        <div className="mv-graph">
          <b>{land ? 'Volume at each step' : sel.province ? `Volume by district · ${sel.province}` : 'Volume by province'}</b>
          <small>{land ? 'This land, nuts a month' : `${VSTEPS[stage][0].toUpperCase()}${VSTEPS[stage].slice(1)}, nuts a month`}</small>
          {land ? (
            <Bars data={STEPS.map(([k, name]) => ({ name, value: vol(land, k) }))} horizontal single height={230} fmt={num} colors={['#2f8a4f']} />
          ) : (
            <Bars data={areaBars(sel, perD)} horizontal single height={Math.max(230, areaBars(sel, perD).length * 26)} fmt={num} />
          )}
        </div>
      </div>
      <div className="mp-lands">
        <b>{land ? 'Selected land' : `Biggest lands in ${place}`}</b>
        <div>
          {rows.map((e) => (
            <button key={e.id} className={e.id === landId ? 'on' : ''} onClick={() => setLandId(e.id === landId ? null : e.id)}>
              <span>{e.name}</span>
              <em>{label(e.district)}</em>
              <strong>{nuts(vol(e))}</strong>
            </button>
          ))}
          {!rows.length && <p className="pc-none">No coconut lands here yet.</p>}
        </div>
      </div>
    </div>
  )
}

export function SalesSummary() {
  const { data: d } = useData()
  if (!d) return null
  const y26 = d.sales.filter((s) => s.year === 2026)
  const y25 = d.sales.filter((s) => s.year === 2025 && s.month <= 10)
  const rev = sumBy(y26, (s) => s.revenue)
  const prev = sumBy(y25, (s) => s.revenue)
  const growth = prev ? Math.round(((rev - prev) / prev) * 100) : 0
  const orders = sumBy(y26, (s) => s.orders)
  const prod = PRODUCTS.map((p) => ({ name: p, color: SALE_CATS[p].color, value: sumBy(y26.filter((s) => s.product === p), (s) => s.revenue) }))
  const monthly = MONTHS.slice(0, 10).map((m, i) => ({ name: m, Revenue: sumBy(y26.filter((s) => s.month === i + 1), (s) => s.revenue) }))
  return (
    <div className="an-root an-solo">
      <div className="an-kpis an-kpis-auto">
        <Kpi photo="trailer" icon="wallet" tone="purple" label="Sales 2026" value={rs(rev)} sub="Jan – Oct" />
        <Kpi photo="copra" icon="trend" label="vs same months 2025" value={`${growth >= 0 ? '+' : ''}${growth}%`} sub={`${rs(prev)} last year`} />
        <Kpi photo="husking" icon="receipt" tone="blue" label="Orders" value={num(orders)} sub="completed through the app" />
      </div>
      <div className="an-grid2">
        <Card title="Sales by month" sub="2026, Jan – Oct">
          <Trend data={monthly} keys={['Revenue']} colors={['#7a4fb0']} area fmt={rs} height={200} />
        </Card>
        <Card title="What sold" sub="Share of the value, 2026">
          <Donut data={prod} height={170} fmt={rs} />
        </Card>
      </div>
    </div>
  )
}

export default function Analysis({ view }) {
  const { data, error } = useData()
  const [sel, setSel] = useState(() => {
    // Deep link: #an-fert/Western/Gampaha opens Fertilizer already drilled in.
    const [, province, district] = window.location.hash.slice(1).split('/')
    return province && province !== '-' ? { province: decodeURIComponent(province), ...(district && district !== '-' ? { district } : {}) } : {}
  })
  const extra = decodeURIComponent(window.location.hash.slice(1).split('/')[3] || '')
  if (!data) return <Loading error={error} />
  const props = { d: data, sel, setSel, extra }
  return (
    <RegionSlot.Provider value={null}>
    <div className="an-root">
      {view === 'an-overview' && <Overview {...props} />}
      {view === 'an-owners' && <Owners {...props} />}
      {view === 'an-suppliers' && <Suppliers {...props} />}
      {view === 'an-clients' && <Clients {...props} />}
      {view === 'an-workers' && <Workers {...props} />}
      {view === 'an-fert' && <Fertilizer {...props} />}
      {view === 'an-mach' && <Machinery {...props} />}
      {view === 'an-sales' && <Sales {...props} />}
      {LAND_TOPICS[view] && <LandTopic view={view} {...props} />}
    </div>
    </RegionSlot.Provider>
  )
}

export { Bars, Donut, FigTiles, PhotoRow, ProvinceStrip, Split, areaBars, glyphRow, landStrip }

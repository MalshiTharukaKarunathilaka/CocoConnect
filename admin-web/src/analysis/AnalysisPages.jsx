import { useMemo, useState } from 'react'
import { Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Legend, Line, LineChart, Pie, PieChart, XAxis, YAxis } from 'recharts'
import DrillMap, { GREEN_SCALE } from './DrillMap'
import { Character, Pair } from './People'
import {
  AGE_GROUPS, BOOKING_STATUSES, DISTRICTS, ESTATE_TYPES, FERT_TYPES, FERT_YEARS, GENDERS, JOB_CATEGORIES,
  MACHINE_TYPES, MONTHS, PRODUCTS, PROVINCE_COLORS, PROVINCE_NAMES, byDistrict, compact, districtsOf, inScope, kgText, label,
  num, pct, provinceOf, rs, scopeName, sumBy, ym,
} from './data'
import { Card, Chart, Chips, DataTable, GradDefs, Kpi, Loading, Modal, PALETTE, PageHead, Segmented, gid, tipEl, useData } from './ui'

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
              <i style={{ background: d.color || PALETTE[i % PALETTE.length] }} />
              <span>{d.name}</span>
              <b>{pct(d.value, total)}</b>
            </li>
          ))}
        </ul>
      )}
    </div>
  )
}

function GenderCard({ gender }) {
  const total = sumBy(gender, (g) => g.value) || 1
  const [pick, setPick] = useState(0)
  return (
    <Card title="Gender" sub="Tap a person or a slice">
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

function AgeCard({ age }) {
  const total = sumBy(age, (a) => a.value) || 1
  const [pick, setPick] = useState(1)
  const data = age.map((a, i) => ({ ...a, color: i === pick ? '#256b45' : '#a9cdb7' }))
  return (
    <Card title="Age" sub="Tap an age group to meet them">
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
            <small>{num(age[pick].value)} workers</small>
          </div>
        </div>
      </div>
    </Card>
  )
}

function Trend({ data, keys, colors = PALETTE, fmt = compact, axisFmt, height = 240, area }) {
  const Ch = area ? AreaChart : LineChart
  return (
    <div className="an-trend">
    <Chart height={height}>
      <Ch data={data} margin={{ left: -8, right: 14, top: 6 }}>
        <CartesianGrid stroke="#dfe5df" strokeDasharray="2 5" vertical={false} />
        <XAxis dataKey="name" {...ax} />
        <YAxis {...ax} tickFormatter={axisFmt || fmt} />
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
        <span className={`an-plan ${e.plan.toLowerCase()}`}>{e.plan}</span>
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
      {!estates.length && <p className="an-empty">No estates registered here yet.</p>}
    </Card>
  )
}

/** All nine provinces side by side, always island-wide. Folded away until asked for. */
function ProvinceStrip({ byD, fmt, unit, sel, setSel, title = 'Province comparison' }) {
  const [open, setOpen] = useState(() => window.location.hash.includes('provinces'))
  const rows = PROVINCE_NAMES.map((p) => ({ name: p, value: sumBy(districtsOf(p), (d) => byD[d.name] || 0) }))
  const total = sumBy(rows, (r) => r.value)
  const max = Math.max(...rows.map((r) => r.value), 1)
  const avg = total / rows.length
  const ranked = [...rows].sort((a, b) => b.value - a.value)
  const best = ranked[0]
  const low = ranked[ranked.length - 1]
  return (
    <Card
      title={title}
      sub={open ? `All provinces, island-wide \u00b7 ${fmt(total)} ${unit} in total. Click one to open it.` : `${best.name} leads with ${fmt(best.value)} \u00b7 ${low.name} is lowest with ${fmt(low.value)}`}
      className="an-strip-card"
      right={<button className="an-more an-noprint" onClick={() => setOpen(!open)}>{open ? 'Hide provinces \u25b4' : 'View all provinces \u25be'}</button>}
    >
      {!open && (
        <div className="an-strip-mini" title="Share of the total by province">
          {ranked.map((r) => (
            <span key={r.name} style={{ flexGrow: Math.max(r.value, total * 0.01), background: PROVINCE_COLORS[r.name] }} title={`${r.name}: ${fmt(r.value)}`} />
          ))}
        </div>
      )}
      {open && (
        <div className="an-strip an-slide">
          {ranked.map((r, i) => {
            const diff = avg ? Math.round(((r.value - avg) / avg) * 100) : 0
            return (
              <button
                key={r.name}
                className={`an-prov ${sel.province === r.name ? 'on' : ''}`}
                onClick={() => setSel(sel.province === r.name && !sel.district ? {} : { province: r.name })}
              >
                <span className="an-prov-rank">#{i + 1}</span>
                <b>{r.name}</b>
                <strong>{fmt(r.value)}</strong>
                <span className="an-prov-bar"><i style={{ width: `${(r.value / max) * 100}%`, background: PROVINCE_COLORS[r.name] }} /></span>
                <small>
                  {pct(r.value, total)} of total
                  <em className={diff >= 0 ? 'up' : 'down'}>{diff >= 0 ? '\u25b2' : '\u25bc'} {Math.abs(diff)}% vs avg</em>
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
  'Coconut Plucking': { photo: 'koku_nagula', text: 'Climbers and pole-pickers who bring the nuts down every six to eight weeks.' },
  'Husking & Dehusking': { photo: 'husking', text: 'Removing the husk from harvested nuts, ready for sale or copra.' },
  'Weeding & Land Clearing': { photo: 'slasher', text: 'Keeping the ground under the palms clear so they grow well.' },
  'Fertilizer Application': { photo: 'disc_plough', text: 'Spreading fertilizer around each palm, usually twice a year.' },
  'Copra Making & Drying': { photo: 'copra', text: 'Cutting, drying and smoking the kernel into copra.' },
  'Planting & Nursery': { photo: 'rotary', text: 'Raising seedlings and planting new palms.' },
  'Irrigation & Maintenance': { photo: 'backhoe', text: 'Digging channels, mending fences and watering in dry months.' },
  'Transport & Loading': { photo: 'trailer', text: 'Moving nuts from the palms to the road and onto lorries.' },
}

const EST_PHOTOS = {
  'Small holding': 'disc_plough',
  'Medium estate': 'rotary',
  'Large plantation': 'slasher',
  'Copra mill & processing': 'copra',
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
function Overview({ d, sel, setSel, extra }) {
  const estates = useMemo(() => d.estates.filter((e) => inScope(sel, e.district)), [d, sel])
  const perD = useMemo(() => byDistrict(d.estates, () => 1), [d])
  const workers = sumBy(d.workers.filter((w) => inScope(sel, w.district)), (w) => w.total)
  const fert25 = sumBy(d.fert.filter((f) => f.year === 2025 && inScope(sel, f.district)), (f) => f.kg)
  const machines = d.machines.filter((m) => inScope(sel, m.district)).length
  const sales = sumBy(d.sales.filter((s) => s.year === 2026 && inScope(sel, s.district)), (s) => s.revenue)

  const growth = useMemo(() => {
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
        out.push({ name: ym(y, m), Estates: run })
      }
    return out
  }, [estates])

  const plans = ['Basic', 'Standard', 'Premium'].map((p, i) => ({ name: p, value: estates.filter((e) => e.plan === p).length, color: ['#9fd0b0', '#5fa47b', '#256b45'][i] }))
  const markers = d.estates.map((e) => ({
    lat: e.lat, lng: e.lng, icon: 'palm', size: 24 + Math.min(12, Math.round(e.acres / 9)),
    dim: !inScope(sel, e.district), color: '#2f8a4f',
    tip: <div className="an-tip"><img src={estatePhoto(e)} alt="" /><b>{e.name}</b><br />{e.owner} · {e.acres} acres<br />{label(e.district)} · {e.plan}</div>,
  }))
  const rows = [...estates].reverse().map((e) => [e.id, e.name, e.owner, label(e.district), e.province, e.acres, num(e.palms), e.plan, e.registeredOn])
  const top = areaBars(sel, perD)[0]

  const sections = () => [
    { title: `Registered estates - ${scopeName(sel)}`, columns: ['ID', 'Estate', 'Owner', 'District', 'Province', 'Acres', 'Palms', 'Plan', 'Registered'], rows },
    { title: 'Estates by area', columns: ['Area', 'Estates'], rows: areaBars(sel, perD).map((r) => [r.name, r.value]) },
  ]

  return (
    <PageHead title="Analysis dashboard" sub="Every subscribed estate and what it brings to the platform" name="Estate overview" sel={sel} onSel={setSel} sections={sections}>
      <ProvinceStrip byD={perD} fmt={num} unit="estates" sel={sel} setSel={setSel} title="Estates by province" />
      <div className="an-kpis">
        <Kpi icon="palm" label="Registered estates" value={num(estates.length)} sub={`${num(sumBy(estates, (e) => e.acres))} acres · ${compact(sumBy(estates, (e) => e.palms))} palms`} />
        <Kpi icon="users" tone="amber" label="Day workers available" value={num(workers)} sub="looking for estate work" />
        <Kpi icon="flask" tone="blue" label="Fertilizer distributed (2025)" value={kgText(fert25)} />
        <Kpi icon="tractor" tone="brown" label="Machines listed" value={num(machines)} sub="tractors · backhoes · hand tractors" />
        <Kpi icon="wallet" tone="purple" label="Sales this year" value={rs(sales)} sub="Jan – Oct 2026" />
      </div>
      <Split
        map={
          <Card title="Estate footprint" sub="Each palm is a subscribed estate; a taller palm means a bigger estate." className="an-card-map">
            <DrillMap
              geo={d.geo} values={perD} fmt={num} unit="estates" sel={sel} onSel={setSel} markers={markers} markerKey="est"
              legend={[{ icon: 'palm', color: '#2f8a4f', text: 'Subscribed estate' }]} height={560}
            />
          </Card>
        }
        side={
          <>
            <Card title={sel.province ? 'Estates by district' : 'Estates by province'} sub={top ? `${top.name} leads with ${top.value}` : ''}>
              <Bars data={areaBars(sel, perD)} horizontal single height={Math.max(180, areaBars(sel, perD).length * 30)} fmt={num} />
            </Card>
            <Card title="Subscription growth" sub="Cumulative registered estates">
              <Trend data={growth} keys={['Estates']} colors={['#256b45']} area fmt={num} height={190} />
            </Card>
            <Card title="Plan mix">
              <Donut data={plans} height={150} />
            </Card>
          </>
        }
      />
      <EstateCards estates={estates} title={`Estates in ${scopeName(sel)}`} sub="Newest subscribers first" />
      <Card title={`Registered estates · ${scopeName(sel)}`} sub={`${estates.length} estates, newest first`}>
        <DataTable columns={['ID', 'Estate', 'Owner', 'District', 'Province', 'Acres', 'Palms', 'Plan', 'Registered']} rows={rows} />
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

  const total = sumBy(rows, (w) => w.total)
  const age = AGE_GROUPS.map((a, i) => ({ name: a, value: sumBy(rows, (w) => w.age[i]) }))
  const gender = GENDERS.slice(0, 2).map((g, i) => ({ name: g, value: sumBy(rows, (w) => w.gender[i]), color: ['#256b45', '#d9741a', '#8e44ad'][i] }))
  const est = ESTATE_TYPES.map((e, i) => ({ name: e.split(' (')[0], full: e, value: sumBy(rows, (w) => w.estate[i]) }))
  const cats = JOB_CATEGORIES.map((c) => ({
    name: c.name, value: sumBy(d.workers.filter((w) => w.category === c.name && inScope(sel, w.district)), (w) => w.total),
    color: cat === c.name ? '#15201a' : '#5fa47b',
  })).sort((a, b) => b.value - a.value)

  const topAge = [...age].sort((a, b) => b.value - a.value)[0]
  const women = gender[1].value
  const topDistrict = areaBars(sel, perD)[0]
  const byArea = areaBars(sel, perD)

  const sections = () => [
    { title: `Day workers by category - ${scopeName(sel)}`, columns: ['Category', 'Workers'], rows: cats.map((c) => [c.name, c.value]) },
    { title: `Age groups${cat ? ` - ${cat}` : ''}`, columns: ['Age group', 'Workers'], rows: age.map((a) => [a.name, a.value]) },
    { title: 'Gender', columns: ['Gender', 'Workers'], rows: gender.map((g) => [g.name, g.value]) },
    { title: 'Estate type they want to work in', columns: ['Estate type', 'Workers'], rows: est.map((e) => [e.full, e.value]) },
    { title: 'By area', columns: ['Area', 'Workers'], rows: byArea.map((r) => [r.name, r.value]) },
  ]

  return (
    <PageHead title="Day workers" sub="People who want day work on estates" name="Day workers" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-filterbar">
        <span>Job category</span>
        <Chips value={cat} onChange={setCat} options={JOB_CATEGORIES.map((c) => c.name)} all="All jobs" />
      </div>
      <ProvinceStrip byD={perD} fmt={num} unit="workers" sel={sel} setSel={setSel} color="#d9a441" title="Day workers by province" />
      <div className="an-kpis">
        <Kpi icon="users" label={cat ? `${cat} workers` : 'Day workers'} value={num(total)} sub={scopeName(sel)} />
        <Kpi icon="user" tone="amber" label="Women / Men" value={`${pct(women, total)} / ${pct(gender[0].value, total)}`} sub={`${num(women)} women · ${num(gender[0].value)} men`} />
        <Kpi icon="clock" tone="blue" label="Biggest age group" value={topAge?.name} sub={`${pct(topAge?.value, total)} of workers`} />
        <Kpi icon="pin" tone="brown" label={sel.province ? 'Top district' : 'Top province'} value={topDistrict?.name || '—'} sub={`${num(topDistrict?.value)} workers`} />
        <Kpi icon="briefcase" tone="purple" label="Job categories" value={cat ? '1 of 8' : '8'} sub="from plucking to transport" />
      </div>
      <Split
        map={
          <Card title="Where the workers are" sub={cat ? `Showing ${cat} only` : 'All job categories'} className="an-card-map">
            <DrillMap geo={d.geo} values={perD} fmt={num} unit="workers" sel={sel} onSel={setSel} scale={AMBER} height={540} />
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
      <Card title={sel.province ? 'By district' : 'By province'} sub="Workers available">
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

function Fertilizer({ d, sel, setSel, extra }) {
  const [year, setYear] = useState(2025)
  const [type, setType] = useState('')
  const [metric, setMetric] = useState('dist')
  const [open, setOpen] = useState(extra === 'open')
  const island = !sel.province
  const M = FERT_METRICS[metric]
  const fertYear = useMemo(() => d.fert.filter((f) => f.year === year && (!type || f.type === type)), [d, year, type])
  const scoped = fertYear.filter((f) => inScope(sel, f.district))
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
    Distributed: sumBy(d.fert.filter((f) => f.year === y && (!type || f.type === type) && inScope(sel, f.district)), (f) => f.kg),
  }))
  const monthly = MONTHS.map((m, i) => ({ name: m, [M.label]: sumBy(scoped.filter((f) => f.month === i + 1), M.val) }))
  const types = FERT_TYPES.map((t) => ({ name: t, value: sumBy(d.fert.filter((f) => f.year === year && f.type === t && inScope(sel, f.district)), M.val) }))
  const byArea = areaBars(sel, perD)
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

  return (
    <PageHead title="Fertilizer" sub="What donors gave, and where it went" name="Fertilizer" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-filterbar">
        <span>Year</span>
        <Segmented value={year} onChange={setYear} options={FERT_YEARS.map((y) => [y, y === 2025 ? '2025 · last year' : y === 2026 ? '2026 · so far' : String(y)])} />
        <span>Type</span>
        <Chips value={type} onChange={setType} options={FERT_TYPES} all="All types" />
      </div>
      <ProvinceStrip byD={perD} fmt={M.fmt} unit={M.label.toLowerCase()} sel={sel} setSel={setSel} title={`${M.name} by province · ${year}`} />
      <div className="an-kpis">
        <Kpi icon="gift" tone="blue" label={`Donation ${year}`} value={kgText(tot('don'))} sub={island ? 'given by donors, island-wide' : scopeName(sel)} onClick={() => choose('don')} active={metric === 'don'} />
        <Kpi icon="truck" label="Distribution" value={kgText(tot('dist'))} sub={`${pct(tot('dist'), tot('don'))} of the donation delivered`} onClick={() => choose('dist')} active={metric === 'dist'} />
        <Kpi icon="clock" tone="amber" label="Yet to distribute" value={kgText(tot('pend'))} sub="donated, still waiting" onClick={() => choose('pend')} active={metric === 'pend'} />
        <Kpi icon="users" tone="purple" label="Farmers reached" value={num(farmers)} sub={farmers ? `${Math.round(tot('dist') / farmers)} kg per farmer` : scopeName(sel)} onClick={() => choose('farm')} active={metric === 'farm'} />
        <Kpi icon="trophy" tone="brown" label={sel.province ? 'Top district' : 'Top province'} value={top?.name || '\u2014'} sub={M.fmt(top?.value)} />
      </div>
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
            <DrillMap geo={d.geo} values={perD} fmt={M.fmt} sel={sel} onSel={setSel} height={540} />
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

// =============================================================================
// 4. Machinery
// =============================================================================
function Machinery({ d, sel, setSel, extra }) {
  const [type, setType] = useState('')
  const typeLabel = (t) => MACHINE_TYPES[t].label
  const machines = useMemo(() => d.machines.filter((m) => !type || m.type === Object.keys(MACHINE_TYPES).find((k) => typeLabel(k) === type)), [d, type])
  const scoped = machines.filter((m) => inScope(sel, m.district))
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
      <div className="an-filterbar">
        <span>Machine</span>
        <Chips value={type} onChange={setType} options={Object.values(MACHINE_TYPES).map((t) => t.label)} all="All machines" />
      </div>
      <ProvinceStrip byD={perD} fmt={num} unit="machines" sel={sel} setSel={setSel} color="#8b4a1c" title="Machines by province" />
      <div className="an-kpis">
        <Kpi icon="tractor" tone="brown" label="Machines listed" value={num(scoped.length)} sub={scopeName(sel)} />
        <Kpi icon="check" label="Available now" value={num(available)} sub={pct(available, scoped.length) + ' of fleet'} />
        <Kpi icon="calendar" tone="blue" label="Bookings" value={num(bookings.length)} sub="Nov 2025 – Dec 2026" />
        <Kpi icon="tag" tone="amber" label="Saved by negotiating" value={listV ? pct(listV - agreedV, listV) : '—'} sub={`${rs(listV - agreedV)} off list price`} />
        <Kpi icon="wallet" tone="purple" label="Booking value" value={rs(agreedV)} sub="agreed prices" />
      </div>
      <Split
        map={
          <Card title="Where the machines are" sub="One icon per machine. The shading shows how many per area." className="an-card-map">
            <DrillMap
              geo={d.geo} values={perD} fmt={num} unit="machines" sel={sel} onSel={setSel} scale={TERRA} markers={markers} markerKey={`mc-${type}`} height={560}
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
  const scoped = base.filter((s) => inScope(sel, s.district))
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
      <ProvinceStrip byD={perD} fmt={rs} unit="revenue" sel={sel} setSel={setSel} color="#7a4fb0" title="Sales by province · 2026" />
      <div className="an-kpis">
        <Kpi icon="wallet" tone="purple" label="Revenue 2026" value={rs(rev26)} sub="Jan – Oct" />
        <Kpi icon="trend" label="vs same months 2025" value={`${growth >= 0 ? '+' : ''}${growth}%`} sub={rs(rev25) + ' last year'} />
        <Kpi icon="receipt" tone="blue" label="Orders" value={num(orders)} sub={scopeName(sel)} />
        <Kpi icon="trophy" tone="amber" label="Best seller" value={topProd?.name || '—'} sub={rs(topProd?.value)} />
        <Kpi icon="pin" tone="brown" label={sel.province ? 'Top district' : 'Top province'} value={byArea[0]?.name || '—'} sub={rs(byArea[0]?.value)} />
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

// =============================================================================
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
    <div className="an-root">
      {view === 'an-overview' && <Overview {...props} />}
      {view === 'an-workers' && <Workers {...props} />}
      {view === 'an-fert' && <Fertilizer {...props} />}
      {view === 'an-mach' && <Machinery {...props} />}
      {view === 'an-sales' && <Sales {...props} />}
    </div>
  )
}

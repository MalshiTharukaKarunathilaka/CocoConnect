import { useMemo, useState } from 'react'
import DrillMap from './DrillMap'
import { glyphHtml } from './pins'
import { Bars, Donut, FigTiles, PhotoRow, ProvinceStrip, Split, areaBars, glyphRow, landStrip } from './AnalysisPages'
import { MONTHS, compact, inScope, kgText, label, num, pct, rs, scopeName, sumBy } from './data'
import { Card, DataTable, PageHead } from './ui'

// =============================================================================
// Land topics: Cultivation Type, Agri Tourism, Aquaculture, Animal Husbandry,
// Green Energy and Environment (carbon). Every land gets a sample record for each
// topic, worked out from the land itself, so the same land shows up everywhere.
// =============================================================================

const hr = (id, salt) => {
  let x = 2166136261
  for (const c of `${id}|${salt}`) x = Math.imul(x ^ c.charCodeAt(0), 16777619)
  x ^= x >>> 15
  x = Math.imul(x, 2246822519)
  return ((x ^ (x >>> 13)) >>> 0) % 100000 / 100000
}
const pickOf = (arr, r) => arr[Math.min(arr.length - 1, Math.floor(r * arr.length))]
const monthly = (total, weights) => {
  const s = sumBy(weights, (w) => w) || 1
  return weights.map((w) => (total * w) / s)
}
const t1 = (n) => `${(Math.round(n * 10) / 10).toLocaleString('en-US')} t`

const TOUR = [
  { name: 'Plantation tour', color: '#2f8a4f', glyph: 'tent', price: 2500 },
  { name: 'Farm stay', color: '#0288d1', glyph: 'house', price: 6500 },
  { name: 'Coconut experience', color: '#d99a0b', glyph: 'cup', price: 3200 },
  { name: 'Farm-to-table meals', color: '#8b4a1c', glyph: 'plate', price: 2800 },
]
const AQUA = [
  { name: 'Tilapia', color: '#0288d1', glyph: 'fish', perAcre: 2600, price: 520 },
  { name: 'Freshwater prawn', color: '#d9741a', glyph: 'fish', perAcre: 1100, price: 1800 },
  { name: 'Carp', color: '#8e44ad', glyph: 'fish', perAcre: 2200, price: 450 },
  { name: 'Ornamental fish', color: '#d99a0b', glyph: 'fish', perAcre: 800, price: 3000 },
]
const ANIMAL = [
  { name: 'Dairy cattle', color: '#5d4037', glyph: 'cow', unit: 'cattle', lo: 2, hi: 25, perHead: 38000, co2: 2.3 },
  { name: 'Goats', color: '#9c7b5b', glyph: 'goat', unit: 'goats', lo: 5, hi: 60, perHead: 9000, co2: 0.2 },
  { name: 'Poultry', color: '#c0392b', glyph: 'hen', unit: 'birds', lo: 30, hi: 600, perHead: 480, co2: 0.01 },
  { name: 'Bee keeping', color: '#d99a0b', glyph: 'hive', unit: 'hives', lo: 5, hi: 40, perHead: 4200, co2: 0 },
]
const CULT = [
  { name: 'Monoculture', color: '#2f8a4f', glyph: 'sprout', perAcre: 95000 },
  { name: 'Intercropped', color: '#2f8a4f', glyph: 'sprouts', perAcre: 150000 },
  { name: 'Mixed home garden', color: '#b5803c', glyph: 'basket', perAcre: 125000 },
  { name: 'Organic', color: '#43a047', glyph: 'leaf', perAcre: 140000 },
]
const INTER = ['Banana', 'Cinnamon', 'Cocoa', 'Ginger', 'Turmeric', 'Papaya', 'Pepper', 'Pineapple']
const ENERGY = [
  { name: 'Solar panels', color: '#1565c0', glyph: 'solar', lo: 2, hi: 25, perKw: 1400 },
  { name: 'Solar water pump', color: '#0288d1', glyph: 'drop', lo: 1, hi: 5, perKw: 1300 },
  { name: 'Biogas unit', color: '#ef6c00', glyph: 'flame', lo: 1, hi: 6, perKw: 1800 },
  { name: 'Coconut-shell biomass', color: '#8b4a1c', glyph: 'shell', lo: 5, hi: 30, perKw: 1100 },
]
const ENV = [
  { name: 'Stores carbon', color: '#2f8a4f', glyph: 'cloud' },
  { name: 'Emits more', color: '#c0392b', glyph: 'cloud' },
]
const GRID_KG = 0.45 // kg of CO2 saved for each kWh that does not come from the grid
const BILL = 38 // rupees per kWh

const cache = new WeakMap()
function topicRows(d) {
  if (cache.has(d)) return cache.get(d)
  const out = { cult: [], tour: [], aqua: [], animal: [], energy: [], env: [] }
  for (const e of d.estates) {
    const a = e.acres
    // cultivation type: every land
    const ct = pickOf(CULT, hr(e.id, 'cult'))
    const together = ct.name === 'Intercropped' || ct.name === 'Mixed home garden'
      ? [pickOf(INTER.filter((x) => x !== e.crop), hr(e.id, 'i1')), ...(hr(e.id, 'i2') > 0.55 ? [pickOf(INTER.filter((x) => x !== e.crop), hr(e.id, 'i3'))] : [])]
      : []
    out.cult.push({ e, cat: ct.name, together: [...new Set(together)], money: a * ct.perAcre * (0.85 + hr(e.id, 'ci') * 0.3) })
    // agri tourism: about one land in four
    if (hr(e.id, 'tour') < 0.27) {
      const t = pickOf(TOUR, hr(e.id, 't1'))
      const visitors = Math.round(180 + hr(e.id, 't2') * 2600 * (0.6 + Math.min(a, 30) / 40))
      const foreign = 0.2 + hr(e.id, 't3') * 0.5
      out.tour.push({ e, cat: t.name, visitors, foreign, money: visitors * t.price, rating: Math.round((3.8 + hr(e.id, 't4') * 1.2) * 10) / 10 })
    }
    // aquaculture: about one land in six
    if (hr(e.id, 'aqua') < 0.17) {
      const s = pickOf(AQUA, hr(e.id, 'a1'))
      const pond = Math.max(0.2, Math.round(a * (0.04 + hr(e.id, 'a2') * 0.1) * 10) / 10)
      const kg = Math.round(pond * s.perAcre * (0.8 + hr(e.id, 'a3') * 0.4))
      out.aqua.push({ e, cat: s.name, pond, kg, money: kg * s.price })
    }
    // animal husbandry: about two lands in five
    if (hr(e.id, 'ani') < 0.42) {
      const k = pickOf(ANIMAL, hr(e.id, 'n1'))
      const count = Math.round(k.lo + hr(e.id, 'n2') * (k.hi - k.lo))
      const cattle = k.name === 'Dairy cattle'
      out.animal.push({ e, cat: k.name, count, unit: k.unit, milk: cattle ? count * 8 : 0, eggs: k.name === 'Poultry' ? Math.round(count * 0.7) : 0, money: (count * k.perHead) / 12, co2: count * k.co2 })
    }
    // green energy: about one land in three
    if (hr(e.id, 'en') < 0.34) {
      const s = pickOf(ENERGY, hr(e.id, 'e1'))
      const kw = Math.round((s.lo + hr(e.id, 'e2') * (s.hi - s.lo)) * 10) / 10
      const kwh = Math.round(kw * s.perKw * (0.9 + hr(e.id, 'e3') * 0.2))
      out.energy.push({ e, cat: s.name, kw, kwh, co2: (kwh * GRID_KG) / 1000, money: kwh * BILL })
    }
  }
  const byId = (list) => Object.fromEntries(list.map((r) => [r.e.id, r]))
  const animals = byId(out.animal)
  const energy = byId(out.energy)
  for (const e of d.estates) {
    const a = e.acres
    const fuel = a * (0.14 + hr(e.id, 'v1') * 0.16)
    const fert = a * (0.2 + hr(e.id, 'v2') * 0.3)
    const live = animals[e.id]?.co2 || 0
    const waste = a * 0.05 * (0.5 + hr(e.id, 'v3'))
    const emit = fuel + fert + live + waste
    const seq = e.crop === 'Coconut' ? e.palms * (0.025 + hr(e.id, 'v4') * 0.02) : a * (e.crop === 'Pepper' ? 0.5 + hr(e.id, 'v4') * 0.8 : 0.3 + hr(e.id, 'v4') * 0.5)
    const avoided = energy[e.id]?.co2 || 0
    const balance = seq + avoided - emit
    out.env.push({ e, cat: balance >= 0 ? ENV[0].name : ENV[1].name, fuel, fert, live, waste, emit, seq, avoided, balance, money: emit })
  }
  cache.set(d, out)
  return out
}

function CatCard({ title, cats, value, onChange, rows }) {
  return (
    <div className="an-crop-card an-noprint">
      <b>{title}</b>
      <button className={!value ? 'on' : ''} onClick={() => onChange('')}>
        <i className="all" />
        <span>All</span>
        <em>{rows.length}</em>
      </button>
      {cats.map((c) => (
        <button key={c.name} className={value === c.name ? 'on' : ''} onClick={() => onChange(value === c.name ? '' : c.name)}>
          <span className="an-crop-ic" dangerouslySetInnerHTML={{ __html: glyphHtml(c.glyph, c.color, 20) }} />
          <span>{c.name}</span>
          <em>{rows.filter((r) => r.cat === c.name).length}</em>
        </button>
      ))}
    </div>
  )
}

/** One page: stat cards, comparison cards, map, charts and a table, all for one topic. */
function TopicPage({ d, sel, setSel, spec }) {
  const [cat, setCat] = useState('')
  const all = useMemo(() => spec.rows(topicRows(d)), [d, spec])
  const here = (r) => inScope(sel, r.e.district) && (!sel.region || r.e.region === sel.region)
  const pool = all.filter((r) => !cat || r.cat === cat)
  const scoped = pool.filter(here)
  const mv = spec.mapVal || (() => 1)
  const perD = useMemo(() => {
    const t = {}
    pool.forEach((r) => (t[r.e.district] = (t[r.e.district] || 0) + mv(r)))
    return t
  }, [pool, mv])
  const byCat = spec.cats.map((c) => ({ name: c.name, value: scoped.filter((r) => r.cat === c.name).length, color: c.color, glyph: c.glyph }))
  const catOf = (n) => spec.cats.find((c) => c.name === n)
  const markers = all.map((r) => ({
    lat: r.e.lat, lng: r.e.lng, icon: catOf(r.cat).glyph, size: 30, color: catOf(r.cat).color,
    dim: !here(r) || (!!cat && r.cat !== cat),
    tip: <div className="an-tip"><b>{r.e.name}</b><br />{r.cat}<br />{spec.tip(r)}<br />{label(r.e.district)}{r.e.region ? ` · ${r.e.region}` : ''}</div>,
  }))
  const cdoValue = (n) => sumBy(pool.filter((r) => r.e.region === n), mv)
  const areas = areaBars(sel, perD, spec.color)
  const top = [...scoped].sort((a, b) => spec.rank(b) - spec.rank(a)).slice(0, 7).map((r) => ({ name: r.e.name, value: spec.rank(r) }))
  const rows = scoped.map(spec.row)
  const sections = () => [
    { title: `${spec.name} - ${scopeName(sel)}`, columns: spec.cols, rows },
    { title: `${spec.noun} by area`, columns: ['Area', spec.noun], rows: areas.map((r) => [r.name, r.value]) },
  ]

  return (
    <PageHead title={spec.title} sub={spec.sub} name={spec.name} sel={sel} onSel={setSel} sections={sections}>
      <PhotoRow items={spec.kpis(scoped, sel)} />
      <FigTiles items={spec.figs(scoped, sel)} />
      <ProvinceStrip startOpen byD={perD} fmt={spec.fmt || num} unit={spec.unit} sel={sel} setSel={setSel} color={spec.color} {...landStrip(d, sel, setSel, perD, spec.noun, cdoValue)} />
      <Split
        map={
          <Card title={spec.mapTitle} sub={spec.mapSub} className="an-card-map">
            <DrillMap
              geo={d.geo} values={perD} fmt={spec.fmt || num} unit={spec.unit} sel={sel} onSel={setSel} scale={spec.scale} markers={markers} markerKey={`topic-${spec.name}-${cat}`}
              overlay={<CatCard title={spec.catTitle} cats={spec.cats} value={cat} onChange={setCat} rows={all.filter(here)} />}
              legend={spec.cats.map((c) => ({ icon: c.glyph, color: c.color, text: c.name }))} height={560}
            />
          </Card>
        }
        side={
          <>
            <Card title={spec.donutTitle} sub={`${scoped.length} lands in ${scopeName(sel)}`}>
              <Donut data={byCat} height={190} />
            </Card>
            <Card title={sel.province ? `${spec.noun} by district` : `${spec.noun} by province`}>
              <Bars data={areas} horizontal single height={Math.max(180, areas.length * 28)} fmt={spec.fmt || num} />
            </Card>
          </>
        }
      />
      <Card title={spec.month.title} sub={spec.month.sub}>
        <Bars data={spec.month.data(scoped)} keys={spec.month.keys} colors={spec.month.colors} stacked={spec.month.keys.length > 1} single={spec.month.keys.length === 1} height={250} fmt={spec.month.fmt || compact} />
      </Card>
      <div className="an-grid2">
        <Card title={spec.second.title} sub={spec.second.sub}>
          <Bars data={spec.second.data(scoped)} horizontal height={230} nameWidth={140} fmt={spec.second.fmt || num} colors={[spec.color]} single />
        </Card>
        {spec.third ? spec.third(scoped) : (
          <Card title={spec.topTitle} sub={spec.topSub}>
            <Bars data={top} horizontal height={230} nameWidth={140} fmt={spec.rankFmt || compact} colors={[spec.color]} single />
          </Card>
        )}
      </div>
      <Card title={`${spec.noun} list`} sub={`${scoped.length} lands, ${scopeName(sel)}`}>
        <DataTable columns={spec.cols} rows={rows} limit={10} />
      </Card>
    </PageHead>
  )
}

const WEEK = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
const monthRows = (keys, series) => MONTHS.map((m, i) => ({ name: m, ...Object.fromEntries(keys.map((k, j) => [k, series[j][i]])) }))
const top1 = (items) => [...items].sort((a, b) => b.value - a.value)[0]
const tally = (rows, cats, f = () => 1) => cats.map((c) => ({ name: c.name, value: sumBy(rows.filter((r) => r.cat === c.name), f) }))

// ----------------------------------------------------------------------------- the six pages
const SPECS = {
  tour: {
    title: 'Agri tourism', sub: 'Lands that welcome visitors, and what the visits bring in', name: 'Agri tourism', noun: 'Tourism lands', unit: 'lands',
    rows: (t) => t.tour, cats: TOUR, catTitle: 'Offering', donutTitle: 'What visitors come for', color: '#0288d1',
    mapTitle: 'Where visitors go', mapSub: 'Each pin is a land that offers a visit, coloured by what it offers.',
    tip: (r) => `${num(r.visitors)} visitors a year · rating ${r.rating}`,
    rank: (r) => r.visitors, rankFmt: num, topTitle: 'Most visited lands', topSub: 'Visitors in a year',
    kpis: (s) => [
      ['rotary', 'palm', 'green', 'Tourism lands', num(s.length), 'open to visitors'],
      ['koku_nagula', 'users', 'blue', 'Visitors', compact(sumBy(s, (r) => r.visitors)), 'in a year'],
      ['trailer', 'wallet', 'purple', 'Tourism income', rs(sumBy(s, (r) => r.money)), 'in a year'],
      ['slasher', 'trophy', 'amber', 'Average rating', s.length ? (sumBy(s, (r) => r.rating) / s.length).toFixed(1) : '-', 'out of 5, from visitors'],
    ],
    figs: (s) => {
      const t = top1(tally(s, TOUR))
      const v = sumBy(s, (r) => r.visitors)
      const f = sumBy(s, (r) => r.visitors * r.foreign)
      return [
        ['Most offered', t && t.value ? t.name : '-', t && t.value ? `on ${t.value} lands` : '', glyphRow(['tent'], ['#0288d1'], 64)],
        ['Foreign visitors', v ? pct(f, v) : '-', v ? `${compact(f)} of ${compact(v)} visitors` : '', glyphRow(['house', 'cup'], ['#0288d1', '#d99a0b'], 52)],
      ]
    },
    month: {
      title: 'Visitors each month', sub: 'Local and foreign visitors. Sample figures; busiest in December to March', keys: ['Local', 'Foreign'], colors: ['#2f8a4f', '#0288d1'], fmt: num,
      data: (s) => {
        const v = sumBy(s, (r) => r.visitors)
        const f = sumBy(s, (r) => r.visitors * r.foreign)
        return monthRows(['Local', 'Foreign'], [
          monthly(v - f, [1.3, 1.4, 1.2, 1.1, 0.65, 0.6, 0.9, 0.9, 0.6, 0.7, 1, 1.55]),
          monthly(f, [1.7, 1.8, 1.4, 1, 0.5, 0.4, 0.9, 1, 0.5, 0.7, 1.1, 2]),
        ])
      },
    },
    second: { title: 'Income by offering', sub: 'Rupees earned in a year', fmt: rs, data: (s) => tally(s, TOUR, (r) => r.money).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'Offering', 'Visitors', 'Foreign', 'Income a year', 'Rating'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, num(r.visitors), `${Math.round(r.foreign * 100)}%`, rs(r.money), r.rating],
  },

  aqua: {
    title: 'Aquaculture', sub: 'Fish and prawn ponds on registered lands', name: 'Aquaculture', noun: 'Fish farms', unit: 'farms',
    rows: (t) => t.aqua, cats: AQUA, catTitle: 'Species', donutTitle: 'What is farmed', color: '#0288d1', scale: ['#e4eff5', '#bad7e6', '#86b6cf', '#4f8fb0', '#25607f'],
    mapTitle: 'Where the ponds are', mapSub: 'Each pin is a land with a pond, coloured by the species kept.',
    tip: (r) => `${r.pond} acres of pond · ${kgText(r.kg)} a year`,
    rank: (r) => r.kg, rankFmt: kgText, topTitle: 'Biggest harvests', topSub: 'Harvest in a year',
    kpis: (s) => [
      ['rotary', 'palm', 'blue', 'Fish farms', num(s.length), 'lands with ponds'],
      ['koku_nagula', 'pin', 'green', 'Pond area', `${(Math.round(sumBy(s, (r) => r.pond) * 10) / 10).toLocaleString('en-US')} ac`, 'under water'],
      ['disc_plough', 'truck', 'amber', 'Harvest', kgText(sumBy(s, (r) => r.kg)), 'in a year'],
      ['trailer', 'wallet', 'purple', 'Income', rs(sumBy(s, (r) => r.money)), 'in a year'],
    ],
    figs: (s) => {
      const t = top1(tally(s, AQUA, (r) => r.kg))
      const ac = sumBy(s, (r) => r.pond)
      return [
        ['Biggest harvest', t && t.value ? t.name : '-', t && t.value ? kgText(t.value) : '', glyphRow(['fish'], ['#0288d1'], 62)],
        ['Harvest per acre', ac ? kgText(sumBy(s, (r) => r.kg) / ac) : '-', 'of pond, in a year', glyphRow(['fish', 'fish'], ['#d9741a', '#0288d1'], 50)],
      ]
    },
    month: {
      title: 'Harvest each month', sub: 'Kilograms by species. Sample figures', keys: AQUA.map((a) => a.name), colors: AQUA.map((a) => a.color), fmt: kgText,
      data: (s) => monthRows(AQUA.map((a) => a.name), AQUA.map((a) => monthly(sumBy(s.filter((r) => r.cat === a.name), (r) => r.kg), [0.9, 0.85, 0.9, 1, 1.1, 1.1, 1.15, 1.15, 1.1, 1, 0.95, 0.85]))),
    },
    second: { title: 'Income by species', sub: 'Rupees earned in a year', fmt: rs, data: (s) => tally(s, AQUA, (r) => r.money).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'Species', 'Pond (acres)', 'Harvest', 'Income a year'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, r.pond, kgText(r.kg), rs(r.money)],
  },

  animal: {
    title: 'Animal husbandry', sub: 'Cattle, goats, poultry and bees kept on registered lands', name: 'Animal husbandry', noun: 'Livestock farms', unit: 'farms',
    rows: (t) => t.animal, cats: ANIMAL, catTitle: 'Livestock', donutTitle: 'What is kept', color: '#8b4a1c', scale: ['#f6e8df', '#e8c5ad', '#d49a73', '#b46a3f', '#7d3f1c'],
    mapTitle: 'Where the animals are', mapSub: 'Each pin is a livestock farm, coloured by the animals kept.',
    tip: (r) => `${num(r.count)} ${r.unit}`,
    rank: (r) => r.money, rankFmt: rs, topTitle: 'Best earning farms', topSub: 'Income in a month',
    kpis: (s) => [
      ['rotary', 'palm', 'brown', 'Livestock farms', num(s.length), 'lands with animals'],
      ['koku_nagula', 'users', 'green', 'Animals kept', compact(sumBy(s, (r) => r.count)), 'including bee hives'],
      ['disc_plough', 'flask', 'blue', 'Milk', `${num(sumBy(s, (r) => r.milk))} L`, 'collected each day'],
      ['trailer', 'gift', 'amber', 'Eggs', num(sumBy(s, (r) => r.eggs)), 'collected each day'],
    ],
    figs: (s) => {
      const t = top1(tally(s, ANIMAL))
      return [
        ['Most common', t && t.value ? t.name : '-', t && t.value ? `on ${t.value} farms` : '', glyphRow(['cow'], ['#5d4037'], 62)],
        ['Farm income', rs(sumBy(s, (r) => r.money)), 'every month, all farms', glyphRow(['goat', 'hen'], ['#9c7b5b', '#c0392b'], 50)],
      ]
    },
    month: {
      title: 'Milk collected each month', sub: 'Litres from dairy cattle. Sample figures; more in the wetter months', keys: ['Milk'], colors: ['#8b4a1c'], fmt: (v) => `${compact(v)} L`,
      data: (s) => monthRows(['Milk'], [monthly(sumBy(s, (r) => r.milk) * 30 * 12, [0.95, 0.9, 0.9, 1, 1.05, 1.1, 1.1, 1.1, 1.05, 1.05, 1.1, 1.05])]),
    },
    second: { title: 'Animals by kind', sub: 'Heads, birds or hives', data: (s) => tally(s, ANIMAL, (r) => r.count).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'Kind', 'Number', 'Milk or eggs a day', 'Income a month'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, `${num(r.count)} ${r.unit}`, r.milk ? `${num(r.milk)} L` : r.eggs ? `${num(r.eggs)} eggs` : '-', rs(r.money)],
  },

  cult: {
    title: 'Cultivation type', sub: 'How each land is grown: one crop, mixed crops or organic', name: 'Cultivation type', noun: 'Lands', unit: 'lands',
    rows: (t) => t.cult, cats: CULT, catTitle: 'Cultivation type', donutTitle: 'Cultivation types', color: '#2f8a4f',
    mapTitle: 'How lands are grown', mapSub: 'Each pin is a land, shown by the way it is cultivated.',
    tip: (r) => `${r.e.crop}${r.together.length ? ' with ' + r.together.join(', ') : ''} \u00b7 ${r.e.acres} acres`,
    rank: (r) => r.money, rankFmt: rs, topTitle: 'Highest earning lands', topSub: 'Estimated income in a year',
    kpis: (s) => [
      ['rotary', 'palm', 'green', 'Lands', num(s.length), `${num(sumBy(s, (r) => r.e.acres))} acres in total`],
      ['koku_nagula', 'users', 'amber', 'Intercropped lands', num(s.filter((r) => r.cat === 'Intercropped' || r.cat === 'Mixed home garden').length), 'more than one crop'],
      ['slasher', 'check', 'brown', 'Organic lands', num(s.filter((r) => r.cat === 'Organic').length), `${num(sumBy(s.filter((r) => r.cat === 'Organic'), (r) => r.e.acres))} acres`],
      ['trailer', 'wallet', 'purple', 'Income per acre', rs(sumBy(s, (r) => r.e.acres) ? sumBy(s, (r) => r.money) / sumBy(s, (r) => r.e.acres) : 0), 'estimated, in a year'],
    ],
    figs: (s) => {
      const mix = {}
      s.forEach((r) => r.together.forEach((x) => (mix[x] = (mix[x] || 0) + 1)))
      const best = Object.entries(mix).sort((a, b) => b[1] - a[1])[0]
      const t = top1(tally(s, CULT))
      return [
        ['Most common type', t && t.value ? t.name : '-', t && t.value ? `${pct(t.value, s.length)} of the lands` : '', glyphRow(['sprout'], ['#2f8a4f'], 64)],
        ['Grown together most', best ? best[0] : '-', best ? `on ${best[1]} lands` : '', glyphRow(['sprouts', 'basket'], ['#2f8a4f', '#b5803c'], 54)],
      ]
    },
    month: {
      title: 'Cultivation type by crop', sub: 'How many lands of each crop are grown each way', keys: ['Coconut', 'Pepper', 'Pineapple'], colors: ['#2f8a4f', '#9c2a23', '#d99a0b'], fmt: num,
      data: (s) => CULT.map((c) => ({ name: c.name, Coconut: s.filter((r) => r.cat === c.name && r.e.crop === 'Coconut').length, Pepper: s.filter((r) => r.cat === c.name && r.e.crop === 'Pepper').length, Pineapple: s.filter((r) => r.cat === c.name && r.e.crop === 'Pineapple').length })),
    },
    second: {
      title: 'Crops grown together', sub: 'Second crops on intercropped and mixed lands',
      data: (s) => {
        const mix = {}
        s.forEach((r) => r.together.forEach((x) => (mix[x] = (mix[x] || 0) + 1)))
        return Object.entries(mix).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value)
      },
    },
    cols: ['ID', 'Land', 'Owner', 'District', 'Crop', 'Type', 'Grown with', 'Acres', 'Income a year'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.e.crop, r.cat, r.together.join(', ') || '-', r.e.acres, rs(r.money)],
  },

  energy: {
    title: 'Green energy', sub: 'Solar, biogas and coconut-shell power on registered lands', name: 'Green energy', noun: 'Lands with green energy', unit: 'lands',
    rows: (t) => t.energy, cats: ENERGY, catTitle: 'System', donutTitle: 'Kinds of system', color: '#d99a0b', scale: ['#fbf0d9', '#f3d9a0', '#e8bb5e', '#cf9526', '#8f610d'],
    mapTitle: 'Where the power is made', mapSub: 'Each pin is a land with its own power, shown by the system.',
    tip: (r) => `${r.kw} kW \u00b7 ${num(r.kwh)} kWh a year`,
    rank: (r) => r.kwh, rankFmt: (v) => `${compact(v)} kWh`, topTitle: 'Biggest producers', topSub: 'Power made in a year',
    kpis: (s) => [
      ['rotary', 'palm', 'amber', 'Lands with green energy', num(s.length), 'own their power'],
      ['disc_plough', 'trend', 'green', 'Capacity', `${num(sumBy(s, (r) => r.kw))} kW`, 'installed'],
      ['trailer', 'clock', 'blue', 'Power made', `${compact(sumBy(s, (r) => r.kwh))} kWh`, 'in a year'],
      ['koku_nagula', 'check', 'purple', 'Carbon avoided', t1(sumBy(s, (r) => r.co2)), 'a year, against grid power'],
    ],
    figs: (s) => {
      const t = top1(tally(s, ENERGY))
      return [
        ['Most used', t && t.value ? t.name : '-', t && t.value ? `on ${t.value} lands` : '', glyphRow(['solar'], ['#1565c0'], 62)],
        ['Saved on power bills', rs(sumBy(s, (r) => r.money)), 'in a year', glyphRow(['solar', 'flame'], ['#1565c0', '#ef6c00'], 50)],
      ]
    },
    month: {
      title: 'Power made each month', sub: 'Kilowatt hours by system. Sample figures; solar is strongest in the dry months', keys: ENERGY.map((x) => x.name), colors: ENERGY.map((x) => x.color), fmt: (v) => `${compact(v)} kWh`,
      data: (s) => monthRows(ENERGY.map((x) => x.name), ENERGY.map((x) => monthly(sumBy(s.filter((r) => r.cat === x.name), (r) => r.kwh), x.name.startsWith('Solar') ? [1.1, 1.15, 1.2, 1.05, 0.85, 0.8, 0.85, 0.9, 0.9, 0.85, 0.85, 1] : WEEK))),
    },
    second: { title: 'Capacity by system', sub: 'Kilowatts installed', fmt: (v) => `${num(v)} kW`, data: (s) => tally(s, ENERGY, (r) => r.kw).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'System', 'Capacity (kW)', 'Power a year', 'Carbon avoided', 'Saved a year'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, r.kw, `${num(r.kwh)} kWh`, t1(r.co2), rs(r.money)],
  },

  env: {
    title: 'Environment', sub: 'Carbon emitted by the lands, carbon stored by their trees, and the balance', name: 'Environment', noun: 'Emissions', unit: 'CO2',
    rows: (t) => t.env, cats: ENV, catTitle: 'Carbon balance', donutTitle: 'Carbon balance of lands', color: '#c0392b', scale: ['#f6e8df', '#e8c5ad', '#d49a73', '#b46a3f', '#7d3f1c'],
    mapTitle: 'Carbon emissions', mapSub: 'The shading is the carbon emitted in each area. A green cloud stores more than it emits, a red cloud emits more.',
    mapVal: (r) => r.emit, fmt: (v) => `${num(v)} t`,
    tip: (r) => `Emits ${t1(r.emit)} \u00b7 stores ${t1(r.seq)} \u00b7 balance ${r.balance >= 0 ? '+' : '-'}${t1(Math.abs(r.balance))}`,
    rank: (r) => r.emit, rankFmt: (v) => t1(v), topTitle: 'Biggest emitters', topSub: 'Carbon emitted in a year',
    kpis: (s) => [
      ['rotary', 'trend', 'brown', 'Carbon emitted', t1(sumBy(s, (r) => r.emit)), 'fuel, fertilizer, animals and waste'],
      ['koku_nagula', 'palm', 'green', 'Carbon stored', t1(sumBy(s, (r) => r.seq)), 'by palms and crops'],
      ['disc_plough', 'scale', 'blue', 'Net balance', `${sumBy(s, (r) => r.balance) >= 0 ? '+' : '-'}${t1(Math.abs(sumBy(s, (r) => r.balance)))}`, sumBy(s, (r) => r.balance) >= 0 ? 'stored more than emitted' : 'emitted more than stored'],
      ['trailer', 'check', 'purple', 'Avoided by green energy', t1(sumBy(s, (r) => r.avoided)), 'less grid power used'],
    ],
    figs: (s) => {
      const ac = sumBy(s, (r) => r.e.acres)
      return [
        ['Emitted per acre', ac ? `${(sumBy(s, (r) => r.emit) / ac).toFixed(2)} t` : '-', 'of carbon, in a year', glyphRow(['cloud'], ['#c0392b'], 64)],
        ['Lands storing more', s.length ? pct(s.filter((r) => r.balance >= 0).length, s.length) : '-', `${num(s.filter((r) => r.balance >= 0).length)} of ${num(s.length)} lands`, glyphRow(['cloud', 'leaf'], ['#2f8a4f', '#43a047'], 52)],
      ]
    },
    month: {
      title: 'Carbon emitted each month', sub: 'Tonnes by source. Sample figures; fertilizer peaks before the rains, fuel at harvest', keys: ['Fuel and machines', 'Fertilizer', 'Animals', 'Waste and other'], colors: ['#8b4a1c', '#d99a0b', '#c0392b', '#7a8f84'], fmt: (v) => t1(v),
      data: (s) => monthRows(['Fuel and machines', 'Fertilizer', 'Animals', 'Waste and other'], [
        monthly(sumBy(s, (r) => r.fuel), [1, 1, 1.1, 1.1, 0.9, 0.9, 0.9, 1, 1.1, 1.1, 1, 0.9]),
        monthly(sumBy(s, (r) => r.fert), [0.5, 0.4, 0.4, 1.6, 1.6, 0.6, 0.4, 0.4, 1.5, 1.6, 0.6, 0.4]),
        monthly(sumBy(s, (r) => r.live), WEEK),
        monthly(sumBy(s, (r) => r.waste), [1.3, 1.2, 0.9, 0.8, 0.8, 0.8, 0.8, 0.9, 0.9, 1, 1.1, 1.3]),
      ]),
    },
    second: { title: 'Carbon stored by crop', sub: 'Tonnes held by the trees and plants, in a year', fmt: (v) => t1(v), data: (s) => ['Coconut', 'Pepper', 'Pineapple'].map((c) => ({ name: c, value: sumBy(s.filter((r) => r.e.crop === c), (r) => r.seq) })) },
    third: (s) => (
      <Card title="Where the emissions come from" sub="Share of the carbon emitted">
        <Donut fmt={(v) => t1(v)} height={190} data={[['Fuel and machines', '#8b4a1c', sumBy(s, (r) => r.fuel)], ['Fertilizer', '#d99a0b', sumBy(s, (r) => r.fert)], ['Animals', '#c0392b', sumBy(s, (r) => r.live)], ['Waste and other', '#7a8f84', sumBy(s, (r) => r.waste)]].map(([name, color, value]) => ({ name, color, value }))} />
      </Card>
    ),
    cols: ['ID', 'Land', 'Owner', 'District', 'Crop', 'Emitted', 'Stored', 'Avoided', 'Balance'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.e.crop, t1(r.emit), t1(r.seq), t1(r.avoided), `${r.balance >= 0 ? '+' : '-'}${t1(Math.abs(r.balance))}`],
  },
}

export const LAND_TOPICS = {
  'soon-cultivation-type': 'cult',
  'soon-agri-tourism': 'tour',
  'soon-aquaculture': 'aqua',
  'soon-animal-husbandry': 'animal',
  'soon-green-energy': 'energy',
  'soon-environment': 'env',
}

export default function LandTopic({ view, d, sel, setSel }) {
  return <TopicPage key={view} d={d} sel={sel} setSel={setSel} spec={SPECS[LAND_TOPICS[view]]} />
}

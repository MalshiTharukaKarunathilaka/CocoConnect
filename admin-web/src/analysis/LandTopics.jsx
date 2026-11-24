import { useMemo, useState } from 'react'
import { Area, AreaChart, CartesianGrid, Legend, Line, LineChart, ReferenceLine, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import DrillMap from './DrillMap'
import { glyphHtml } from './pins'
import { Bars, Donations, LandId, LandStats, estatePhoto, Donut, FigTiles, Overview, PhotoRow, ProvinceStrip, Split, areaBars, glyphRow, landStrip } from './AnalysisPages'
import { MONTHS, USD_LKR, compact, inScope, kgText, label, num, pct, rs, scopeName, sumBy } from './data'
import PlatformPage from './PlatformPages'
import { vegetationOf } from './Vegetation'
import { Card, Chips, DataTable, PageHead, Segmented } from './ui'

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
const t1 = (n) => `${(Math.round(n * 10) / 10).toLocaleString('en-US')} MT`

const TOUR = [
  { name: 'Plantation tour', color: '#2f8a4f', glyph: 'planttour', price: 2500 },
  { name: 'Farm stay', color: '#0288d1', glyph: 'farmstay', price: 6500 },
  { name: 'Farm tour', color: '#d99a0b', glyph: 'farmtour', price: 3200 },
  { name: 'Farm food', color: '#8b4a1c', glyph: 'farmfood', price: 2800 },
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
  { name: 'Solar panels', color: '#1565c0', glyph: 'energysolar', lo: 2, hi: 25, perKw: 1400 },
  { name: 'Solar water pump', color: '#0288d1', glyph: 'energywater', lo: 1, hi: 5, perKw: 1300 },
  { name: 'Biogas unit', color: '#ef6c00', glyph: 'energybiogas', lo: 1, hi: 6, perKw: 1800 },
  { name: 'Coconut-shell biomass', color: '#8b4a1c', glyph: 'energyshell', lo: 5, hi: 30, perKw: 1100 },
]
// What makes carbon creditable: new, extra action (not business as usual). `share` is the part of a land's absorbed carbon it adds.
const PRACTICES = [
  { key: 'planting', label: 'New planting', share: 0.3 },
  { key: 'intercrop', label: 'Intercrop (Gliricidia, Mana grass)', share: 0.2 },
  { key: 'biochar', label: 'Biochar from husks and shells', share: 0.25 },
]
const CREDIT_STATUS = {
  ready: { text: 'Credit-ready', color: '#d99a0b', note: 'Extra climate action, verified, rights held' },
  pending: { text: 'Practices in place, not verified', color: '#8a96a0', note: 'Extra climate action, but verification, rights or a group project is missing' },
  none: { text: 'Not eligible yet', color: '#c9d1cc', note: 'No new planting, intercrop or biochar: business-as-usual farming does not earn credits' },
}
const ENV = [
  { name: 'Stores carbon', color: '#2f8a4f', glyph: 'envpalm' },
  { name: 'Emits more', color: '#c0392b', glyph: 'envpalm' },
]
const GRID_KG = 0.45 // kg of CO2 saved for each kWh that does not come from the grid
const BILL = 38 // rupees per kWh

const LOAN = [
  { name: 'Replanting', color: '#2f8a4f', glyph: 'seedlings', mult: 1 },
  { name: 'Machinery', color: '#8e44ad', glyph: 'tractor', mult: 1.8 },
  { name: 'Irrigation', color: '#0288d1', glyph: 'irrigation', mult: 1.2 },
  { name: 'Working capital', color: '#d99a0b', glyph: 'moneybag', mult: 0.7 },
  { name: 'Processing', color: '#8b4a1c', glyph: 'energyshell', mult: 1.5 },
]
const LENDERS = ['Bank of Ceylon', "People's Bank", 'Sampath Bank', 'National Development Bank', 'Regional Development Bank']
const LOAN_STATUS = [['Active', 0.62], ['Repaid', 0.25], ['Overdue', 0.13]]
const COVER = [
  { name: 'Crop and drought', color: '#2f8a4f', glyph: 'sprout', per: 110000, rate: 0.045 },
  { name: 'Fire and property', color: '#d9741a', glyph: 'flame', per: 70000, rate: 0.012 },
  { name: 'Machinery', color: '#8e44ad', glyph: 'tractor', per: 90000, rate: 0.03 },
  { name: 'Livestock', color: '#5d4037', glyph: 'cow', per: 50000, rate: 0.04 },
]
const INSURERS = ['Sri Lanka Insurance', 'Ceylinco Insurance', 'Janashakthi Insurance', 'AIA Insurance']
const CREDIT = [
  { name: 'Registered', color: '#43a047', glyph: 'leaf' },
  { name: 'Verified', color: '#0288d1', glyph: 'shield' },
  { name: 'Sold', color: '#d99a0b', glyph: 'coin' },
]
const STANDARDS = ['Verra VCS', 'Gold Standard', 'Sri Lanka Carbon Registry']
const USD = 300 // rupees to the dollar
const share = (items, r) => {
  let a = 0
  for (const [name, w] of items) { a += w; if (r < a) return name }
  return items[items.length - 1][0]
}

const SUBS = [
  { name: 'Fertilizer', color: '#2f8a4f', glyph: 'sack', p: 0.5, schemes: ['Free issue', 'Reduced price', 'Cash grant'], amt: (a, r) => a * (4000 + r * 5000) },
  { name: 'Machinery', color: '#8e44ad', glyph: 'tractor', p: 0.15, schemes: ['Tractor subsidy', 'Hand tractor grant', 'Hire voucher'], amt: (a, r) => 40000 + r * 110000 },
  { name: 'Instruments', color: '#8b4a1c', glyph: 'wrench', p: 0.3, schemes: ['Harvesting tools', 'Climbing gear', 'Hand tools'], amt: (a, r) => 8000 + r * 17000 },
  { name: 'Irrigation Equipment', color: '#0288d1', glyph: 'irrigation', p: 0.2, schemes: ['Drip kit', 'Sprinklers', 'Pump grant'], amt: (a, r) => a * (6000 + r * 6000) },
  { name: 'Guns', color: '#d9741a', glyph: 'spraygun', p: 0.25, schemes: ['Sprayer gun', 'Knapsack sprayer', 'Fogger'], amt: (a, r) => 12000 + r * 33000 },
  { name: 'Planting Materials', color: '#43a047', glyph: 'seedlings', p: 0.35, schemes: ['Seedlings', 'Tissue-culture plants', 'Hybrid seed nuts'], amt: (a, r) => a * (5000 + r * 9000) },
  { name: 'Chemicals', color: '#c0392b', glyph: 'flask', p: 0.4, schemes: ['Pesticide', 'Fungicide', 'Weedicide'], amt: (a, r) => a * (2500 + r * 2500) },
]

// The farm-input pages under Resources: what lands bought, from whom, and how much it cost.
const RES = {
  instruments: { p: 0.3, unit: 'items', suppliers: ['Ceylon Tools', 'Coco Gear Lanka', 'Agro Hardware', 'Kandy Farm Supplies'], cats: [
    { name: 'Harvesting pole', color: '#8b4a1c', glyph: 'harvestpole', price: 3800, lo: 1, hi: 8, unit: 'poles' },
    { name: 'Climbing gear', color: '#d9741a', glyph: 'climbgear', price: 9500, lo: 1, hi: 5, unit: 'sets' },
    { name: 'Machete', color: '#607d8b', glyph: 'machete', price: 1800, lo: 2, hi: 12, unit: 'machetes' },
    { name: 'Husking spike', color: '#8e44ad', glyph: 'wrench', price: 2600, lo: 1, hi: 6, unit: 'spikes' },
  ] },
  irrigation: { p: 0.2, unit: 'sets', suppliers: ['AquaFarm Lanka', 'Rainbird Agro', 'Water Wise Ceylon', 'Southern Irrigation'], cats: [
    { name: 'Drip kit', color: '#0288d1', glyph: 'irrigation', price: 24000, lo: 1, hi: 10, unit: 'kits' },
    { name: 'Sprinkler', color: '#26a69a', glyph: 'drop', price: 6500, lo: 2, hi: 20, unit: 'sprinklers' },
    { name: 'Water pump', color: '#d9741a', glyph: 'drop', price: 68000, lo: 1, hi: 3, unit: 'pumps' },
    { name: 'Pipes and fittings', color: '#5d4037', glyph: 'drop', price: 1200, lo: 20, hi: 200, unit: 'lengths' },
  ] },
  guns: { p: 0.25, unit: 'sprayers', suppliers: ['SprayTech Lanka', 'Agro Machines', 'Green Shield', 'Farm Power Ceylon'], cats: [
    { name: 'Knapsack sprayer', color: '#d9741a', glyph: 'spraygun', price: 14500, lo: 1, hi: 6, unit: 'sprayers' },
    { name: 'Power sprayer', color: '#c0392b', glyph: 'spraygun', price: 46000, lo: 1, hi: 3, unit: 'sprayers' },
    { name: 'Fogger', color: '#8e44ad', glyph: 'spraygun', price: 62000, lo: 1, hi: 2, unit: 'foggers' },
    { name: 'Hand sprayer', color: '#0288d1', glyph: 'spraygun', price: 3200, lo: 2, hi: 10, unit: 'sprayers' },
  ] },
  planting: { p: 0.35, unit: 'plants', suppliers: ['Coconut Research Nursery', 'Green Plant Lanka', 'Ceylon Seed Co.', 'Spice Nursery Matale'], cats: [
    { name: 'Coconut seedlings', color: '#43a047', glyph: 'seedlings', price: 180, lo: 40, hi: 600, unit: 'seedlings' },
    { name: 'Hybrid seed nuts', color: '#8b4a1c', glyph: 'shell', price: 95, lo: 100, hi: 1500, unit: 'nuts' },
    { name: 'Tissue-culture plants', color: '#2f8a4f', glyph: 'sprouts', price: 420, lo: 20, hi: 300, unit: 'plants' },
    { name: 'Pepper plants', color: '#9c2a23', glyph: 'pepperplant', price: 150, lo: 50, hi: 800, unit: 'plants' },
  ] },
  chemicals: { p: 0.4, unit: 'litres', suppliers: ['CIC Agribusiness', 'Hayleys Agriculture', 'Baurs Lanka', 'Agro Chem Ceylon'], cats: [
    { name: 'Pesticide', color: '#c0392b', glyph: 'flask', price: 1600, lo: 5, hi: 60, unit: 'litres' },
    { name: 'Fungicide', color: '#8e44ad', glyph: 'flask', price: 1400, lo: 5, hi: 50, unit: 'kg' },
    { name: 'Weedicide', color: '#0288d1', glyph: 'flask', price: 1300, lo: 10, hi: 120, unit: 'litres' },
    { name: 'Soil lime', color: '#9e9e9e', glyph: 'flask', price: 60, lo: 100, hi: 2000, unit: 'kg' },
  ] },
}

const cache = new WeakMap()
function topicRows(d) {
  if (cache.has(d)) return cache.get(d)
  const out = { cult: [], tour: [], aqua: [], animal: [], energy: [], env: [], loans: [], insure: [], carbon: [], instruments: [], irrigation: [], guns: [], planting: [], chemicals: [] }
  for (const e of d.estates) {
    // farm inputs: each land buys some of each kind, from one supplier
    for (const [key, cfg] of Object.entries(RES)) {
      if (hr(e.id, key) >= cfg.p) continue
      const c = pickOf(cfg.cats, hr(e.id, key + '1'))
      const qty = Math.round(c.lo + hr(e.id, key + '2') * (c.hi - c.lo))
      out[key].push({ e, cat: c.name, qty, unit: c.unit, supplier: pickOf(cfg.suppliers, hr(e.id, key + '3')), money: Math.round((qty * c.price * (0.9 + hr(e.id, key + '4') * 0.2)) / 10) * 10 })
    }
  }
  for (const e of d.estates) {
    const a = e.acres
    // loans: about two lands in five
    if (hr(e.id, 'loan') < 0.42) {
      const p = pickOf(LOAN, hr(e.id, 'l1'))
      const amount = Math.round((a * (45000 + hr(e.id, 'l2') * 110000) * p.mult) / 1000) * 1000
      const status = share(LOAN_STATUS, hr(e.id, 'l3'))
      out.loans.push({ e, cat: p.name, lender: pickOf(LENDERS, hr(e.id, 'l4')), amount, rate: Math.round((8 + hr(e.id, 'l5') * 6) * 10) / 10, term: pickOf([12, 24, 36, 60], hr(e.id, 'l6')), status, owing: status === 'Repaid' ? 0 : Math.round(amount * (0.3 + hr(e.id, 'l7') * 0.6)), money: amount })
    }
    // insurance: about one land in three
    if (hr(e.id, 'ins') < 0.34) {
      const c = pickOf(COVER, hr(e.id, 'i1'))
      const sum = Math.round((a * c.per * (0.7 + hr(e.id, 'i2') * 0.6)) / 1000) * 1000
      const claims = Math.floor(hr(e.id, 'i3') * 3.4)
      out.insure.push({ e, cat: c.name, insurer: pickOf(INSURERS, hr(e.id, 'i4')), sum, premium: Math.round(sum * c.rate), claims, paid: Math.round(claims * sum * (0.04 + hr(e.id, 'i5') * 0.08)), status: hr(e.id, 'i6') < 0.82 ? 'Active' : 'Lapsed', money: Math.round(sum * c.rate) })
    }
    // carbon credits: about one land in four
    if (hr(e.id, 'cc') < 0.27) {
      const credits = Math.max(1, Math.round(a * (0.8 + hr(e.id, 'c1') * 1.4) * (e.crop === 'Coconut' ? 1.2 : 0.8)))
      const status = share([['Registered', 0.3], ['Verified', 0.35], ['Sold', 0.35]], hr(e.id, 'c2'))
      const price = Math.round((8 + hr(e.id, 'c3') * 10) * USD)
      out.carbon.push({ e, cat: status, credits, standard: pickOf(STANDARDS, hr(e.id, 'c4')), price, sold: status === 'Sold' ? credits : 0, money: credits * price })
    }
  }
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
  const manaIds = new Set(vegetationOf(d).mana.map((p) => p.id))
  for (const e of d.estates) {
    const a = e.acres
    const fuel = a * (0.14 + hr(e.id, 'v1') * 0.16)
    const fert = a * (0.2 + hr(e.id, 'v2') * 0.3)
    const live = animals[e.id]?.co2 || 0
    const waste = a * 0.05 * (0.5 + hr(e.id, 'v3'))
    const emit = fuel + fert + live + waste
    // a coconut palm absorbs about 37 to 56 kg of CO2 a year
    const seq = e.crop === 'Coconut' ? e.palms * (0.037 + hr(e.id, 'v4') * 0.019) : a * (e.crop === 'Pepper' ? 0.5 + hr(e.id, 'v4') * 0.8 : 0.3 + hr(e.id, 'v4') * 0.5)
    const avoided = energy[e.id]?.co2 || 0
    const balance = seq + avoided - emit
    // Credits need extra climate action beyond normal farming, then verification and clear rights.
    const practices = {
      planting: e.crop === 'Coconut' && hr(e.id, 'p1') < 0.28,
      intercrop: manaIds.has(e.id) || hr(e.id, 'p2') < 0.14,
      biochar: energy[e.id]?.cat === 'Coconut-shell biomass' || hr(e.id, 'p3') < 0.1,
    }
    const share = PRACTICES.reduce((t, x) => t + (practices[x.key] ? x.share : 0), 0)
    const verified = hr(e.id, 'p4') < 0.4
    const rights = hr(e.id, 'p5') < 0.85
    const group = hr(e.id, 'p6') < 0.5
    const cstatus = share === 0 ? 'none' : verified && rights && (a >= 25 || group) ? 'ready' : 'pending'
    out.env.push({
      e, cat: balance >= 0 ? ENV[0].name : ENV[1].name, fuel, fert, live, waste, emit, seq, avoided, balance, money: emit,
      kgPerPalm: e.crop === 'Coconut' && e.palms ? (seq * 1000) / e.palms : null,
      practices, share, creditable: seq * share, verified, rights, group, cstatus,
    })
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

/**
 * Carbon figures for one year, shown in the map's timeline panel (Environment page).
 * Sample model: palms store more as they mature, emissions ease as green energy spreads,
 * and the "if cleared" line shows what is lost when a coconut land is cut down after 2023.
 */
const ENV_FIRST = 2001, ENV_NOW = 2023
function envModel(rows, year) {
  const seq0 = sumBy(rows, (r) => r.seq)
  const emit0 = sumBy(rows, (r) => r.emit)
  const avoided = sumBy(rows, (r) => r.avoided)
  const acres = sumBy(rows, (r) => r.e.acres)
  const past = Math.min(year, ENV_NOW)
  const ahead = Math.max(0, year - ENV_NOW)
  const mature = 0.5 + 0.5 * (past - ENV_FIRST) / (ENV_NOW - ENV_FIRST)
  const stored = seq0 * mature * (1 + 0.05 * ahead)
  const emitted = emit0 * (0.8 + 0.2 * (past - ENV_FIRST) / (ENV_NOW - ENV_FIRST)) * (1 - 0.03 * ahead)
  const palms = Math.round(acres * 70 * mature * (1 + 0.05 * ahead))
  return { seq0, ahead, stored, emitted, palms, net: stored + avoided - emitted }
}

/** Line chart of the same model, 2001 to 2030. Dashed after 2023, a marker at the year picked on the map. */
function EnvTrend({ rows, year }) {
  const data = []
  for (let y = ENV_FIRST; y <= 2030; y++) {
    const m = envModel(rows, y)
    const o = { year: y }
    ;[['stored', m.stored], ['emitted', m.emitted], ['net', m.net]].forEach(([k, v]) => {
      const val = Math.round(v * 10) / 10
      if (y <= ENV_NOW) o[k] = val
      if (y >= ENV_NOW) o[`${k}F`] = val
    })
    data.push(o)
  }
  const C = { stored: '#2e7d32', emitted: '#c0392b', net: '#1565c0' }
  const names = { stored: 'Carbon stored', emitted: 'Carbon emitted', net: 'Net balance' }
  return (
    <ResponsiveContainer width="100%" height={330}>
      <LineChart data={data} margin={{ top: 30, right: 36, left: 4, bottom: 4 }}>
        <CartesianGrid stroke="#e6ece8" vertical={false} />
        <XAxis dataKey="year" tick={{ fontSize: 11 }} tickLine={false} ticks={[2001, 2005, 2010, 2015, 2020, 2025, 2030]} />
        <YAxis tick={{ fontSize: 11 }} tickLine={false} axisLine={false} tickFormatter={(v) => num(v)} width={56} />
        <Tooltip formatter={(v, n) => [t1(v), String(n).replace(' (projection)', '')]} labelFormatter={(y) => (y > ENV_NOW ? `${y} (projection)` : y)} />
        <Legend content={() => (
          <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: '6px 22px', fontSize: 12, paddingTop: 8 }}>
            {Object.keys(C).map((k) => <span key={k} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: '#3f5148' }}><i style={{ width: 18, height: 3, borderRadius: 2, background: C[k] }} />{names[k]}</span>)}
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6, color: '#6b7a70' }}><i style={{ width: 18, borderTop: '3px dashed #6b7a70' }} />Dashed = projection after 2023</span>
          </div>
        )} />
        <ReferenceLine x={ENV_NOW} stroke="#9aa8a0" strokeDasharray="2 4" label={{ value: 'data ends', fontSize: 10, fill: '#6b7a70', position: 'insideBottomLeft' }} />
        <ReferenceLine x={year} stroke="#1e2a22" strokeWidth={2} label={{ value: year, fontSize: 11, fontWeight: 700, fill: '#1e2a22', position: 'top' }} />
        {Object.keys(C).map((k) => <Line key={k} name={names[k]} type="monotone" dataKey={k} stroke={C[k]} strokeWidth={2.5} dot={false} isAnimationActive={false} />)}
        {Object.keys(C).map((k) => <Line key={`${k}F`} name={`${names[k]} (projection)`} type="monotone" dataKey={`${k}F`} stroke={C[k]} strokeWidth={2.5} strokeDasharray="6 5" dot={false} isAnimationActive={false} />)}
      </LineChart>
    </ResponsiveContainer>
  )
}

/**
 * "Adopt a land": pick one land and see what it stores, what its carbon could earn and what keeping it is worth.
 * Sample model: the land stores its yearly carbon now, 5% more each year as palms mature (for 20 years),
 * every tonne can be sold as a credit, and clearing it would release ten years of stored carbon at once.
 */
function AdoptLand({ rows }) {
  const [id, setId] = useState('')
  const [usd, setUsd] = useState(12)
  const [yrs, setYrs] = useState(20)
  const list = useMemo(() => [...rows].sort((a, b) => a.e.name.localeCompare(b.e.name)), [rows])
  const r = list.find((x) => x.e.id === id) || [...list].sort((a, b) => b.seq - a.seq)[0]
  if (!r) return <p style={{ color: '#6b7a70', fontSize: '0.8rem' }}>No lands in view.</p>
  const price = usd * USD_LKR
  const data = []
  let cum = 0
  for (let t = 1; t <= yrs; t++) {
    const growth = 1 + 0.05 * Math.min(t - 1, 20)
    const tonnes = r.seq * growth
    const income = r.creditable * growth * price
    cum += income
    data.push({ year: 2023 + t, tonnes: Math.round(tonnes * 10) / 10, income: Math.round(income), total: Math.round(cum) })
  }
  const nowIncome = r.creditable * price
  const released = r.seq * 10
  const st = CREDIT_STATUS[r.cstatus]
  return (
    <div className="an-adopt">
      <div className="an-adopt-top">
        <div className="an-adopt-photo" style={{ backgroundImage: `url(${estatePhoto(r.e)})` }}>
          <span className={`an-plan ${r.e.plan.split(' ')[0].toLowerCase()}`}>{r.e.plan}</span>
          <div className="an-adopt-cap">
            <b>{r.e.name}</b>
            <span>{r.e.owner}</span>
            <span>{label(r.e.district)}{r.e.region ? ` · ${r.e.region}` : ''}</span>
          </div>
        </div>
        <div className="an-adopt-main">
          <div className="an-adopt-ctl">
            <label><span>Land</span>
              <select value={r.e.id} onChange={(e) => setId(e.target.value)}>
                {list.map((x) => <option key={x.e.id} value={x.e.id}>{x.e.name} · {label(x.e.district)}</option>)}
              </select>
            </label>
            <label><span>Credit price: <b>${usd}</b> a tonne ({rs(price)})</span>
              <input type="range" min={5} max={40} step={1} value={usd} onChange={(e) => setUsd(Number(e.target.value))} />
            </label>
            <label><span>Keep it for</span>
              <Segmented value={yrs} onChange={setYrs} options={[[10, '10 years'], [20, '20 years'], [30, '30 years']]} />
            </label>
          </div>
          <div className="an-adopt-facts">
            <span><b>{num(r.e.acres)}</b> acres</span>
            <span><b>{num(r.e.palms || Math.round(r.e.acres * 70))}</b> palms</span>
            <span><b>{r.cat}</b></span>
            {r.kgPerPalm != null && <span><b>{Math.round(r.kgPerPalm)} kg</b> CO₂ per palm a year</span>}
            <span>Registered <b>{r.e.registeredOn}</b></span>
          </div>
          <div className="an-elig" style={{ '--c': st.color }}>
            <div className="an-elig-head"><i />{st.text}<small>{st.note}</small></div>
            <div className="an-elig-chips">
              {PRACTICES.map((x) => <span key={x.key} className={r.practices[x.key] ? 'on' : ''}>{r.practices[x.key] ? '✓' : '✗'} {x.label}</span>)}
              <span className={r.verified ? 'on' : ''}>{r.verified ? '✓' : '✗'} Verified</span>
              <span className={r.rights ? 'on' : ''}>{r.rights ? '✓' : '✗'} Land and carbon rights</span>
              <span className={r.group || r.e.acres >= 25 ? 'on' : ''}>{r.group || r.e.acres >= 25 ? '✓' : '✗'} {r.e.acres >= 25 ? 'Large enough alone' : 'In a group project'}</span>
            </div>
          </div>
          <div className="an-adopt-tiles">
            <div><span>Carbon absorbed a year</span><b style={{ color: '#2e7d32' }}>{t1(r.seq)}</b></div>
            <div><span>Credit-eligible a year</span><b style={{ color: '#9a6b00' }}>{t1(r.creditable)}</b><small>{Math.round(r.share * 100)}% of absorbed</small></div>
            <div><span>{r.cstatus === 'pending' ? 'Income once verified' : 'Credit income a year'}</span><b>{rs(nowIncome)}</b></div>
            <div className="hero"><span>Worth over {yrs} years</span><b>{rs(cum)}</b></div>
            <div className="bad"><span>Released if cleared</span><b>{t1(released)}</b></div>
          </div>
        </div>
      </div>
      <div className="an-grid2">
        <div>
          <h4 className="an-adopt-h">Carbon stored each year</h4>
          <ResponsiveContainer width="100%" height={210}>
            <AreaChart data={data} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
              <CartesianGrid stroke="#e6ece8" vertical={false} />
              <XAxis dataKey="year" tick={{ fontSize: 11 }} tickLine={false} interval={Math.ceil(yrs / 6) - 1} />
              <YAxis tick={{ fontSize: 11 }} tickLine={false} axisLine={false} width={44} />
              <Tooltip formatter={(v) => [t1(v), 'Stored']} />
              <Area type="monotone" dataKey="tonnes" stroke="#2e7d32" strokeWidth={2.5} fill="#bfe3c6" isAnimationActive={false} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
        <div>
          <h4 className="an-adopt-h">Credit income each year, and the total so far</h4>
          <ResponsiveContainer width="100%" height={210}>
            <LineChart data={data} margin={{ top: 8, right: 12, left: 0, bottom: 0 }}>
              <CartesianGrid stroke="#e6ece8" vertical={false} />
              <XAxis dataKey="year" tick={{ fontSize: 11 }} tickLine={false} interval={Math.ceil(yrs / 6) - 1} />
              <YAxis tick={{ fontSize: 11 }} tickLine={false} axisLine={false} width={56} tickFormatter={(v) => compact(v)} />
              <Tooltip formatter={(v, n) => [rs(v), n]} />
              <Line name="Income that year" type="monotone" dataKey="income" stroke="#d99a0b" strokeWidth={2.5} dot={false} isAnimationActive={false} />
              <Line name="Total so far" type="monotone" dataKey="total" stroke="#1565c0" strokeWidth={2.5} dot={false} isAnimationActive={false} />
              <Legend />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>
      <p className="an-adopt-note">Sample figures. The land absorbs {t1(r.seq)} a year now and 5% more each year as its palms mature. Only the extra carbon from new planting, intercrops and biochar ({Math.round(r.share * 100)}% here) can become credits, and only after third-party verification. Each credit is one tonne of CO₂ sold at ${usd}. Cut the land down and it stops earning, and about {t1(released)} of stored carbon is released.</p>
    </div>
  )
}

function EnvTimeline({ rows, year, projected }) {
  const { seq0, ahead, stored, emitted, palms, net } = envModel(rows, year)
  // if every land in view were cleared in 2024: nothing is stored any more and ten years of stored carbon is released once
  const clearedNet = ahead ? -emitted - seq0 * 10 : null
  const sign = (v) => `${v >= 0 ? '+' : '-'}${t1(Math.abs(v))}`
  return (
    <div className="an-env-tl">
      <div><span>Palms standing</span><b>{num(palms)}</b></div>
      <div><span>Stored a year</span><b style={{ color: '#2e7d32' }}>{t1(stored)}</b></div>
      <div><span>Emitted a year</span><b style={{ color: '#c0392b' }}>{t1(emitted)}</b></div>
      <div><span>Net balance</span><b style={{ color: net >= 0 ? '#2e7d32' : '#c0392b' }}>{sign(net)}</b></div>
      {projected && (
        <div className="bad"><span>If cleared in 2024</span><b>{sign(clearedNet)}</b></div>
      )}
      <small>{projected ? 'Keeping the palms turns the balance positive. Clearing them releases the stored carbon.' : 'Palms store more carbon as they mature.'} Sample figures for the {num(rows.length)} lands in view.</small>
    </div>
  )
}

/** One page: stat cards, comparison cards, map, charts and a table, all for one topic. */
function TopicPage({ d, sel, setSel, spec, bar }) {
  const [cat, setCat] = useState('')
  const [tlYear, setTlYear] = useState(ENV_NOW)
  const [landId, setLandId] = useState(null) // Environment page: the land picked on the map
  const [view, setView] = useState('absorb') // Environment map: absorb | emit | credit
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
  const maxOf = (f) => Math.max(1e-9, ...all.map(f))
  const maxSeq = spec.timeline ? maxOf((r) => r.seq) : 1
  const maxEmit = spec.timeline ? maxOf((r) => r.emit) : 1
  const maxCred = spec.timeline ? maxOf((r) => r.creditable) : 1
  // Environment map: what the palm shows depends on the view. Size follows the tonnes, the dot follows the meaning.
  const pinFor = (r) => {
    if (!spec.timeline) return { size: 30, color: catOf(r.cat).color, off: false }
    if (view === 'emit') return { size: 22 + Math.round((18 * r.emit) / maxEmit), color: '#c0392b', off: false }
    if (view === 'credit') return { size: 22 + Math.round((18 * r.creditable) / maxCred), color: CREDIT_STATUS[r.cstatus].color, off: r.cstatus === 'none' }
    return { size: 22 + Math.round((18 * r.seq) / maxSeq), color: '#2e7d32', off: false }
  }
  const viewTip = (r) => (view === 'credit'
    ? <>{CREDIT_STATUS[r.cstatus].text}<br />Credit-eligible {t1(r.creditable)} of {t1(r.seq)} absorbed<br />{PRACTICES.filter((x) => r.practices[x.key]).map((x) => x.label).join(', ') || 'No extra climate action yet'}</>
    : view === 'emit' ? <>Emits {t1(r.emit)} a year</>
      : <>Absorbs {t1(r.seq)} a year{r.kgPerPalm != null ? ` · ${Math.round(r.kgPerPalm)} kg CO₂ per palm` : ''}</>)
  const markers = all.map((r) => {
    const pin = pinFor(r)
    return {
      lat: r.e.lat, lng: r.e.lng, icon: catOf(r.cat).glyph, size: pin.size, color: pin.color, acres: r.e.acres,
      dim: !here(r) || (!!cat && r.cat !== cat) || (!!landId && r.e.id !== landId) || pin.off,
      ...(spec.timeline ? { size: r.e.id === landId ? 42 : pin.size, onClick: () => setLandId(r.e.id === landId ? null : r.e.id) } : {}),
      tip: <div className="an-tip"><b>{r.e.name}</b><br />{spec.timeline ? viewTip(r) : <>{r.cat}<br />{spec.tip(r)}</>}<br />{label(r.e.district)}{r.e.region ? ` · ${r.e.region}` : ''}</div>,
    }
  })
  const viewLegend = view === 'credit'
    ? Object.values(CREDIT_STATUS).map((c) => ({ icon: 'envpalm', color: c.color, text: c.text }))
    : view === 'emit' ? [{ icon: 'envpalm', color: '#c0392b', text: 'Emits CO₂ (bigger palm = more tonnes)' }]
      : [{ icon: 'envpalm', color: '#2e7d32', text: 'Absorbs CO₂ (bigger palm = more tonnes)' }]
  const viewSub = view === 'credit'
    ? 'Credits need extra climate action (new planting, intercrop, biochar), then verification and clear rights. Gold lands are ready; grey have the practice but are not verified; faded lands are not eligible yet.'
    : view === 'emit' ? 'Each palm is a land; a bigger palm emits more carbon from fuel, fertilizer, animals and waste.'
      : 'Each palm is a land; a bigger palm absorbs more CO₂ in its palms and soil. This is what keeping the coconut land is worth.'
  const cdoValue = (n) => sumBy(pool.filter((r) => r.e.region === n), mv)
  const areas = areaBars(sel, perD, spec.color)
  const top = [...scoped].sort((a, b) => spec.rank(b) - spec.rank(a)).slice(0, 7).map((r) => ({ name: r.e.name, value: spec.rank(r) }))
  const rows = scoped.map(spec.row)
  const land = landId ? all.find((r) => r.e.id === landId) : null
  const sections = () => [
    { title: `${spec.name} - ${scopeName(sel)}`, columns: spec.cols, rows },
    { title: `${spec.noun} by area`, columns: ['Area', spec.noun], rows: areas.map((r) => [r.name, r.value]) },
  ]

  return (
    <PageHead title={spec.title} sub={spec.sub} name={spec.name} sel={sel} onSel={setSel} sections={sections}>
      {bar}
      <PhotoRow items={spec.kpis(scoped, sel)} />
      <FigTiles items={spec.figs(scoped, sel)} />
      <ProvinceStrip startOpen byD={perD} fmt={spec.fmt || num} unit={spec.unit} sel={sel} setSel={setSel} color={spec.color} {...landStrip(d, sel, setSel, perD, spec.noun, cdoValue)} />
      <Split
        map={
          <Card title={spec.mapTitle} sub={spec.timeline ? viewSub : spec.mapSub} className="an-card-map" right={spec.timeline ? <Segmented value={view} onChange={setView} options={[['absorb', 'Absorbs CO₂'], ['emit', 'Emits'], ['credit', 'Credit-ready']]} /> : null}>
            <DrillMap
              geo={d.geo} values={perD} fmt={spec.fmt || num} unit={spec.unit} sel={sel} onSel={(x) => { setLandId(null); setSel(x) }} scale={spec.scale} markers={markers} badge={spec.timeline ? { html: (v) => `<span class="an-badge-fig nut">${glyphHtml('palm', '#2f8a4f', 44)}</span><b>${(spec.fmt || num)(v)}</b>` } : null} markerKey={`topic-${spec.name}-${cat}-${landId}-${view}`}
              overlay={<CatCard title={spec.catTitle} cats={spec.cats} value={cat} onChange={setCat} rows={all.filter(here)} />}
              legend={spec.timeline ? viewLegend : spec.cats.map((c) => ({ icon: c.glyph, color: c.color, text: c.name }))} height={spec.timeline ? 700 : 560}
              forest={!!spec.timeline} greenery onYear={spec.timeline ? setTlYear : null} forestInfo={spec.timeline ? (y, proj) => <EnvTimeline rows={scoped} year={y} projected={proj} /> : null}
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
      {spec.timeline && land && (
        <LandStats e={land.e} onClose={() => setLandId(null)} extra={[
          ['Carbon absorbed a year', t1(land.seq)], ['Per palm a year', land.kgPerPalm != null ? `${Math.round(land.kgPerPalm)} kg CO₂` : '-'], ['Carbon emitted a year', t1(land.emit)],
          ['Net balance', `${land.balance >= 0 ? '+' : '-'}${t1(Math.abs(land.balance))}`],
          ['Credit status', CREDIT_STATUS[land.cstatus].text], ['Credit-eligible a year', t1(land.creditable)],
          ['Credit income a year', land.cstatus === 'ready' ? rs(land.creditable * 12 * USD_LKR) : land.cstatus === 'pending' ? `${rs(land.creditable * 12 * USD_LKR)} once verified` : 'Rs. 0'],
        ]} />
      )}
      {spec.timeline && (
        <Card title="Carbon over the years" sub={`Stored, emitted and net balance for ${scoped.length} lands in ${scopeName(sel)}. Sample figures; dashed lines are a projection after ${ENV_NOW}. Move the map slider to move the marker.`}>
          <EnvTrend rows={scoped} year={tlYear} />
        </Card>
      )}
      {spec.timeline && (
        <Card title="Adopt a land" sub="Pick a land to see the carbon it stores, what the credits could earn its owner, and what keeping it is worth">
          <AdoptLand rows={scoped} />
        </Card>
      )}
      <Card title={spec.month.title} sub={spec.month.sub}>
        <Bars data={spec.month.data(scoped)} keys={spec.month.keys} colors={spec.month.colors} stacked={spec.month.keys.length > 1} single={spec.month.keys.length === 1} height={250} fmt={spec.month.fmt || compact} />
      </Card>
      <div className="an-grid2">
        <Card title={spec.second.title} sub={spec.second.sub}>
          <Bars data={spec.second.data(scoped)} horizontal height={spec.second.icons ? 260 : 230} nameWidth={spec.second.icons ? 245 : 140} fmt={spec.second.fmt || num} colors={[spec.second.color || spec.color]} single tickIcons={spec.second.icons} />
        </Card>
        {spec.third ? spec.third(scoped) : (
          <Card title={spec.topTitle} sub={spec.topSub}>
            <Bars data={top} horizontal height={230} nameWidth={140} fmt={spec.rankFmt || compact} colors={[spec.color]} single />
          </Card>
        )}
      </div>
      <Card title={`${spec.noun} list`} sub={`${scoped.length} lands, ${scopeName(sel)}`}>
        <DataTable columns={spec.cols} rows={rows} limit={10} cell={(v, j) => (j === 0 ? <LandId e={all.find((r) => r.e.id === v)?.e}>{v}</LandId> : v)} />
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
      ['tour-lands', 'palm', 'green', 'Tourism lands', num(s.length), 'open to visitors'],
      ['tour-visitors', 'users', 'blue', 'Visitors', compact(sumBy(s, (r) => r.visitors)), 'in a year'],
      ['tour-income', 'wallet', 'purple', 'Tourism income', rs(sumBy(s, (r) => r.money)), 'in a year'],
      ['tour-rating', 'trophy', 'amber', 'Average rating', s.length ? (sumBy(s, (r) => r.rating) / s.length).toFixed(1) : '-', 'out of 5, from visitors'],
    ],
    figs: (s) => {
      const t = top1(tally(s, TOUR))
      const v = sumBy(s, (r) => r.visitors)
      const f = sumBy(s, (r) => r.visitors * r.foreign)
      return [
        ['Most offered', t && t.value ? t.name : '-', t && t.value ? `on ${t.value} lands` : '', glyphRow(['planttour'], ['#0288d1'], 64)],
        ['Foreign visitors', v ? pct(f, v) : '-', v ? `${compact(f)} of ${compact(v)} visitors` : '', glyphRow(['farmstay', 'farmfood'], ['#0288d1', '#d99a0b'], 52)],
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
      ['aqua-farms', 'palm', 'blue', 'Fish farms', num(s.length), 'lands with ponds'],
      ['aqua-pond', 'pin', 'green', 'Pond area', `${(Math.round(sumBy(s, (r) => r.pond) * 10) / 10).toLocaleString('en-US')} ac`, 'under water'],
      ['aqua-harvest', 'truck', 'amber', 'Harvest', kgText(sumBy(s, (r) => r.kg)), 'in a year'],
      ['aqua-income', 'wallet', 'purple', 'Income', rs(sumBy(s, (r) => r.money)), 'in a year'],
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
      ['animal-farms', 'palm', 'brown', 'Livestock farms', num(s.length), 'lands with animals'],
      ['animal-kept', 'users', 'green', 'Animals kept', compact(sumBy(s, (r) => r.count)), 'including bee hives'],
      ['animal-milk', 'flask', 'blue', 'Milk', `${num(sumBy(s, (r) => r.milk))} L`, 'collected each day'],
      ['animal-eggs', 'gift', 'amber', 'Eggs', num(sumBy(s, (r) => r.eggs)), 'collected each day'],
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
      title: 'Cultivation type by crop', sub: 'How many lands of each crop are grown each way', keys: ['Coconut', 'Pepper', 'Pineapple', 'Peanut'], colors: ['#2f8a4f', '#9c2a23', '#d99a0b', '#b5803c'], fmt: num,
      data: (s) => CULT.map((c) => ({ name: c.name, Coconut: s.filter((r) => r.cat === c.name && r.e.crop === 'Coconut').length, Pepper: s.filter((r) => r.cat === c.name && r.e.crop === 'Pepper').length, Pineapple: s.filter((r) => r.cat === c.name && r.e.crop === 'Pineapple').length, Peanut: s.filter((r) => r.cat === c.name && r.e.crop === 'Peanut').length })),
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
      ['energy-lands', 'palm', 'amber', 'Lands with green energy', num(s.length), 'own their power'],
      ['energy-capacity', 'trend', 'green', 'Capacity', `${num(sumBy(s, (r) => r.kw))} kW`, 'installed'],
      ['energy-made', 'clock', 'blue', 'Power made', `${compact(sumBy(s, (r) => r.kwh))} kWh`, 'in a year'],
      ['energy-carbon', 'check', 'purple', 'Carbon avoided', t1(sumBy(s, (r) => r.co2)), 'a year, against grid power'],
    ],
    figs: (s) => {
      const t = top1(tally(s, ENERGY))
      return [
        ['Most used', t && t.value ? t.name : '-', t && t.value ? `on ${t.value} lands` : '', glyphRow(['energysolar'], ['#1565c0'], 62)],
        ['Saved on power bills', rs(sumBy(s, (r) => r.money)), 'in a year', glyphRow(['energysolar', 'energybiogas'], ['#1565c0', '#ef6c00'], 50)],
      ]
    },
    month: {
      title: 'Power made each month', sub: 'Kilowatt hours by system. Sample figures; solar is strongest in the dry months', keys: ENERGY.map((x) => x.name), colors: ENERGY.map((x) => x.color), fmt: (v) => `${compact(v)} kWh`,
      data: (s) => monthRows(ENERGY.map((x) => x.name), ENERGY.map((x) => monthly(sumBy(s.filter((r) => r.cat === x.name), (r) => r.kwh), x.name.startsWith('Solar') ? [1.1, 1.15, 1.2, 1.05, 0.85, 0.8, 0.85, 0.9, 0.9, 0.85, 0.85, 1] : WEEK))),
    },
    second: { title: 'Capacity by system', sub: 'Kilowatts installed', icons: { 'Solar panels': { kind: 'energysolar', color: '#1565c0' }, 'Solar water pump': { kind: 'energywater', color: '#0288d1' }, 'Biogas unit': { kind: 'energybiogas', color: '#ef6c00' }, 'Coconut-shell biomass': { kind: 'energyshell', color: '#8b4a1c' } }, fmt: (v) => `${num(v)} kW`, data: (s) => tally(s, ENERGY, (r) => r.kw).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'System', 'Capacity (kW)', 'Power a year', 'Carbon avoided', 'Saved a year'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, r.kw, `${num(r.kwh)} kWh`, t1(r.co2), rs(r.money)],
  },

  env: {
    title: 'Environment', sub: 'Carbon emitted by the lands, carbon stored by their trees, and the balance', name: 'Environment', noun: 'Emissions', unit: 'CO2',
    timeline: true,
    rows: (t) => t.env, cats: ENV, catTitle: 'Carbon balance', donutTitle: 'Carbon balance of lands', color: '#c0392b', scale: ['#f6e8df', '#e8c5ad', '#d49a73', '#b46a3f', '#7d3f1c'],
    mapTitle: 'Carbon emissions', mapSub: 'The shading is the carbon emitted in each area. A green cloud stores more than it emits, a red cloud emits more.',
    mapVal: (r) => r.emit, fmt: (v) => `${num(v)} t`,
    tip: (r) => `Emits ${t1(r.emit)} \u00b7 stores ${t1(r.seq)} \u00b7 balance ${r.balance >= 0 ? '+' : '-'}${t1(Math.abs(r.balance))}`,
    rank: (r) => r.emit, rankFmt: (v) => t1(v), topTitle: 'Biggest emitters', topSub: 'Carbon emitted in a year',
    kpis: (s) => [
      ['env-emitted', 'trend', 'brown', 'Carbon emitted', t1(sumBy(s, (r) => r.emit)), 'fuel, fertilizer, animals and waste'],
      ['env-stored', 'palm', 'green', 'Carbon stored', t1(sumBy(s, (r) => r.seq)), 'by palms and crops'],
      ['env-net', 'scale', 'blue', 'Net balance', `${sumBy(s, (r) => r.balance) >= 0 ? '+' : '-'}${t1(Math.abs(sumBy(s, (r) => r.balance)))}`, sumBy(s, (r) => r.balance) >= 0 ? 'stored more than emitted' : 'emitted more than stored'],
      ['env-avoided', 'check', 'purple', 'Avoided by green energy', t1(sumBy(s, (r) => r.avoided)), 'less grid power used'],
    ],
    figs: (s) => {
      const ac = sumBy(s, (r) => r.e.acres)
      return [
        ['Emitted per acre', ac ? `${(sumBy(s, (r) => r.emit) / ac).toFixed(2)} t` : '-', 'of carbon, in a year', FIN_IMG('co2-cloud.svg')],
        ['Lands storing more', s.length ? pct(s.filter((r) => r.balance >= 0).length, s.length) : '-', `${num(s.filter((r) => r.balance >= 0).length)} of ${num(s.length)} lands`, FIN_IMG('co2-leaf.svg')],
        ['Credit-eligible carbon', t1(sumBy(s, (r) => r.creditable)), `${pct(sumBy(s, (r) => r.creditable), sumBy(s, (r) => r.seq))} of what is absorbed · ${num(s.filter((r) => r.cstatus === 'ready').length)} lands credit-ready`, FIN_IMG('carbon')],
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
    second: { title: 'Carbon stored by crop', sub: 'Tonnes held by the trees and plants, in a year', fmt: (v) => t1(v), color: '#2e7d32', icons: { Coconut: { kind: 'coconut', color: '#8b5a2b' }, Pepper: { kind: 'pepperplant', color: '#2f8a4f' }, Pineapple: { kind: 'pineapple', color: '#d99a0b' } }, data: (s) => ['Coconut', 'Pepper', 'Pineapple'].map((c) => ({ name: c, value: sumBy(s.filter((r) => r.e.crop === c), (r) => r.seq) })) },
    third: (s) => (
      <Card title="Where the emissions come from" sub="Share of the carbon emitted">
        <Donut fmt={(v) => t1(v)} height={190} data={[['Fuel and machines', '#8b4a1c', sumBy(s, (r) => r.fuel), 'tractor'], ['Fertilizer', '#d99a0b', sumBy(s, (r) => r.fert), 'sack'], ['Animals', '#c0392b', sumBy(s, (r) => r.live), 'cow'], ['Waste and other', '#7a8f84', sumBy(s, (r) => r.waste), 'flame']].map(([name, color, value, glyph]) => ({ name, color, value, glyph }))} />
      </Card>
    ),
    cols: ['ID', 'Land', 'Owner', 'District', 'Crop', 'Emitted', 'Stored', 'Avoided', 'Balance'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.e.crop, t1(r.emit), t1(r.seq), t1(r.avoided), `${r.balance >= 0 ? '+' : '-'}${t1(Math.abs(r.balance))}`],
  },

  loans: {
    title: 'Financial products', sub: 'Loans taken by land owners, from banks and lenders', name: 'Loans', noun: 'Loans', unit: 'loans',
    rows: (t) => t.loans, cats: LOAN, catTitle: 'Loan purpose', donutTitle: 'What the loans are for', color: '#7a4fb0',
    mapTitle: 'Where the loans are', mapSub: 'Each pin is a land with a loan, shown by what the loan is for.',
    tip: (r) => `${rs(r.amount)} \u00b7 ${r.lender} \u00b7 ${r.status}`,
    rank: (r) => r.amount, rankFmt: rs, topTitle: 'Biggest loans', topSub: 'Amount lent',
    kpis: (s) => [
      ['land-farmer', 'wallet', 'green', 'Loans', num(s.length), `${num(s.filter((r) => r.status === 'Active').length)} still active`],
      ['energy-capacity', 'wallet', 'purple', 'Lent in total', rs(sumBy(s, (r) => r.amount)), 'to land owners'],
      ['land-rows', 'scale', 'amber', 'Still owed', rs(sumBy(s, (r) => r.owing)), 'not yet repaid'],
      ['land-palm', 'check', 'brown', 'Overdue loans', num(s.filter((r) => r.status === 'Overdue').length), s.length ? `${pct(s.filter((r) => r.status === 'Overdue').length, s.length)} of the loans` : ''],
    ],
    figs: (s) => {
      const t = top1(tally(s, LOAN))
      return [
        ['Most common purpose', t && t.value ? t.name : '-', t && t.value ? `${t.value} loans` : '', FIN_IMG('loans')],
        ['Average interest', s.length ? `${(sumBy(s, (r) => r.rate) / s.length).toFixed(1)}%` : '-', 'a year', glyphRow(['bank'], ['#7a4fb0'], 60)],
      ]
    },
    month: {
      title: 'Loans given each month', sub: 'Rupees lent by purpose. Sample figures; most are taken before planting seasons', keys: LOAN.map((x) => x.name), colors: LOAN.map((x) => x.color), fmt: rs,
      data: (s) => monthRows(LOAN.map((x) => x.name), LOAN.map((x) => monthly(sumBy(s.filter((r) => r.cat === x.name), (r) => r.amount), [0.9, 1, 1.3, 1.4, 1.1, 0.8, 0.8, 0.9, 1.2, 1.3, 1, 0.9]))),
    },
    second: { title: 'Lent by bank', sub: 'Rupees lent', fmt: rs, data: (s) => LENDERS.map((n) => ({ name: n, value: sumBy(s.filter((r) => r.lender === n), (r) => r.amount) })).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'Purpose', 'Bank', 'Amount', 'Interest', 'Term', 'Status'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, r.lender, rs(r.amount), `${r.rate}%`, `${r.term} months`, r.status],
  },

  insure: {
    title: 'Financial products', sub: 'Insurance cover on registered lands, and the claims paid', name: 'Insurance', noun: 'Policies', unit: 'policies',
    rows: (t) => t.insure, cats: COVER, catTitle: 'Cover', donutTitle: 'What is insured', color: '#0288d1', scale: ['#e4eff5', '#bad7e6', '#86b6cf', '#4f8fb0', '#25607f'],
    mapTitle: 'Where the cover is', mapSub: 'Each pin is an insured land, shown by the kind of cover.',
    tip: (r) => `${rs(r.sum)} insured \u00b7 ${r.insurer} \u00b7 ${r.status}`,
    rank: (r) => r.sum, rankFmt: rs, topTitle: 'Highest cover', topSub: 'Sum insured',
    kpis: (s) => [
      ['ins-sign', 'check', 'blue', 'Policies', num(s.length), `${num(s.filter((r) => r.status === 'Active').length)} active`],
      ['land-grove', 'wallet', 'green', 'Sum insured', rs(sumBy(s, (r) => r.sum)), 'cover in total'],
      ['energy-lands', 'tag', 'amber', 'Premiums', rs(sumBy(s, (r) => r.premium)), 'paid in a year'],
      ['env-avoided', 'receipt', 'purple', 'Claims paid', rs(sumBy(s, (r) => r.paid)), `${num(sumBy(s, (r) => r.claims))} claims made`],
    ],
    figs: (s) => {
      const t = top1(tally(s, COVER))
      return [
        ['Most common cover', t && t.value ? t.name : '-', t && t.value ? `on ${t.value} lands` : '', FIN_IMG('insurance')],
        ['Claims per 100 policies', s.length ? String(Math.round((sumBy(s, (r) => r.claims) / s.length) * 100)) : '-', 'in the last year', glyphRow(['shield', 'sprout'], ['#2f8a4f', '#43a047'], 50)],
      ]
    },
    month: {
      title: 'Premiums and claims each month', sub: 'Rupees. Sample figures; claims peak after dry spells and in the rainy months', keys: ['Premiums', 'Claims paid'], colors: ['#0288d1', '#d9741a'], fmt: rs,
      data: (s) => monthRows(['Premiums', 'Claims paid'], [
        monthly(sumBy(s, (r) => r.premium), WEEK),
        monthly(sumBy(s, (r) => r.paid), [0.6, 0.7, 0.8, 0.9, 1.4, 1.5, 0.9, 0.8, 0.9, 1.4, 1.6, 1.2]),
      ]),
    },
    second: { title: 'Cover by insurer', sub: 'Rupees insured', fmt: rs, data: (s) => INSURERS.map((n) => ({ name: n, value: sumBy(s.filter((r) => r.insurer === n), (r) => r.sum) })).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'Cover', 'Insurer', 'Sum insured', 'Premium a year', 'Claims', 'Status'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, r.insurer, rs(r.sum), rs(r.premium), r.claims, r.status],
  },

  carbon: {
    title: 'Financial products', sub: 'Carbon credits earned by lands that store carbon, and what they sell for', name: 'Carbon credits', noun: 'Credit lands', unit: 'lands',
    rows: (t) => t.carbon, cats: CREDIT, catTitle: 'Credit status', donutTitle: 'Where the credits stand', color: '#2f8a4f',
    mapTitle: 'Where the credits come from', mapSub: 'Each pin is a land enrolled for carbon credits, shown by the status of its credits.',
    mapVal: (r) => r.credits, fmt: (v) => `${num(v)} t`,
    tip: (r) => `${num(r.credits)} t CO2e \u00b7 ${r.standard} \u00b7 ${r.cat}`,
    rank: (r) => r.credits, rankFmt: (v) => `${num(v)} t`, topTitle: 'Most credits', topSub: 'Tonnes of CO2e',
    kpis: (s) => [
      ['env-stored', 'palm', 'green', 'Lands enrolled', num(s.length), 'earning carbon credits'],
      ['env-avoided', 'scale', 'blue', 'Credits', `${num(sumBy(s, (r) => r.credits))} t`, 'tonnes of CO2e'],
      ['env-emitted', 'check', 'amber', 'Credits sold', `${num(sumBy(s, (r) => r.sold))} t`, s.length ? `${pct(sumBy(s, (r) => r.sold), sumBy(s, (r) => r.credits))} of all credits` : ''],
      ['land-farmer', 'wallet', 'purple', 'Earned', rs(sumBy(s.filter((r) => r.cat === 'Sold'), (r) => r.money)), 'from credits sold'],
    ],
    figs: (s) => {
      const c = sumBy(s, (r) => r.credits)
      return [
        ['Average price', c ? rs(sumBy(s, (r) => r.money) / c) : '-', 'for one tonne of CO2e', glyphRow(['coin'], ['#d99a0b'], 62)],
        ['Credits per acre', sumBy(s, (r) => r.e.acres) ? (c / sumBy(s, (r) => r.e.acres)).toFixed(2) : '-', 'tonnes a year', FIN_IMG('carbon')],
      ]
    },
    month: {
      title: 'Credits issued each month', sub: 'Tonnes of CO2e. Sample figures; most are issued after the yearly audit', keys: ['Issued', 'Sold'], colors: ['#43a047', '#d99a0b'], fmt: (v) => `${num(v)} t`,
      data: (s) => monthRows(['Issued', 'Sold'], [
        monthly(sumBy(s, (r) => r.credits), [0.5, 0.6, 1.8, 1.6, 0.8, 0.6, 0.6, 0.7, 1.5, 1.4, 0.8, 0.6]),
        monthly(sumBy(s, (r) => r.sold), [0.4, 0.5, 0.9, 1.3, 1.5, 1.2, 0.9, 0.8, 1, 1.4, 1.2, 0.7]),
      ]),
    },
    second: { title: 'Credits by standard', sub: 'Tonnes of CO2e', fmt: (v) => `${num(v)} t`, data: (s) => STANDARDS.map((n) => ({ name: n, value: sumBy(s.filter((r) => r.standard === n), (r) => r.credits) })).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'Status', 'Standard', 'Credits (t CO2e)', 'Price per tonne', 'Value'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, r.standard, num(r.credits), rs(r.price), rs(r.money)],
  },
}

export const LAND_TOPICS = {
  'soon-cultivation-type': 'cult',
  'soon-agri-tourism': 'tour',
  'soon-aquaculture': 'aqua',
  'soon-animal-husbandry': 'animal',
  'soon-green-energy': 'energy',
  'soon-environment': 'env',
  'an-finance': 'finance',
  'an-subsidies': 'subsidies',
  'soon-instruments': 'instruments',
  'soon-irrigation': 'irrigation',
  'soon-guns': 'guns',
  'soon-planting-materials': 'planting',
  'soon-chemicals': 'chemicals',
  'soon-error-correction': 'platform',
  'soon-audit-trail': 'platform',
}



// ----------------------------------------------------------------------------- the farm-input pages
const resSpec = (key, cfg) => {
  const R = RES[key]
  return {
    title: cfg.title, sub: cfg.sub, name: cfg.title, noun: cfg.noun, unit: 'lands',
    rows: (t) => t[key], cats: R.cats, catTitle: cfg.catTitle, donutTitle: cfg.donutTitle, color: cfg.color, scale: cfg.scale,
    mapTitle: cfg.mapTitle, mapSub: 'Each pin is a land that bought these, shown by what it bought.',
    tip: (r) => `${num(r.qty)} ${r.unit} \u00b7 ${rs(r.money)}`,
    rank: (r) => r.money, rankFmt: rs, topTitle: 'Biggest buyers', topSub: 'Spent over the year',
    kpis: (s) => [
      ['rotary', 'palm', 'green', 'Lands buying', num(s.length), 'lands that bought these'],
      ['koku_nagula', 'users', 'amber', cfg.qtyLabel, compact(sumBy(s, (r) => r.qty)), 'bought in the year'],
      ['disc_plough', 'wallet', 'blue', 'Spent', rs(sumBy(s, (r) => r.money)), 'in a year'],
      ['trailer', 'gift', 'purple', 'Average per land', rs(s.length ? sumBy(s, (r) => r.money) / s.length : 0), 'in a year'],
    ],
    figs: (s) => {
      const t = top1(tally(s, R.cats, (r) => r.money))
      const c = t && R.cats.find((x) => x.name === t.name)
      return [
        ['Most bought', t && t.value ? t.name : '-', t && t.value ? `${rs(t.value)} spent` : '', glyphRow([c ? c.glyph : R.cats[0].glyph], [c ? c.color : cfg.color], 62)],
        ['Suppliers used', num(new Set(s.map((r) => r.supplier)).size), 'different suppliers', glyphRow(R.cats.slice(0, 2).map((x) => x.glyph), R.cats.slice(0, 2).map((x) => x.color), 50)],
      ]
    },
    month: {
      title: `${cfg.title} bought each month`, sub: 'Rupees spent. Sample figures; more before the planting seasons', keys: ['Spent'], colors: [cfg.color], fmt: rs,
      data: (s) => monthRows(['Spent'], [monthly(sumBy(s, (r) => r.money), [0.9, 0.85, 1, 1.15, 1.1, 1, 0.95, 0.95, 1.05, 1.1, 1, 0.95])]),
    },
    second: { title: 'Spent on each kind', sub: 'Rupees over the year', fmt: rs, data: (s) => tally(s, R.cats, (r) => r.money).sort((a, b) => b.value - a.value) },
    cols: ['ID', 'Land', 'Owner', 'District', 'Kind', 'Quantity', 'Supplier', 'Spent'],
    row: (r) => [r.e.id, r.e.name, r.e.owner, label(r.e.district), r.cat, `${num(r.qty)} ${r.unit}`, r.supplier, rs(r.money)],
  }
}
SPECS.instruments = resSpec('instruments', { title: 'Instruments', sub: 'Harvesting poles, climbing gear and hand tools bought by registered lands', noun: 'Lands with tools', qtyLabel: 'Tools bought', catTitle: 'Tool', donutTitle: 'Kinds of tool', color: '#8b4a1c', scale: ['#f6e8df', '#e8c5ad', '#d49a73', '#b46a3f', '#7d3f1c'], mapTitle: 'Where the tools went' })
SPECS.irrigation = resSpec('irrigation', { title: 'Irrigation equipment', sub: 'Drip kits, sprinklers, pumps and pipes bought by registered lands', noun: 'Lands with irrigation', qtyLabel: 'Sets bought', catTitle: 'Equipment', donutTitle: 'Kinds of equipment', color: '#0288d1', scale: ['#e4eff5', '#bad7e6', '#86b6cf', '#4f8fb0', '#25607f'], mapTitle: 'Where the water systems went' })
SPECS.guns = resSpec('guns', { title: 'Guns', sub: 'Spray guns, power sprayers and foggers bought by registered lands', noun: 'Lands with sprayers', qtyLabel: 'Sprayers bought', catTitle: 'Sprayer', donutTitle: 'Kinds of sprayer', color: '#d9741a', scale: ['#fbefe0', '#f3d2a8', '#e8a95e', '#cf7a26', '#8f4d0d'], mapTitle: 'Where the sprayers went' })
SPECS.planting = resSpec('planting', { title: 'Planting materials', sub: 'Seedlings, seed nuts, tissue-culture and pepper plants bought by registered lands', noun: 'Lands planting', qtyLabel: 'Plants bought', catTitle: 'Material', donutTitle: 'Kinds of planting material', color: '#43a047', scale: ['#e6f3e8', '#bfe0c5', '#8ec99a', '#4ea963', '#25703a'], mapTitle: 'Where new plants went' })
SPECS.chemicals = resSpec('chemicals', { title: 'Chemicals', sub: 'Pesticides, fungicides, weedicides and soil lime bought by registered lands', noun: 'Lands using chemicals', qtyLabel: 'Quantity bought', catTitle: 'Chemical', donutTitle: 'Kinds of chemical', color: '#c0392b', scale: ['#fbe9e6', '#f2c2bb', '#e0867a', '#c4503f', '#8a2b1d'], mapTitle: 'Where the chemicals went' })

// Each subsidy reuses the donation page: the same funding sources, counted in that subsidy's own unit.
const SUB_UNITS = { Machinery: ['machines', 2500], Instruments: ['tool sets', 120], 'Irrigation Equipment': ['kits', 400], Guns: ['sprayers', 300], 'Planting Materials': ['plants', 0.2], Chemicals: ['litres', 1] }
const subKinds = {}
function subsidyKind(name) {
  if (subKinds[name]) return subKinds[name]
  const k = SUBS.find((x) => x.name === name)
  const all = !k
  const [unit, scale] = all ? ['', 1 / 450] : SUB_UNITS[name]
  const types = all ? [] : k.schemes
  const fmt = all ? (v) => rs(v) : (v) => `${num(v)} ${unit}`
  subKinds[name] = {
    name: all ? 'All subsidies' : k.name, page: 'Subsidies', glyph: all ? 'gift' : k.glyph, color: all ? '#d99a0b' : k.color, noun: all ? 'subsidies' : k.name.toLowerCase(),
    perFarmer: all ? (v) => `${rs(v)} per farmer` : (v) => `${num(Math.round(v * 10) / 10)} ${unit} per farmer`,
    types: name === 'Planting Materials' ? [...types, 'Pepper plants'] : types, typeLabel: 'Scheme', fmt, axis: (v) => compact(v),
    derive: (x) => {
      // a donor given in dollars is counted in rupees on the All page, so the cards show the real amount
      const base = Math.round(x.kg / scale)
      const fixed = x.usd ? x.usd * USD_LKR : x.lkr // an amount given in dollars or rupees
      const factor = all && fixed ? fixed / (base || 1) : 1
      // a funder does not reach every district with every kind of subsidy, so each pick reaches its own districts and farmers
      const reach = (a) => (all ? 1 : hr(x.id, `reach${name}${a.district}`) < 0.78 ? 0.45 + 0.55 * hr(x.id, `far${name}${a.district}`) : 0)
      const areas = x.areas.map((a) => ({ ...a, kg: Math.round((a.kg / scale) * factor), farmers: all ? a.farmers : Math.round(a.farmers * reach(a)) })).filter((a) => a.kg > 0 && (all || reach(a) > 0))
      const type = all ? (x.scheme || (x.only ? x.only.join(' + ') : 'All subsidies')) : x.scheme || pickOf(k.schemes, hr(x.id, `dk${name}`))
      return { ...x, kg: all && fixed ? Math.round(fixed) : base, delivered: sumBy(areas, (a) => a.kg), areas, type }
    },
  }
  return subKinds[name]
}

function Subsidies({ d, sel, setSel }) {
  const [kind, setKind] = useState('')
  const [pickedId, setPickedId] = useState(d.donations[0]?.id)
  // pick the funder first; the subsidy types that follow are the ones that funder gives
  const donor = d.donations.find((x) => x.id === pickedId)
  const kinds = SUBS.map((x) => x.name)
  const allowed = donor?.only ? kinds.filter((k) => donor.only.includes(k)) : kinds
  const nameOf = (k) => (donor?.scheme && k === 'Planting Materials' ? donor.scheme : k) // the ADB only gives pepper plants
  const here = allowed.includes(kind) ? kind : ''
  const chips = <Chips value={here ? nameOf(here) : ''} onChange={(v) => setKind(v ? allowed.find((k) => nameOf(k) === v) || '' : '')} options={allowed.map(nameOf)} all="All" />
  const kindBar = (
    <div className="an-filterbar">
      <span>Subsidy</span>
      {chips}
    </div>
  )
  if (here === 'Fertilizer') return <Donations d={d} sel={sel} setSel={setSel} pickedId={pickedId} onPickId={setPickedId} kindBar={kindBar} cardKind={subsidyKind('')} />
  return <Donations key={here} d={d} sel={sel} setSel={setSel} pickedId={pickedId} onPickId={setPickedId} kindBar={kindBar} kind={subsidyKind(here)} cardKind={subsidyKind('')} />
}

const FIN_IMG = (name) => <img src={`/finance/${name.includes('.') ? name : name + '.png'}`} alt="" style={{ height: 118, width: 'auto', objectFit: 'contain', display: 'block' }} />
const FIN_TABS = [['loans', 'Loans'], ['insure', 'Insurance'], ['carbon', 'Carbon credits']]
function Finance({ d, sel, setSel }) {
  const [tab, setTab] = useState('loans')
  const bar = (
    <div className="an-filterbar">
      <span>Financial product</span>
      <Segmented value={tab} onChange={setTab} options={FIN_TABS} />
    </div>
  )
  return <TopicPage key={tab} d={d} sel={sel} setSel={setSel} spec={SPECS[tab]} bar={bar} />
}

export default function LandTopic({ view, d, sel, setSel }) {
  if (LAND_TOPICS[view] === 'platform') return <PlatformPage view={view} d={d} sel={sel} setSel={setSel} />
  if (LAND_TOPICS[view] === 'finance') return <Finance d={d} sel={sel} setSel={setSel} />
  if (LAND_TOPICS[view] === 'subsidies') return <Subsidies d={d} sel={sel} setSel={setSel} />
  if (LAND_TOPICS[view] === 'cult') return <Overview key={view} d={d} sel={sel} setSel={setSel} mode="crops" />
  return <TopicPage key={view} d={d} sel={sel} setSel={setSel} spec={SPECS[LAND_TOPICS[view]]} />
}

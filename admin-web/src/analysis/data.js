// Dummy dataset for the Analysis dashboard.
// Everything is generated from a fixed seed so the numbers are the same on
// every load. Replace `buildDataset` with API calls when the real tables exist.

export const DISTRICTS = [
  ['Colombo', 'Western', 0.6],
  ['Gampaha', 'Western', 1.4],
  ['Kalutara', 'Western', 1.1],
  ['Kandy', 'Central', 0.9],
  ['Matale', 'Central', 0.9],
  ['NuwaraEliya', 'Central', 0.2],
  ['Galle', 'Southern', 0.9],
  ['Matara', 'Southern', 0.9],
  ['Hambantota', 'Southern', 0.5],
  ['Jaffna', 'Northern', 0.7],
  ['Kilinochchi', 'Northern', 0.3],
  ['Mannar', 'Northern', 0.2],
  ['Vavuniya', 'Northern', 0.1],
  ['Mullaitivu', 'Northern', 0.2],
  ['Batticaloa', 'Eastern', 0.4],
  ['Ampara', 'Eastern', 0.3],
  ['Trincomalee', 'Eastern', 0.3],
  ['Kurunegala', 'North Western', 4.6],
  ['Puttalam', 'North Western', 2.0],
  ['Anuradhapura', 'North Central', 0.5],
  ['Polonnaruwa', 'North Central', 0.3],
  ['Badulla', 'Uva', 0.3],
  ['Moneragala', 'Uva', 0.3],
  ['Ratnapura', 'Sabaragamuwa', 0.5],
  ['Kegalle', 'Sabaragamuwa', 0.8],
].map(([name, province, w]) => ({ name, province, w }))

/** One colour per province, used on the map, tiles and charts. */
export const PROVINCE_COLORS = {
  'North Western': '#256b45',
  Western: '#2f7396',
  Central: '#7a4fb0',
  Southern: '#d08a1f',
  Northern: '#c0562b',
  Eastern: '#1f9e8f',
  'North Central': '#9aa02a',
  Uva: '#b8467a',
  Sabaragamuwa: '#5a6b7c',
}
const mixWhite = (hex, t) => {
  const n = parseInt(hex.slice(1), 16)
  const c = (v) => Math.round(255 + (v - 255) * t)
  return `rgb(${c((n >> 16) & 255)},${c((n >> 8) & 255)},${c(n & 255)})`
}
/** Light-to-dark steps of one colour. */
export const rampOf = (hex) => [0.16, 0.38, 0.6, 0.8, 1].map((t) => mixWhite(hex, t))

export const PROVINCE_NAMES = [...new Set(DISTRICTS.map((d) => d.province))]
export const provinceOf = (district) => DISTRICTS.find((d) => d.name === district)?.province
export const label = (name) => (name || '').replace(/([a-z])([A-Z])/g, '$1 $2')
export const districtsOf = (province) => DISTRICTS.filter((d) => d.province === province)

/** A selection is {province?, district?}. Empty means the whole island. */
export function inScope(sel, district) {
  if (!sel || !sel.province) return true
  if (provinceOf(district) !== sel.province) return false
  return !sel.district || sel.district === district
}
export const scopeName = (sel) =>
  sel?.district ? `${label(sel.district)} district` : sel?.province ? `${sel.province} Province` : 'Sri Lanka'

// ---- small helpers ---------------------------------------------------------
function rngOf(seed) {
  let a = seed
  return () => {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}
function wpick(rng, items, weight) {
  const total = items.reduce((s, i) => s + weight(i), 0)
  let r = rng() * total
  for (const i of items) {
    r -= weight(i)
    if (r <= 0) return i
  }
  return items[items.length - 1]
}
const split = (rng, total, weights) => {
  const noisy = weights.map((w) => w * (0.8 + rng() * 0.4))
  const sum = noisy.reduce((a, b) => a + b, 0)
  const parts = noisy.map((w) => Math.floor((total * w) / sum))
  parts[0] += total - parts.reduce((a, b) => a + b, 0)
  return parts
}
const pad = (n) => String(n).padStart(2, '0')
export const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

function pointIn(ring, x, y) {
  let inside = false
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i]
    const [xj, yj] = ring[j]
    if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside
  }
  return inside
}

// ---- catalogues ------------------------------------------------------------
export const JOB_CATEGORIES = [
  // name, share, age weights (18-25,26-35,36-45,46-55,56+), female share, estate-type weights
  { name: 'Coconut Plucking', share: 0.2, age: [2, 5, 4, 2, 0.5], female: 0.02, est: [3, 4, 3, 1] },
  { name: 'Husking & Dehusking', share: 0.14, age: [2, 4, 4, 3, 1.5], female: 0.45, est: [2, 3, 3, 4] },
  { name: 'Weeding & Land Clearing', share: 0.15, age: [3, 4, 3, 2, 1], female: 0.3, est: [4, 4, 2, 1] },
  { name: 'Fertilizer Application', share: 0.1, age: [2, 4, 3, 2, 1], female: 0.35, est: [3, 4, 3, 1] },
  { name: 'Copra Making & Drying', share: 0.12, age: [1.5, 3, 4, 3, 2], female: 0.5, est: [2, 2, 2, 5] },
  { name: 'Planting & Nursery', share: 0.08, age: [3, 4, 3, 1.5, 0.5], female: 0.55, est: [2, 3, 3, 2] },
  { name: 'Irrigation & Maintenance', share: 0.09, age: [2, 3, 3, 3, 1.5], female: 0.1, est: [2, 3, 4, 1] },
  { name: 'Transport & Loading', share: 0.12, age: [4, 5, 3, 1.5, 0.3], female: 0.04, est: [2, 3, 3, 4] },
]
export const AGE_GROUPS = ['18–25', '26–35', '36–45', '46–55', '56+']
export const GENDERS = ['Male', 'Female', 'Other']
export const ESTATE_TYPES = ['Small holding (< 5 ac)', 'Medium estate (5–25 ac)', 'Large plantation (25+ ac)', 'Copra mill & processing']

export const FERT_TYPES = ['Urea', 'TSP', 'MOP', 'Dolomite', 'Organic compost', 'Coconut special mix']
export const FERT_YEARS = [2022, 2023, 2024, 2025, 2026]

export const MACHINE_TYPES = {
  TRACTOR: { label: 'Tractor', color: '#0288d1', services: ['Disc Ploughing', 'Land Preparation', 'Transport & Hauling'] },
  BACKHOE: { label: 'Backhoe', color: '#8e44ad', services: ['Land Clearing', 'Trenching', 'Pit Digging'] },
  HAND_TRACTOR: { label: 'Hand tractor', color: '#8b4a1c', services: ['Inter-row Tilling', 'Weeding'] },
}
export const BOOKING_STATUSES = ['Completed', 'Confirmed', 'Pending', 'Cancelled']

export const PRODUCTS = ['Raw coconuts', 'Dehusked coconuts', 'Coconut husks']

const NAME_A = ['Green Palm', 'Sunrise', 'Hill View', 'Lakshmi', 'Ceylon Gold', 'Rathna', 'Sea Breeze', 'Kapruka', 'Nelum', 'Mihiri', 'Ruhuna', 'Lanka Pride', 'Coco Valley', 'Isuru', 'Thilini', 'Vijaya', 'Siri', 'Dhanya', 'Pearl', 'Royal Palm', 'Nila', 'Ganga', 'Ranmali', 'Sandun']
const NAME_B = ['Estate', 'Plantation', 'Gardens', 'Holdings', 'Coconut Land']
const OWNERS = ['K. Perera', 'S. Fernando', 'N. Silva', 'R. Jayasuriya', 'M. Rajapaksha', 'A. Bandara', 'T. Wijesinghe', 'P. Gunawardena', 'D. Senanayake', 'L. Herath', 'C. Dissanayake', 'H. Amarasinghe', 'V. Kumar', 'F. Rahman', 'J. Selvam']
const PROVIDERS = ['Kamal Agro Services', 'Ruwan Machinery', 'Southern Tractors', 'Lanka Earthworks', 'Nimal Hire', 'Green Field Services', 'Ceylon Agro Hire', 'Perera Brothers', 'Sampath Machinery', 'Wijaya Contractors']

// ---- builder ---------------------------------------------------------------
export function buildDataset(geo) {
  const rng = rngOf(20261104)
  const shapes = {}
  for (const f of geo.features) {
    const polys = f.geometry.coordinates
    const rings = polys.map((p) => p[0])
    const xs = rings.flat().map((p) => p[0])
    const ys = rings.flat().map((p) => p[1])
    shapes[f.properties.district] = {
      rings,
      c: f.properties.c,
      box: [Math.min(...xs), Math.min(...ys), Math.max(...xs), Math.max(...ys)],
    }
  }
  const randomPoint = (district) => {
    const s = shapes[district]
    for (let i = 0; i < 60; i++) {
      const x = s.box[0] + rng() * (s.box[2] - s.box[0])
      const y = s.box[1] + rng() * (s.box[3] - s.box[1])
      if (s.rings.some((r) => pointIn(r, x, y))) return [y, x]
    }
    return s.c
  }

  // Estates --------------------------------------------------------------
  const estates = []
  const startMs = Date.parse('2024-02-01')
  const spanMs = Date.parse('2026-10-28') - startMs
  for (let i = 0; i < 96; i++) {
    const d = wpick(rng, DISTRICTS, (x) => x.w)
    const [lat, lng] = randomPoint(d.name)
    const acres = Math.max(1.5, Math.round(Math.exp(1.2 + rng() * 2.9) * 2) / 2)
    const when = new Date(startMs + Math.pow(rng(), 0.65) * spanMs)
    estates.push({
      id: `E-${String(i + 1).padStart(3, '0')}`,
      name: `${NAME_A[Math.floor(rng() * NAME_A.length)]} ${NAME_B[Math.floor(rng() * NAME_B.length)]}`,
      owner: OWNERS[Math.floor(rng() * OWNERS.length)],
      district: d.name,
      province: d.province,
      lat,
      lng,
      acres,
      palms: Math.round(acres * (60 + rng() * 25)),
      plan: acres > 25 ? 'Premium' : acres > 5 ? 'Standard' : 'Basic',
      registeredOn: when.toISOString().slice(0, 10),
    })
  }
  estates.sort((a, b) => a.registeredOn.localeCompare(b.registeredOn))
  estates.forEach((e, i) => (e.id = `E-${String(i + 1).padStart(3, '0')}`))

  // Day workers ----------------------------------------------------------
  const workers = [] // one row per district x category, with its own breakdowns
  for (const d of DISTRICTS) {
    for (const c of JOB_CATEGORIES) {
      const n = Math.round(d.w * 5200 * c.share * (0.8 + rng() * 0.4))
      const female = Math.round(n * c.female * (0.85 + rng() * 0.3))
      const other = Math.round(n * 0.004)
      workers.push({
        district: d.name,
        province: d.province,
        category: c.name,
        total: n,
        age: split(rng, n, c.age),
        gender: [n - female - other, female, other],
        estate: split(rng, n, c.est),
      })
    }
  }

  // Fertilizer -----------------------------------------------------------
  const yearBase = { 2022: 190000, 2023: 245000, 2024: 318000, 2025: 436000, 2026: 402000 }
  const typeShare = [0.26, 0.14, 0.17, 0.12, 0.19, 0.12]
  const season = [0.6, 0.7, 0.9, 1.3, 1.5, 1.1, 0.8, 0.8, 1.0, 1.3, 1.1, 0.7]
  const fert = [] // distributed to a district
  const donated = [] // received from donors, island-wide
  for (const y of FERT_YEARS) {
    const lastMonth = y === 2026 ? 10 : 12
    for (let m = 1; m <= lastMonth; m++) {
      FERT_TYPES.forEach((t, ti) => {
        const don = Math.round((yearBase[y] / 12) * season[m - 1] * typeShare[ti] * 6 * (0.9 + rng() * 0.2)) / 1
        donated.push({ year: y, month: m, type: t, kg: don })
        const rate = y === 2026 && m > 8 ? 0.55 + rng() * 0.2 : 0.9 + rng() * 0.08
        const dist = Math.round(don * rate)
        const allocParts = split(rng, don, DISTRICTS.map((d) => d.w + 0.05))
        const parts = allocParts.map((a) => Math.round(a * rate))
        DISTRICTS.forEach((d, di) => {
          if (parts[di] > 0)
            fert.push({ year: y, month: m, type: t, district: d.name, province: d.province, kg: parts[di], alloc: allocParts[di], farmers: Math.max(1, Math.round(parts[di] / (45 + rng() * 25))) })
        })
      })
    }
  }

  // Machinery ------------------------------------------------------------
  const machines = []
  const mixOf = (d) => (['Kurunegala', 'Puttalam', 'Gampaha', 'Kalutara'].includes(d) ? [4, 2, 2] : [3, 1, 3])
  for (let i = 0; i < 70; i++) {
    const d = wpick(rng, DISTRICTS, (x) => x.w)
    const [tw] = [mixOf(d.name)]
    const type = wpick(rng, ['TRACTOR', 'BACKHOE', 'HAND_TRACTOR'], (t) => tw[['TRACTOR', 'BACKHOE', 'HAND_TRACTOR'].indexOf(t)])
    const [lat, lng] = randomPoint(d.name)
    machines.push({
      id: `M-${String(i + 1).padStart(3, '0')}`,
      type,
      provider: PROVIDERS[Math.floor(rng() * PROVIDERS.length)],
      district: d.name,
      province: d.province,
      lat,
      lng,
      rate: type === 'BACKHOE' ? 9000 + Math.round(rng() * 4) * 500 : type === 'TRACTOR' ? 5000 + Math.round(rng() * 6) * 250 : 2400 + Math.round(rng() * 4) * 100,
      rating: Math.round((4 + rng() * 0.9) * 10) / 10,
      available: rng() > 0.28,
    })
  }
  const bookings = []
  for (let i = 0; i < 420; i++) {
    const m = machines[Math.floor(Math.pow(rng(), 1.3) * machines.length)]
    const months = Math.floor(rng() * 14) // 0 = Nov 2025 ... 13 = Dec 2026
    const date = new Date(2025, 10 + months, 1 + Math.floor(rng() * 27))
    const ownerD = rng() < 0.7 ? m.district : wpick(rng, DISTRICTS, (x) => x.w).name
    const svc = MACHINE_TYPES[m.type].services[Math.floor(rng() * 3) % MACHINE_TYPES[m.type].services.length]
    const qty = Math.round((2 + rng() * 7) * 2) / 2
    const list = Math.round(m.rate * qty)
    const agreed = Math.round(list * (0.88 + rng() * 0.12))
    const past = date < new Date(2026, 10, 4)
    const status = !past ? (rng() < 0.7 ? 'Confirmed' : 'Pending') : rng() < 0.08 ? 'Cancelled' : 'Completed'
    bookings.push({
      id: `B-${1000 + i}`,
      machine: m.id,
      type: m.type,
      service: svc,
      district: ownerD,
      province: provinceOf(ownerD),
      date: date.toISOString().slice(0, 10),
      qty,
      list,
      agreed,
      status,
    })
  }
  bookings.sort((a, b) => a.date.localeCompare(b.date))

  // Sales ----------------------------------------------------------------
  const sales = []
  const pBase = [1, 0.5, 0.9]
  const pPrice = [105, 140, 28] // Rs per nut (raw, dehusked) and per kg of husk
  for (let y = 2024; y <= 2026; y++) {
    for (let m = 1; m <= (y === 2026 ? 10 : 12); m++) {
      const growth = 1 + (y - 2024) * 0.28 + m * 0.012
      PRODUCTS.forEach((p, pi) => {
        const unitPrice = pPrice[pi] * (0.92 + 0.1 * Math.sin((m / 12) * Math.PI * 2) + (y - 2024) * 0.07)
        const parts = split(rng, Math.round(90000 * pBase[pi] * growth * season[m - 1]), DISTRICTS.map((d) => d.w + 0.03))
        DISTRICTS.forEach((d, di) => {
          const qty = parts[di]
          if (qty > 0)
            sales.push({ year: y, month: m, product: p, district: d.name, province: d.province, qty, revenue: Math.round(qty * unitPrice), orders: Math.max(1, Math.round(qty / (pi === 0 ? 900 : 120))) })
        })
      })
    }
  }

  return { shapes, estates, workers, fert, donated, machines, bookings, sales }
}

let cache
export function loadDataset() {
  if (!cache) {
    cache = fetch('/geo/lk-districts.json')
      .then((r) => r.json())
      .then((geo) => ({ geo, ...buildDataset(geo) }))
  }
  return cache
}

// ---- formatting ------------------------------------------------------------
export const num = (n) => Math.round(n || 0).toLocaleString('en-US')
export const compact = (n) => {
  const v = Math.abs(n || 0)
  if (v >= 1e9) return `${(n / 1e9).toFixed(1)}B`
  if (v >= 1e6) return `${(n / 1e6).toFixed(1)}M`
  if (v >= 1e3) return `${(n / 1e3).toFixed(v >= 1e5 ? 0 : 1)}K`
  return String(Math.round(n || 0))
}
export const rs = (n) => `Rs. ${compact(n)}`
export const kgText = (n) => (Math.abs(n) >= 1000 ? `${(n / 1000).toFixed(1)} t` : `${num(n)} kg`)
export const ym = (y, m) => `${MONTHS[m - 1]} ${String(y).slice(2)}`
export const pct = (a, b) => (b ? `${Math.round((a / b) * 100)}%` : '—')
export const sumBy = (rows, f) => rows.reduce((s, r) => s + f(r), 0)
export function byDistrict(rows, f) {
  const out = {}
  for (const d of DISTRICTS) out[d.name] = 0
  for (const r of rows) out[r.district] += f(r)
  return out
}

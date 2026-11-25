import { provinceOf } from './data'

// Some coconut lands have Guinea grass growing on part of their area. Which lands, and how much,
// is made up for the demo, the same way the other figures on this dashboard are.
export const MANA = { name: 'Guinea grass', icon: 'mana', color: '#7d9a1f' }
export const WHITEFLY = { name: 'Whitefly', icon: 'whitefly', color: '#7a8f9a' }
export const MITE = { name: 'Coconut mite', icon: 'mite', color: '#c0392b' }

const rngOf = (seed) => {
  let a = seed
  return () => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const cache = new WeakMap()

/**
 * { mana, whitefly, mite }: one entry per land that has Guinea grass, whitefly or coconut mite, placed beside that land's palm.
 * Each has {id, land, kind, district, region, lat, lng, acres}. About one land in three has it
 * in the dry zone, more in North Western, fewer elsewhere.
 */
export function vegetationOf(d) {
  if (cache.has(d)) return cache.get(d)
  const dry = ['North Central', 'Uva', 'Eastern', 'Southern']
  const mana = []
  const whitefly = []
  const mite = []
  for (const e of d.estates) {
    if (e.crop !== 'Coconut') continue
    const rng = rngOf(Number(String(e.id).replace(/\D/g, '')) * 7919 + 20261120)
    const province = provinceOf(e.district)
    // pests: a different seed per pest, so a land can have none, one or both
    const pest = (seed, chance, kind, list, dLat, dLng, share) => {
      const r = rngOf(Number(String(e.id).replace(/\D/g, '')) * seed + 20261120)
      if (r() >= chance) return
      list.push({ id: e.id, land: e, kind, district: e.district, region: e.region, lat: e.lat + dLat, lng: e.lng + dLng, acres: Math.max(0.5, Math.round(e.acres * (share + r() * 0.15) * 10) / 10) })
    }
    pest(104729, province === 'North Western' ? 0.3 : 0.14, WHITEFLY.name, whitefly, 0.006, -0.026, 0.05)
    pest(15485863, province === 'North Western' ? 0.34 : dry.includes(province) ? 0.2 : 0.12, MITE.name, mite, -0.01, -0.012, 0.04)
    const chance = province === 'North Western' ? 0.45 : dry.includes(province) ? 0.32 : 0.18
    if (rng() >= chance) continue
    mana.push({
      id: e.id, land: e, kind: MANA.name, district: e.district, region: e.region,
      lat: e.lat - 0.004, lng: e.lng + 0.03, // beside the palm, not on top of it
      acres: Math.max(1, Math.round(e.acres * (0.1 + rng() * 0.25) * 10) / 10),
    })
  }
  const out = { mana, whitefly, mite }
  cache.set(d, out)
  return out
}

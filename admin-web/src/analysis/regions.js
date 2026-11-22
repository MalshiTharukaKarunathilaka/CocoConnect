import { pointIn } from './data'

// The small regions inside a district (only Kurunegala so far).
let cache
export const loadRegions = () => (cache ||= fetch('/geo/kurunegala-cdo.json').then((r) => r.json()))

const ringArea = (ring) => Math.abs(ring.reduce((a, p, i) => a + (p[0] * ring[(i + 1) % ring.length][1] - ring[(i + 1) % ring.length][0] * p[1]), 0) / 2)
const inside = (f, p) => pointIn(f.geometry.coordinates[0], p.lng, p.lat)

/**
 * Numbers for one region. Estates and machines have map coordinates, so they are
 * counted exactly. Day workers, fertilizer and sales are recorded per district, so
 * a region gets a share of them: its estates, plus a slice based on its area.
 */
export function regionFigures(geo, region, estates, machines) {
  const feats = geo.features
  const mine = feats.find((f) => f.properties.region === region)
  if (!mine) return null
  const inRegion = estates.filter((e) => inside(mine, e))
  const counts = feats.map((f) => estates.filter((e) => inside(f, e)).length)
  const areas = feats.map((f) => ringArea(f.geometry.coordinates[0]))
  const areaSum = areas.reduce((a, b) => a + b, 0) || 1
  const weights = counts.map((c, i) => c + (areas[i] / areaSum) * (estates.length * 0.5 + 1))
  const share = weights[feats.indexOf(mine)] / (weights.reduce((a, b) => a + b, 0) || 1)
  return {
    estates: inRegion,
    acres: inRegion.reduce((s, e) => s + e.acres, 0),
    palms: inRegion.reduce((s, e) => s + e.palms, 0),
    machines: machines.filter((m) => inside(mine, m)).length,
    share,
  }
}

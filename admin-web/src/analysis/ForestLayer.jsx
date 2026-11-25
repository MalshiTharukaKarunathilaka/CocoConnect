import { useEffect, useRef } from 'react'
import { useMap } from 'react-leaflet'
import L from 'leaflet'

// Real satellite data, no keys needed:
//   World imagery .... Esri (server.arcgisonline.com)
//   Tree cover 2000 .. Hansen / UMD / Google / USGS / NASA (earthengine.google.org)
//   Tree cover loss .. the same study, served by Global Forest Watch. Each pixel carries the year it was lost.
export const IMAGERY = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
export const COVER_2000 = 'https://earthengine.google.org/static/hansen_2013/tree_alpha/{z}/{x}/{y}.png'
const LOSS = 'https://tiles.globalforestwatch.org/umd_tree_cover_loss/v1.11/tcd_30/{z}/{x}/{y}.png'
export const FIRST_YEAR = 2001
export const LAST_YEAR = 2026 // the latest year shown as data (this year)
export const CURRENT_YEAR = 2026 // this year: the marker on the timeline and charts
export const PROJ_END = 2030 // years after CURRENT_YEAR are a projection

const RED = [232, 62, 40]
const YELLOW = [255, 214, 10]

// Paint a tile: every pixel lost up to `year` is red, the ones lost in `year` itself are yellow.
function paint(canvas, year) {
  const years = canvas._years
  if (!years) return
  const ctx = canvas.getContext('2d')
  const img = ctx.createImageData(256, 256)
  const last = year - 2000
  for (let i = 0; i < years.length; i++) {
    const y = years[i]
    if (!y || y > last) continue
    const c = y === last ? YELLOW : RED
    const o = i * 4
    img.data[o] = c[0]
    img.data[o + 1] = c[1]
    img.data[o + 2] = c[2]
    img.data[o + 3] = 235
  }
  ctx.putImageData(img, 0, 0)
}

/** Tree cover lost up to a year, drawn on the map. Changing `year` repaints the tiles already loaded; it does not download them again. */
export default function ForestLayer({ year, onError, onReady }) {
  const map = useMap()
  const layer = useRef(null)
  const yearRef = useRef(year)
  yearRef.current = year

  useEffect(() => {
    const tiles = new Set()
    const grid = L.gridLayer({ tileSize: 256, zIndex: 5, maxNativeZoom: 12, attribution: 'Forest data: Hansen / UMD / Google / USGS / NASA, Global Forest Watch · Imagery: Esri' })
    grid.createTile = (coords, done) => {
      const canvas = document.createElement('canvas')
      canvas.width = 256
      canvas.height = 256
      const img = new Image()
      img.crossOrigin = 'anonymous'
      img.onload = () => {
        try {
          const probe = document.createElement('canvas')
          probe.width = 256
          probe.height = 256
          const pctx = probe.getContext('2d', { willReadFrequently: true })
          pctx.drawImage(img, 0, 0, 256, 256)
          const px = pctx.getImageData(0, 0, 256, 256).data
          const years = new Uint8Array(256 * 256)
          for (let i = 0; i < years.length; i++) if (px[i * 4 + 3] > 0) years[i] = px[i * 4 + 2]
          canvas._years = years
          tiles.add(canvas)
          paint(canvas, yearRef.current)
          done(null, canvas)
          onReady && onReady()
        } catch (e) {
          done(e, canvas)
          onError && onError()
        }
      }
      img.onerror = () => {
        done(new Error('tile failed'), canvas)
        onError && onError()
      }
      img.src = L.Util.template(LOSS, { z: coords.z, x: coords.x, y: coords.y })
      return canvas
    }
    grid.on('tileunload', (e) => tiles.delete(e.tile))
    grid._tiles_set = tiles
    grid.addTo(map)
    layer.current = grid
    return () => {
      grid.remove()
      layer.current = null
    }
  }, [map]) // eslint-disable-line

  useEffect(() => {
    const grid = layer.current
    if (!grid) return
    grid._tiles_set.forEach((c) => paint(c, year))
  }, [year])

  return null
}

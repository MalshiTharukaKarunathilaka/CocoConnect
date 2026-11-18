import L from 'leaflet'

// Map glyphs. Estates are coconut palms; machines are coloured badges holding
// the silhouette of a tractor, a backhoe loader or a hand tractor, in its own colour.
// `bg` is the colour of wheel hubs and windows so they read as cut-outs.

const palm = (size) => `
<svg viewBox="0 0 32 32" width="${size}" height="${size}" style="overflow:visible;filter:drop-shadow(0 2px 2px rgba(0,0,0,.35))">
  <path d="M16 30 Q14.5 22 17 13" stroke="#8b4a1c" stroke-width="2.8" stroke-linecap="round" fill="none"/>
  <g stroke="#2f8a4f" stroke-width="3.2" stroke-linecap="round" fill="none">
    <path d="M17 13 Q8 5 2.5 11"/>
    <path d="M17 13 Q11 3 6 2.5"/>
    <path d="M17 13 Q18 2 24 1.5"/>
    <path d="M17 13 Q26 5 30 10"/>
    <path d="M17 13 Q27 12 29.5 19"/>
    <path d="M17 13 Q8 13 5.5 19"/>
  </g>
  <circle cx="15.4" cy="14.6" r="2.1" fill="#7a3f14"/>
  <circle cx="18.8" cy="15.2" r="2.1" fill="#8b4a1c"/>
</svg>`

const GLYPH = {
  // burlap fertilizer sack: tied neck, round belly, a plus mark cut out of it
  sack: (bg) => `
    <path d="M11.2 3.6 L20.8 3.6 L19.4 9 C26.2 12 28.4 19 26.4 25 C25.4 28.4 22 29.6 16 29.6 C10 29.6 6.6 28.4 5.6 25 C3.6 19 5.8 12 12.6 9 Z" fill="#fff"/>
    <path d="M12.4 9.8 Q16 11.8 19.6 9.8" stroke="${bg}" stroke-width="1.7" stroke-linecap="round" fill="none"/>
    <path d="M16 15.4 V24 M11.8 19.7 H20.2" stroke="${bg}" stroke-width="2.4" stroke-linecap="round" fill="none"/>`,
  // farm tractor: hood and exhaust at the front, glass cab, huge rear wheel
  tractor: (bg) => `
    <rect x="5.4" y="5" width="2.2" height="9" rx="1" fill="#fff"/>
    <path d="M2.5 14.5 H15 V22.5 H2.5 Z" fill="#fff"/>
    <path d="M14 6 H27 V8.4 H25.4 L26.4 19 H14 Z" fill="#fff"/>
    <path d="M16.6 9.8 H24 L24.6 16.2 H16.6 Z" fill="${bg}"/>
    <circle cx="22" cy="22" r="7.6" fill="#fff"/>
    <circle cx="22" cy="22" r="3" fill="${bg}"/>
    <circle cx="8" cy="24.6" r="4.4" fill="#fff"/>
    <circle cx="8" cy="24.6" r="1.7" fill="${bg}"/>`,
  // backhoe loader: bucket on the front arm, cab in the middle, digging arm at the back
  backhoe: (bg) => `
    <path d="M7 17.6 L2.6 15" stroke="#fff" stroke-width="2.6" stroke-linecap="round" fill="none"/>
    <path d="M0.8 11.6 H5.4 L5.4 18.8 L2.2 18.8 Z" fill="#fff"/>
    <path d="M9 7 H18.4 L19.4 19 H9 Z" fill="#fff"/>
    <path d="M11 9.2 H17.2 L17.8 14.6 H11 Z" fill="${bg}"/>
    <rect x="7.4" y="18.4" width="17" height="5" rx="1.6" fill="#fff"/>
    <path d="M24 18 L28.8 8.4 L24.2 4.4" stroke="#fff" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
    <path d="M24.2 4.4 L19.8 4 L20.8 10 L26.4 8.2 Z" fill="#fff"/>
    <circle cx="21.6" cy="24" r="5" fill="#fff"/>
    <circle cx="21.6" cy="24" r="1.9" fill="${bg}"/>
    <circle cx="8.6" cy="25" r="3.7" fill="#fff"/>
    <circle cx="8.6" cy="25" r="1.4" fill="${bg}"/>`,
  // walk-behind hand tractor: one big wheel, small engine, long handlebars
  hand: (bg) => `
    <circle cx="10.5" cy="21.6" r="8.2" fill="#fff"/>
    <circle cx="10.5" cy="21.6" r="3.3" fill="${bg}"/>
    <rect x="10" y="7.4" width="11" height="8.6" rx="2.4" fill="#fff"/>
    <rect x="11.6" y="4.4" width="4.4" height="3.6" rx="1" fill="#fff"/>
    <path d="M19.6 11.4 L28.4 4.8" stroke="#fff" stroke-width="2.8" stroke-linecap="round" fill="none"/>
    <path d="M26.2 3.4 L30 6.6" stroke="#fff" stroke-width="3.4" stroke-linecap="round" fill="none"/>
    <path d="M19.6 16.6 L24.4 22.4" stroke="#fff" stroke-width="2.8" stroke-linecap="round" fill="none"/>
    <circle cx="26.2" cy="25" r="4" fill="#fff"/>
    <circle cx="26.2" cy="25" r="1.4" fill="${bg}"/>`,
}

const OUTLINE =
  'drop-shadow(1.6px 0 0 #fff) drop-shadow(-1.6px 0 0 #fff) drop-shadow(0 1.6px 0 #fff) drop-shadow(0 -1.6px 0 #fff) drop-shadow(0 3px 3px rgba(0,0,0,.38))'

/** The silhouette in the machine's colour; wheel hubs and windows are cut out in white. */
const glyph = (kind, color, px) =>
  `<svg viewBox="0 0 32 32" width="${px}" height="${px}" style="display:block;overflow:visible;filter:${OUTLINE}">${GLYPH[kind]('#ffffff').replaceAll('"#fff"', `"${color}"`)}</svg>`

export const glyphHtml = (kind, color, size = 16) => (kind === 'palm' ? palm(size) : glyph(kind, color, size))

const cache = {}
/** A Leaflet icon for a pin. Cached, because there can be a hundred of them. */
export function pinIcon(kind, color, size, dim) {
  const key = `${kind}|${color}|${size}|${dim}`
  if (!cache[key]) {
    cache[key] = L.divIcon({
      html: kind === 'palm' ? palm(size) : glyph(kind, color, size),
      className: `an-pin${dim ? ' dim' : ''}`,
      iconSize: [size, size],
      iconAnchor: [size / 2, kind === 'palm' ? size - 2 : size / 2],
    })
  }
  return cache[key]
}

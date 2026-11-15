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
  fish: (bg) => `
    <path d="M2.5 16 C8 6.500 18 6.500 23 16 C18 25.500 8 25.500 2.500 16Z" fill="#fff"/>
    <path d="M21.500 16 L30 8.500 V23.500 Z" fill="#fff"/>
    <circle cx="9" cy="14" r="1.600" fill="${bg}"/>`,
  cow: (bg) => `
    <path d="M7 6 C4 6 2 4 2 2.500 C5 2.500 7 3.500 8 5Z M25 6 C28 6 30 4 30 2.500 C27 2.500 25 3.500 24 5Z" fill="#fff"/>
    <path d="M8 5 H24 C26.500 9 26.500 14 24 17 H8 C5.500 14 5.500 9 8 5Z" fill="#fff"/>
    <path d="M7 16 H25 V25 C25 28.500 22 30 16 30 C10 30 7 28.500 7 25Z" fill="#fff"/>
    <circle cx="12" cy="10.500" r="1.500" fill="${bg}"/><circle cx="20" cy="10.500" r="1.500" fill="${bg}"/>
    <ellipse cx="16" cy="23.500" rx="6" ry="4" fill="${bg}"/>
    <circle cx="14" cy="23.500" r="1.200" fill="#fff"/><circle cx="18" cy="23.500" r="1.200" fill="#fff"/>`,
  sun: (bg) => `
    <circle cx="16" cy="16" r="6.500" fill="#fff"/>
    <path d="M16 2.500V6.500M16 25.500V29.500M2.500 16H6.500M25.500 16H29.500M6.500 6.500L9.300 9.300M22.700 22.700L25.500 25.500M25.500 6.500L22.700 9.300M9.300 22.700L6.500 25.500" stroke="#fff" stroke-width="2.800" stroke-linecap="round" fill="none"/>`,
  cloud: (bg) => `
    <path d="M9 25 C3 25 2 17.500 7.500 16.500 C7.500 9.500 16.500 7 19.500 13 C25 11 30 16.500 26 21 C29.500 23 27.500 25 24 25Z" fill="#fff"/>
    <text x="16" y="21.500" text-anchor="middle" font-size="7.500" font-weight="700" font-family="Arial" fill="${bg}">CO2</text>`,
  tent: (bg) => `
    <path d="M1.500 27 L16 4.500 L30.500 27Z" fill="#fff"/>
    <path d="M12 27 L16 15 L20 27Z" fill="${bg}"/>`,
  sprout: (bg) => `
    <path d="M16 29.500 V15" stroke="#fff" stroke-width="2.800" stroke-linecap="round" fill="none"/>
    <path d="M16 18 C8 18 3.500 13 3.500 6 C11.500 6 16 10.500 16 18Z" fill="#fff"/>
    <path d="M16 14.500 C16 8 20 3.500 28.500 3.500 C28.500 11 24.500 15.500 16 14.500Z" fill="#fff"/>`,
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

// Crop pictures (real artwork) used as pins for pepper and pineapple.
const PHOTO = {
  pepper: ['/crops/pepper.png', 1.1], pineapple: ['/crops/pineapple.png', 0.82],
  sack: ['/crops/sack.png', 0.95, 0.95],
  tractor: ['/crops/tractor.png', 1.41, 0.7], hand: ['/crops/hand-tractor.png', 1.45, 0.7], backhoe: ['/crops/backhoe.png', 2.1, 0.6],
}
// A sack can be shown in other colours: turn the brown picture round the colour wheel.
const hueOf = (hex) => {
  const n = parseInt(String(hex || '#a5651e').replace('#', ''), 16)
  const r = ((n >> 16) & 255) / 255, g = ((n >> 8) & 255) / 255, b = (n & 255) / 255
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b)
  if (mx === mn) return 30
  const d = mx - mn
  const h = mx === r ? ((g - b) / d) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4
  return Math.round(((h * 60) + 360) % 360)
}
const photo = (kind, size, color) => {
  const [src, ratio, k = 1] = PHOTO[kind]
  const h = Math.round(size * k)
  return `<img src="${src}" alt="" width="${Math.round(h * ratio)}" style="display:block;height:${h}px;width:auto;filter:${kind === 'sack' && color ? `hue-rotate(${hueOf(color) - 33}deg) ` : ''}drop-shadow(0 2px 2px rgba(0,0,0,.35))"/>`
}

// Illustrated icons for the Land pages: shaded like the tractor and pepper pictures,
// not flat silhouettes. `c` is the main colour; light and dark are worked out from it.
const rgbOf = (hex) => {
  const n = parseInt(String(hex || '#2f8a4f').replace('#', ''), 16)
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255]
}
const mixHex = (hex, to, t) => {
  const a = rgbOf(hex)
  const b = rgbOf(to)
  return '#' + a.map((v, i) => Math.round(v + (b[i] - v) * t).toString(16).padStart(2, '0')).join('')
}
const RICH = {
  fish: (c, L, D, g) => `
    <path d="M22 16 L31 8.500 Q28.500 16 31 23.500 Z" fill="${D}"/>
    <path d="M9 9.500 Q14 3.500 20 9.500 Z" fill="${D}"/>
    <path d="M12 23 Q16 28 20 23 Z" fill="${D}"/>
    <ellipse cx="13.500" cy="16" rx="11.500" ry="8" fill="${g}"/>
    <ellipse cx="12.500" cy="12.200" rx="7.500" ry="2.600" fill="#fff" opacity=".35"/>
    <path d="M15 10.500 Q17.500 16 15 21.500 M19 11 Q21 16 19 21" stroke="${D}" stroke-width=".9" fill="none" opacity=".55"/>
    <circle cx="6.800" cy="14.500" r="2.200" fill="#fff"/><circle cx="6.500" cy="14.500" r="1.100" fill="#17202a"/>`,
  cow: (c, L, D) => `
    <rect x="7.500" y="20" width="3.200" height="9" rx="1.300" fill="#6d4c41"/><rect x="12" y="20" width="3.200" height="9" rx="1.300" fill="#5d4037"/>
    <rect x="18" y="20" width="3.200" height="9" rx="1.300" fill="#6d4c41"/><rect x="22.500" y="20" width="3.200" height="9" rx="1.300" fill="#5d4037"/>
    <path d="M5.500 14 Q1.500 15 2.500 23" stroke="#6d4c41" stroke-width="1.600" fill="none"/>
    <rect x="4.500" y="10.500" width="23" height="12.500" rx="6" fill="#fffaf0"/>
    <ellipse cx="11" cy="15" rx="3.800" ry="3" fill="${c}"/><ellipse cx="20.500" cy="18.500" rx="3.200" ry="2.500" fill="${c}"/>
    <rect x="22" y="4.500" width="9.500" height="10" rx="4" fill="#fffaf0"/><ellipse cx="28.200" cy="12.500" rx="3.300" ry="2.500" fill="#f3b5ad"/>
    <path d="M23.500 5 L22 1.800 M29.500 5 L31 1.800" stroke="#e8d9b5" stroke-width="1.800" stroke-linecap="round"/>
    <ellipse cx="22" cy="8.500" rx="2.400" ry="1.500" fill="${c}"/>
    <circle cx="26" cy="8" r="1.100" fill="#17202a"/>
    <ellipse cx="14" cy="12" rx="7" ry="1.800" fill="#fff" opacity=".6"/>`,
  goat: (c, L, D, g) => `
    <rect x="9" y="20" width="2.600" height="9" rx="1.100" fill="${D}"/><rect x="13" y="20" width="2.600" height="9" rx="1.100" fill="${D}"/>
    <rect x="18" y="20" width="2.600" height="9" rx="1.100" fill="${D}"/><rect x="22" y="20" width="2.600" height="9" rx="1.100" fill="${D}"/>
    <rect x="6" y="11.500" width="20" height="11.500" rx="5.500" fill="${g}"/>
    <path d="M24 12 L26 5.500 L30.500 8 L29 14 Z" fill="${g}"/>
    <path d="M25.500 5.500 Q24 1.500 21 2.500 M28 6 Q30.500 2 31.500 4" stroke="#e8dcc3" stroke-width="1.800" fill="none" stroke-linecap="round"/>
    <path d="M28.500 14 Q28 18 29.500 18.500" stroke="#f1eadb" stroke-width="1.800" fill="none" stroke-linecap="round"/>
    <circle cx="27.500" cy="9" r="1" fill="#17202a"/><ellipse cx="14" cy="13.500" rx="7" ry="1.900" fill="#fff" opacity=".35"/>`,
  hen: (c, L, D, g) => `
    <path d="M6.500 16 Q1.500 13 2.500 22 Q8.500 22 8 17 Z" fill="${D}"/>
    <path d="M13 26 V30 M18 26 V30" stroke="#f2a900" stroke-width="1.600" stroke-linecap="round"/>
    <ellipse cx="15" cy="19" rx="10.500" ry="8" fill="${g}"/>
    <ellipse cx="14" cy="19.500" rx="5.500" ry="3.800" fill="${D}" opacity=".6"/>
    <circle cx="24" cy="11" r="5.200" fill="${g}"/>
    <path d="M21.500 6.500 Q22 3 24 5 Q25.500 2.500 27 5.500 Q27.800 8 25 7.500 Z" fill="#d32f2f"/>
    <path d="M28.500 10.500 L32 12 L28.500 13.500 Z" fill="#f2a900"/><path d="M27 14 Q27.500 17 26 17" stroke="#d32f2f" stroke-width="2" fill="none"/>
    <circle cx="25.500" cy="10" r="1" fill="#17202a"/><ellipse cx="11" cy="14.500" rx="5" ry="1.800" fill="#fff" opacity=".35"/>`,
  hive: (c, L, D, g) => `
    <path d="M3.500 14.500 L16 6 L28.500 14.500 Z" fill="${D}"/>
    <rect x="6" y="14" width="20" height="14.500" rx="1.800" fill="${g}"/>
    <path d="M6 19 H26 M6 24 H26" stroke="${D}" stroke-width="1.100" opacity=".7"/>
    <rect x="12.500" y="25.500" width="7" height="2.200" rx="1" fill="#2b1b0f"/>
    <ellipse cx="25" cy="8" rx="3.400" ry="2.300" fill="#f9c22e"/><path d="M23.500 6 V10 M25.500 5.800 V10.200" stroke="#2b1b0f" stroke-width="1"/>
    <ellipse cx="24" cy="5.500" rx="2" ry="1.300" fill="#fff" opacity=".85"/>`,
  solar: (c, L, D, g) => `
    <rect x="14" y="22" width="3.200" height="6.500" fill="#8a949c"/><rect x="9" y="27.500" width="13" height="2.300" rx="1.100" fill="#6b757d"/>
    <path d="M4 23.500 L8.500 9.500 H29 L24.500 23.500 Z" fill="${g}"/>
    <path d="M6.200 16.500 H27 M10.500 23.500 L14 9.500 M17.500 23.500 L20 9.500 M24 23.500 L25.500 9.500" stroke="#fff" stroke-width=".9" opacity=".55"/>
    <path d="M8.500 9.500 H29 L28.200 12 H7.700 Z" fill="#fff" opacity=".28"/>
    <circle cx="6.500" cy="5.500" r="3.200" fill="#ffc107"/>
    <path d="M6.500 .8 V1.800 M1.800 5.500 H2.800 M10.200 2 L9.500 2.800 M2.800 9 L3.500 8.300" stroke="#ffb300" stroke-width="1.200" stroke-linecap="round"/>`,
  drop: (c, L, D, g) => `
    <path d="M16 2.500 C22.500 11 26 15 26 20 A10 10 0 0 1 6 20 C6 15 9.500 11 16 2.500 Z" fill="${g}"/>
    <path d="M10.500 19.500 Q10.500 14.500 14 11" stroke="#fff" stroke-width="2" fill="none" opacity=".6" stroke-linecap="round"/>
    <path d="M17.500 14 L12.500 21 H16 L14.500 27 L21 19 H17.200 Z" fill="#ffd54f" stroke="#e0a800" stroke-width=".6"/>`,
  flame: (c, L, D, g) => `
    <path d="M16 1.500 C18.500 8 25.500 12 25.500 20 A9.500 9.500 0 0 1 6.500 20 C6.500 14 11.500 12 11.500 5.500 C14 7 15 5 16 1.500 Z" fill="${g}"/>
    <path d="M16 13.500 C18 17 21.500 18 21.500 22.500 A5.500 5.500 0 0 1 10.500 22.500 C10.500 19 15 18 16 13.500 Z" fill="#ffe082"/>
    <path d="M16 19 C17 21 18.500 21.500 18.500 23.500 A2.500 2.500 0 0 1 13.500 23.500 C13.500 22 15.500 21.500 16 19 Z" fill="#fff8e1"/>`,
  shell: (c, L, D, g) => `
    <circle cx="16" cy="17" r="12.500" fill="${g}"/>
    <path d="M4.500 15 L2.500 12 M6 22 L3 24 M26 24 L29 25 M27.500 13 L30 11" stroke="${D}" stroke-width="1.300" stroke-linecap="round"/>
    <ellipse cx="16" cy="15.500" rx="8.500" ry="8" fill="#f3e3c3"/><ellipse cx="16" cy="15.500" rx="5.500" ry="5" fill="#fff9ea"/>
    <ellipse cx="11" cy="9.500" rx="5" ry="2" fill="#fff" opacity=".4"/>`,
  cloud: (c, L, D, g) => `
    <path d="M9 27 C2.500 27 1.500 18 8 17 C8 9.500 18.500 7 21.500 14 C28 12 32 20 26.500 24 C28.500 26 27 27 24.500 27 Z" fill="${g}"/>
    <ellipse cx="13" cy="12.500" rx="5.500" ry="2.200" fill="#fff" opacity=".4"/>
    <text x="16" y="23" text-anchor="middle" font-size="8.200" font-weight="800" font-family="Arial, sans-serif" fill="#fff">CO<tspan font-size="5.500" dy="1.500">2</tspan></text>`,
  tent: (c, L, D, g) => `
    <path d="M1.500 28.500 L16 4.500 L30.500 28.500 Z" fill="${g}"/>
    <path d="M16 4.500 L30.500 28.500 H21.500 Z" fill="${D}" opacity=".5"/>
    <path d="M11.500 28.500 L16 16.500 L20.500 28.500 Z" fill="#2b1b0f" opacity=".75"/>
    <path d="M16 4.500 V1" stroke="#6d4c41" stroke-width="1.400"/><path d="M16 1 L21 2.500 L16 4 Z" fill="#e53935"/>`,
  house: (c, L, D, g) => `
    <rect x="6" y="14.500" width="20" height="14" fill="${g}"/>
    <path d="M2.500 15.500 L16 3.500 L29.500 15.500 Z" fill="${D}"/><path d="M16 3.500 L29.500 15.500 H21 Z" fill="#000" opacity=".15"/>
    <rect x="13" y="20" width="6.200" height="8.500" rx="1" fill="#5d4037"/>
    <rect x="7.800" y="17.500" width="4" height="4" rx=".6" fill="#bfe3f5"/><rect x="20.500" y="17.500" width="4" height="4" rx=".6" fill="#bfe3f5"/>`,
  cup: (c, L, D, g) => `
    <circle cx="16" cy="19" r="11" fill="${g}"/>
    <ellipse cx="16" cy="11.500" rx="7.500" ry="2.800" fill="#f3e3c3"/><ellipse cx="16" cy="11.500" rx="5.500" ry="1.800" fill="#fff9ea"/>
    <path d="M18 11.500 L24 2" stroke="#e53935" stroke-width="2.200" stroke-linecap="round"/>
    <ellipse cx="11.500" cy="19" rx="3" ry="5" fill="#fff" opacity=".25"/>`,
  plate: (c, L, D, g) => `
    <path d="M3 4 V12 M1.500 4 V8 M4.500 4 V8 M3 12 V17" stroke="#9aa5ab" stroke-width="1.100" fill="none" stroke-linecap="round"/>
    <ellipse cx="17" cy="21" rx="13.500" ry="7.800" fill="#fff" stroke="#d6dbdd" stroke-width=".8"/>
    <ellipse cx="17" cy="21" rx="9" ry="4.800" fill="#eef1f2"/>
    <ellipse cx="17" cy="19.500" rx="6" ry="3.600" fill="${g}"/><ellipse cx="15.500" cy="18" rx="3" ry="1.600" fill="${L}"/>
    <path d="M14 14 Q13 11 15 9 M19 14 Q18 11 20 8.500" stroke="#b9c2c6" stroke-width="1" fill="none" stroke-linecap="round"/>`,
  sprout: (c, L, D, g) => `
    <ellipse cx="16" cy="28" rx="10" ry="2.800" fill="#6d4c41"/><ellipse cx="16" cy="27.300" rx="8" ry="1.800" fill="#8d6e63"/>
    <path d="M16 28 V13.500" stroke="#4f8f31" stroke-width="2.600" stroke-linecap="round"/>
    <path d="M16 19 C8 19 3.500 14 3.500 6.500 C11.500 6.500 16 11.500 16 19 Z" fill="${g}"/>
    <path d="M16 15.500 C16 8 20.500 3.500 28.500 3.500 C28.500 11 24 16.500 16 15.500 Z" fill="${L}"/>
    <path d="M16 19 C12 15 9 11.500 6.500 8.500" stroke="#fff" stroke-width=".8" opacity=".5" fill="none"/>`,
  sprouts: (c, L, D, g) => `
    <ellipse cx="16" cy="28.500" rx="14" ry="2.800" fill="#6d4c41"/><ellipse cx="16" cy="27.800" rx="12" ry="1.800" fill="#8d6e63"/>
    <path d="M9 28 V16" stroke="#4f8f31" stroke-width="2.200" stroke-linecap="round"/>
    <path d="M9 20 C3.500 20 1 16 1 11 C6 11 9 14.500 9 20 Z" fill="${g}"/><path d="M9 17.500 C9 12.500 12 9.500 17 9.500 C17 14.500 14 18 9 17.500 Z" fill="${L}"/>
    <path d="M23 28 V12" stroke="#4f8f31" stroke-width="2.200" stroke-linecap="round"/>
    <path d="M23 17 C17.500 17 15 13 15 8 C20 8 23 11.500 23 17 Z" fill="#e8a317"/><path d="M23 14.500 C23 9.500 26 6 31 6 C31 11 28 15 23 14.500 Z" fill="#f4c74f"/>`,
  basket: (c, L, D, g) => `
    <path d="M8.500 14 C8.500 3.500 23.500 3.500 23.500 14" stroke="${D}" stroke-width="2.200" fill="none" stroke-linecap="round"/>
    <circle cx="12" cy="13" r="3.200" fill="#e53935"/><circle cx="17.500" cy="11" r="3.400" fill="#fdd835"/><circle cx="21" cy="13.500" r="3" fill="#43a047"/>
    <path d="M3.500 14 H28.500 L25.500 28.500 H6.500 Z" fill="${g}"/>
    <path d="M5 18.500 H27 M5.800 23 H26.200" stroke="${D}" stroke-width="1" opacity=".6"/><path d="M11 14 L12 28.500 M16 14 V28.500 M21 14 L20 28.500" stroke="${D}" stroke-width=".9" opacity=".45"/>`,
  leaf: (c, L, D, g) => `
    <path d="M4.500 28 C4.500 12 13.500 3.500 28.500 3.500 C28.500 18.500 20 28 4.500 28 Z" fill="${g}"/>
    <path d="M4.500 28 L23 9.500" stroke="#fff" stroke-width="1.600" opacity=".7" stroke-linecap="round"/>
    <path d="M12 21.500 L12 14.500 M16.500 17 L16.500 11 M9.500 24 L5.500 21" stroke="#fff" stroke-width=".9" opacity=".45"/>
    <path d="M4.500 28 C2.500 28.500 1.500 29.500 .5 31" stroke="${D}" stroke-width="1.400" fill="none" stroke-linecap="round"/>`,
}
const richSvg = (kind, color, size) => {
  const c = color || '#2f8a4f'
  const L = mixHex(c, '#ffffff', 0.5)
  const D = mixHex(c, '#000000', 0.34)
  const id = `rg-${kind}-${c.replace('#', '')}`
  const g = `url(#${id})`
  const defs = `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0.25" y2="1"><stop offset="0" stop-color="${L}"/><stop offset=".45" stop-color="${c}"/><stop offset="1" stop-color="${D}"/></linearGradient></defs>`
  return `<svg viewBox="0 0 32 32" width="${size}" height="${size}" style="display:block;overflow:visible;filter:drop-shadow(0 0 1px #fff) drop-shadow(0 2px 2px rgba(0,0,0,.4))">${defs}${RICH[kind](c, L, D, g)}</svg>`
}
const markup = (kind, color, size) => (kind === 'palm' ? palm(size) : PHOTO[kind] ? photo(kind, size, color) : RICH[kind] ? richSvg(kind, color, size) : glyph(kind, color, size))
export const glyphHtml = (kind, color, size = 16) => markup(kind, color, size)

const cache = {}
/** A Leaflet icon for a pin. Cached, because there can be a hundred of them. */
export function pinIcon(kind, color, size, dim, label) {
  const key = `${kind}|${color}|${size}|${dim}|${label || ''}`
  if (!cache[key]) {
    cache[key] = L.divIcon({
      html: markup(kind, color, size) + (label ? `<span class="an-pin-lab">${label}</span>` : ''),
      className: `an-pin${dim ? ' dim' : ''}`,
      iconSize: [size, size],
      iconAnchor: [size / 2, kind === 'palm' || PHOTO[kind] || RICH[kind] ? size - 2 : size / 2],
    })
  }
  return cache[key]
}

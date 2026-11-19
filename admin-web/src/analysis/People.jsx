import { useId, useState } from 'react'

/**
 * Friendly, rendered-style Sri Lankan characters. Big eyes, soft shading, a
 * little bounce, blinking and a wave. `stage` is the age: 0 (18-25) .. 4 (56+).
 */
const HAIR = ['#17100d', '#17100d', '#241812', '#3c342f', '#d6d6d8']
const MALE_TOP = ['#3d8fbf', '#5fa47b', '#d9a441', '#9a5a2a', '#7e96a3']
const FEMALE_TOP = ['#6b7a2c', '#8a2f3c', '#2f7a73', '#b8892a', '#56657a']
const FEMALE_SCARF = ['#f7efdb', '#f7efdb', '#f7efdb', '#f4ecd9', '#f1ebdc']

/**
 * Uses a real picture when one exists: /characters/m-0.png ... m-4.png and
 * f-0.png ... f-4.png (transparent background, full body). Otherwise the
 * drawn character below is used.
 */
export function Character(props) {
  const [missing, setMissing] = useState(false)
  const { gender = 'M', stage = 1, height = 190, active = false, delay = 0 } = props
  if (missing) return <DrawnCharacter {...props} />
  return (
    <img
      src={`/characters/${gender === 'F' ? 'f' : 'm'}-${stage}.png`}
      alt={gender === 'F' ? 'Woman' : 'Man'}
      height={height}
      className={`ch-img ${active ? 'ch-active' : ''}`}
      style={{ height, animationDelay: `${delay}s` }}
      onError={() => setMissing(true)}
    />
  )
}

function DrawnCharacter({ gender = 'M', stage = 1, height = 190, active = false, delay = 0 }) {
  const uid = useId().replace(/:/g, '')
  const female = gender === 'F'
  const hair = HAIR[stage]
  const top = female ? FEMALE_TOP[stage] : MALE_TOP[stage]
  const broad = stage >= 3 ? 5 : 0
  const g = (n) => `${n}-${uid}`
  const style = { animationDelay: `${delay}s` }
  return (
    <svg viewBox="0 0 160 250" height={height} width={height * 0.64} className={`ch ${active ? 'ch-active' : ''}`} role="img" aria-label={`${female ? 'Woman' : 'Man'}, age group ${stage + 1}`}>
      <defs>
        <radialGradient id={g('skin')} cx="36%" cy="30%" r="85%">
          <stop offset="0" stopColor="#e9b88e" />
          <stop offset="0.55" stopColor="#c98f63" />
          <stop offset="1" stopColor="#97633f" />
        </radialGradient>
        <linearGradient id={g('top')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor={top} />
          <stop offset="1" stopColor={top} stopOpacity="0.72" />
        </linearGradient>
        <linearGradient id={g('saree')} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0" stopColor="#fbf4e1" />
          <stop offset="1" stopColor="#e6d9bb" />
        </linearGradient>
        <linearGradient id={g('sarong')} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stopColor="#ffffff" />
          <stop offset="1" stopColor="#d9dde0" />
        </linearGradient>
        <radialGradient id={g('hair')} cx="35%" cy="22%" r="90%">
          <stop offset="0" stopColor={hair} stopOpacity="0.78" />
          <stop offset="1" stopColor={hair} />
        </radialGradient>
        <radialGradient id={g('iris')} cx="40%" cy="35%" r="70%">
          <stop offset="0" stopColor="#8a5a34" />
          <stop offset="1" stopColor="#3d2415" />
        </radialGradient>
        <filter id={g('blur')}><feGaussianBlur stdDeviation="4" /></filter>
      </defs>

      <ellipse cx="80" cy="238" rx="50" ry="8" fill="#000" opacity="0.22" filter={`url(#${g('blur')})`} />

      <g className="ch-body" style={style}>
        {/* back hair (long for women) */}
        {female && stage < 4 && <path d="M43 58 Q38 14 80 12 Q122 14 117 58 Q122 104 104 118 L56 118 Q38 104 43 58Z" fill={`url(#${g('hair')})`} />}

        {/* legs */}
        {female ? (
          <g>
            <path d="M54 148 Q80 158 106 148 L117 226 Q80 238 43 226 Z" fill={`url(#${g('saree')})`} />
            <g fill="#5f8f4a" opacity="0.55">
              <ellipse cx="66" cy="172" rx="4" ry="2" transform="rotate(-30 66 172)" />
              <ellipse cx="92" cy="186" rx="4" ry="2" transform="rotate(30 92 186)" />
              <ellipse cx="72" cy="205" rx="4" ry="2" transform="rotate(-20 72 205)" />
              <ellipse cx="98" cy="214" rx="4" ry="2" transform="rotate(25 98 214)" />
              <ellipse cx="58" cy="218" rx="4" ry="2" transform="rotate(30 58 218)" />
              <ellipse cx="84" cy="164" rx="4" ry="2" transform="rotate(-15 84 164)" />
            </g>
          </g>
        ) : (
          <g>
            <path d="M56 146 H104 L109 227 H51 Z" fill={`url(#${g('sarong')})`} />
            <path d="M56 176 H106 M54 200 H107" stroke="#3d6fa3" strokeWidth="3" opacity="0.7" />
            <path d="M80 150 V226" stroke="#000" strokeOpacity="0.08" strokeWidth="2" />
          </g>
        )}
        {female && <path d="M70 156 L62 228 M84 158 L80 232 M96 156 L100 228" stroke="#000" strokeOpacity="0.1" strokeWidth="2" fill="none" />}
        <ellipse cx="67" cy="229" rx="14" ry="6" fill="#2a1d15" />
        <ellipse cx="93" cy="229" rx="14" ry="6" fill="#2a1d15" />

        {/* cane for the oldest group */}
        {stage === 4 && (
          <g>
            <path d="M40 150 V232" stroke="#8b4a1c" strokeWidth="4.5" strokeLinecap="round" />
            <path d="M40 150 Q40 138 29 140" stroke="#8b4a1c" strokeWidth="4.5" strokeLinecap="round" fill="none" />
          </g>
        )}

        {/* far arm (hangs) */}
        <rect x={38 - broad} y="100" width="16" height="54" rx="8" fill={female ? `url(#${g('skin')})` : `url(#${g('top')})`} />
        <circle cx={46 - broad} cy="158" r="8.5" fill={`url(#${g('skin')})`} />

        {/* torso */}
        <path
          d={female ? 'M54 96 Q80 88 106 96 Q112 118 110 154 Q80 162 50 154 Q48 118 54 96Z' : `M${50 - broad} 98 Q${50 - broad} 90 62 90 H98 Q${110 + broad} 90 ${110 + broad} 98 V152 Q${110 + broad} 162 100 162 H60 Q${50 - broad} 162 ${50 - broad} 152Z`}
          fill={`url(#${g('top')})`}
        />
        {female && <path d="M58 94 L102 152" stroke={FEMALE_SCARF[stage]} strokeWidth="17" strokeLinecap="round" />}
        {female && <circle cx="47" cy="104" r="12.5" fill={`url(#${g('top')})`} />}
        {!female && <path d="M72 91 L80 108 L88 91" fill="none" stroke="#fff" strokeOpacity="0.55" strokeWidth="3" strokeLinejoin="round" />}

        {/* near arm: waves when active */}
        <g className="ch-wave" style={style}>
          <rect x={106 + broad} y="100" width="16" height="52" rx="8" fill={female ? `url(#${g('skin')})` : `url(#${g('top')})`} />
          <circle cx={114 + broad} cy="156" r="8.5" fill={`url(#${g('skin')})`} />
          {female && <circle cx={114 + broad} cy="106" r="12.5" fill={`url(#${g('top')})`} />}
        </g>

        {/* neck + head */}
        <rect x="70" y="84" width="20" height="18" rx="7" fill="#a8704a" />
        <g className="ch-head" style={style}>
          <circle cx="46" cy="62" r="7" fill={`url(#${g('skin')})`} />
          <circle cx="114" cy="62" r="7" fill={`url(#${g('skin')})`} />
          <circle cx="80" cy="58" r="36" fill={`url(#${g('skin')})`} />

          {/* hair */}
          {female ? (
            stage === 4 ? (
              <>
                <circle cx="80" cy="14" r="12" fill={`url(#${g('hair')})`} />
                <path d="M46 52 Q52 20 80 22 Q108 20 114 52 Q100 34 80 36 Q60 34 46 52Z" fill={`url(#${g('hair')})`} />
              </>
            ) : (
              <path d="M46 52 Q52 20 80 22 Q108 20 114 52 Q100 34 80 36 Q60 34 46 52Z" fill={`url(#${g('hair')})`} />
            )
          ) : (
            <path d="M44 56 Q38 14 80 16 Q122 14 116 56 Q110 36 92 34 Q76 40 60 34 Q48 38 44 56Z" fill={`url(#${g('hair')})`} />
          )}
          {stage === 3 && <path d="M60 30 Q80 22 100 30" stroke="#bdbdbd" strokeWidth="4" strokeLinecap="round" fill="none" opacity="0.75" />}
          {female && (
            <g>
              <g transform="translate(55 30)">
                {[0, 72, 144, 216, 288].map((r) => (
                  <ellipse key={r} cx="0" cy="-7" rx="4.6" ry="7.4" fill="#fffdf6" stroke="#e8e1c9" strokeWidth="0.6" transform={`rotate(${r})`} />
                ))}
                <circle r="3" fill="#f5c542" />
              </g>
              <ellipse cx="45" cy="76" rx="3.6" ry="5" fill="#d9a441" />
              <circle cx="45" cy="70" r="1.8" fill="#f2d27a" />
            </g>
          )}

          {/* face */}
          <ellipse cx="60" cy="74" rx="8" ry="5" fill="#e0707a" opacity="0.32" />
          <ellipse cx="100" cy="74" rx="8" ry="5" fill="#e0707a" opacity="0.32" />
          <g>
            <ellipse cx="66" cy="60" rx="8.6" ry="10.6" fill="#fff" />
            <ellipse cx="94" cy="60" rx="8.6" ry="10.6" fill="#fff" />
            <circle cx="67" cy="62" r="6.6" fill={`url(#${g('iris')})`} />
            <circle cx="93" cy="62" r="6.6" fill={`url(#${g('iris')})`} />
            <circle cx="67" cy="62" r="3.3" fill="#120a06" />
            <circle cx="93" cy="62" r="3.3" fill="#120a06" />
            <circle cx="64.6" cy="58.6" r="2.1" fill="#fff" />
            <circle cx="90.6" cy="58.6" r="2.1" fill="#fff" />
            <ellipse className="ch-lid" style={style} cx="66" cy="60" rx="9.4" ry="11.4" fill="#c98f63" />
            <ellipse className="ch-lid" style={style} cx="94" cy="60" rx="9.4" ry="11.4" fill="#c98f63" />
          </g>
          <path d="M56 46 Q66 41 75 46" stroke={hair} strokeWidth="3" strokeLinecap="round" fill="none" />
          <path d="M85 46 Q94 41 104 46" stroke={hair} strokeWidth="3" strokeLinecap="round" fill="none" />
          <path d="M79 66 Q82 74 77 76" stroke="#8a5535" strokeWidth="2.2" strokeLinecap="round" fill="none" />
          {!female && stage >= 1 && <path d="M66 79 Q80 73 94 79 Q80 84 66 79Z" fill={hair} />}
          <path d="M66 82 Q80 98 94 82 Q80 87 66 82Z" fill="#7d2b2b" />
          <path d="M70 83.4 Q80 88 90 83.4 Q80 85.5 70 83.4Z" fill="#fff" />
          {stage >= 3 && (
            <g stroke="#7d4f31" strokeOpacity="0.55" strokeWidth="1.6" fill="none" strokeLinecap="round">
              <path d="M52 62 q-4 2 -5 6" />
              <path d="M108 62 q4 2 5 6" />
              <path d="M62 80 q-3 6 0 12" />
              <path d="M98 80 q3 6 0 12" />
            </g>
          )}
          {stage === 4 && (
            <g stroke="#2a2a2a" strokeWidth="2.4" fill="none">
              <circle cx="66" cy="60" r="12" />
              <circle cx="94" cy="60" r="12" />
              <path d="M78 59 H82" />
            </g>
          )}
          <ellipse cx="62" cy="32" rx="12" ry="5" fill="#fff" opacity="0.2" transform="rotate(-22 62 32)" />
        </g>
      </g>
    </svg>
  )
}

/** Two people of one age group, standing together. */
export function Pair({ stage, height = 170, active = true }) {
  return (
    <div className="ch-pair">
      <Character gender="M" stage={stage} height={height} active={active} />
      <Character gender="F" stage={stage} height={height} active={active} delay={0.3} />
    </div>
  )
}

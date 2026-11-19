import { createContext, useContext, useEffect, useState } from 'react'
import { ResponsiveContainer, Tooltip } from 'recharts'
import { loadDataset, num, scopeName } from './data'

export const PALETTE = ['#256b45', '#5fa47b', '#d9a441', '#8b4a1c', '#3d85a8', '#7a5c9e', '#c0562b', '#8a948e']

/** Loads the dummy dataset once. */
export function useData() {
  const [data, setData] = useState(null)
  const [error, setError] = useState('')
  useEffect(() => {
    loadDataset().then(setData).catch((e) => setError(e.message))
  }, [])
  return { data, error }
}

export function Loading({ error }) {
  return <div className="an-loading">{error ? `Could not load the map data: ${error}` : 'Loading analysis…'}</div>
}


const ICONS = {
  palm: <><path d="M12 21V11" /><path d="M12 11c-1-3-4-4-7-3" /><path d="M12 11c1-3 4-4 7-3" /><path d="M12 11c-3 0-5 2-5 5" /><path d="M12 11c3 0 5 2 5 5" /></>,
  users: <><circle cx="9" cy="8" r="3.2" /><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6" /><path d="M16 5.2a3 3 0 0 1 0 5.6" /><path d="M18 14.3c1.8.8 3 2.5 3 4.7" /></>,
  user: <><circle cx="12" cy="8" r="3.5" /><path d="M5 20c0-3.9 3.1-7 7-7s7 3.1 7 7" /></>,
  flask: <><path d="M9 3h6" /><path d="M10 3v6l-5 9a2 2 0 0 0 1.8 3h10.4A2 2 0 0 0 19 18l-5-9V3" /><path d="M7.5 15h9" /></>,
  tractor: <><circle cx="7" cy="17" r="3.2" /><circle cx="18" cy="17.5" r="2.2" /><path d="M10 17h5.8" /><path d="M3.8 15V9h7.2l2 4h4.6" /><path d="M7 9V5h3" /></>,
  wallet: <><path d="M3 7h15a3 3 0 0 1 3 3v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7z" /><path d="M3 7l11-3v3" /><path d="M17 14h2" /></>,
  calendar: <><rect x="3" y="5" width="18" height="16" rx="3" /><path d="M3 10h18M8 3v4M16 3v4" /></>,
  pin: <><path d="M12 21s7-6.2 7-11a7 7 0 0 0-14 0c0 4.8 7 11 7 11z" /><circle cx="12" cy="10" r="2.5" /></>,
  check: <><circle cx="12" cy="12" r="9" /><path d="M8 12.5l3 3 5-6" /></>,
  truck: <><path d="M2 6h11v10H2z" /><path d="M13 10h4l4 3v3h-8" /><circle cx="6" cy="18" r="1.8" /><circle cx="17" cy="18" r="1.8" /></>,
  trend: <><path d="M3 17l6-6 4 4 8-9" /><path d="M15 6h6v6" /></>,
  receipt: <><path d="M6 3h12v18l-3-2-3 2-3-2-3 2z" /><path d="M9 8h6M9 12h6" /></>,
  trophy: <><path d="M8 4h8v5a4 4 0 0 1-8 0V4z" /><path d="M8 6H4v1a3 3 0 0 0 3 3M16 6h4v1a3 3 0 0 1-3 3M12 13v4M9 20h6" /></>,
  tag: <><path d="M4 4h8l8 8-8 8-8-8z" /><circle cx="8.5" cy="8.5" r="1.2" /></>,
  clock: <><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 2" /></>,
  briefcase: <><rect x="3" y="7" width="18" height="13" rx="2" /><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M3 13h18" /></>,
  scale: <><path d="M12 4v16M5 8h14" /><path d="M5 8l-3 7a3 3 0 0 0 6 0L5 8zM19 8l-3 7a3 3 0 0 0 6 0l-3-7z" /></>,
  gift: <><rect x="3" y="9" width="18" height="4" rx="1" /><path d="M5 13h14v8H5zM12 9v12" /><path d="M12 9S9 9 8.5 7A2 2 0 0 1 12 5.5L12 9zM12 9s3 0 3.5-2A2 2 0 0 0 12 5.5" /></>,
  download: <><path d="M12 4v11M7 11l5 5 5-5M5 20h14" /></>,
  print: <><path d="M7 9V3h10v6M7 17H4v-7h16v7h-3M7 14h10v7H7z" /></>,
}
export function Icon({ name, size = 22 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      {ICONS[name]}
    </svg>
  )
}

/** Soft fades for bars; ids are derived from the colour. */
export const gid = (hex) => `gr-${String(hex).replace('#', '')}`
const darken = (hex, f) => {
  const n = parseInt(String(hex).replace('#', ''), 16)
  const c = (v) => Math.max(0, Math.round(v * f))
  return `rgb(${c((n >> 16) & 255)},${c((n >> 8) & 255)},${c(n & 255)})`
}
export function GradDefs({ colors, horizontal }) {
  const set = [...new Set(colors.filter(Boolean))]
  return (
    <defs>
      {set.map((c) => (
        <linearGradient key={c} id={gid(c)} x1="0" y1="0" x2={horizontal ? '1' : '0'} y2={horizontal ? '0' : '1'}>
          <stop offset="0%" stopColor={c} />
          <stop offset="100%" stopColor={darken(c, 0.62)} />
        </linearGradient>
      ))}
    </defs>
  )
}

const KPI_PHOTO = {
  palm: ['rotary', '50% 40%'], users: ['koku_nagula', '70% 45%'], user: ['slasher', '60% 40%'],
  flask: ['disc_plough', '50% 50%'], tractor: ['backhoe', '50% 50%'], wallet: ['trailer', '50% 50%'],
  calendar: ['hand_tractor', '70% 50%'], pin: ['rotary', '20% 30%'], check: ['backhoe', '30% 50%'],
  truck: ['trailer', '70% 50%'], trend: ['trailer', '30% 60%'], receipt: ['trailer', '50% 30%'],
  trophy: ['koku_nagula', '20% 40%'], tag: ['hand_tractor', '30% 50%'], clock: ['slasher', '30% 50%'],
  briefcase: ['koku_nagula', '85% 60%'], scale: ['disc_plough', '25% 40%'], gift: ['disc_plough', '75% 60%'],
}

const PHOTO_POS = { koku_nagula: '70% 45%', rotary: '50% 45%', hand_tractor: '70% 50%', husking: '50% 40%', copra: '50% 60%', slasher: '60% 45%' }

export function Kpi({ label, value, sub, tone = 'green', icon, onClick, active, photo: picked }) {
  const [photo, pos] = picked ? [picked, PHOTO_POS[picked] || '50% 50%'] : KPI_PHOTO[icon] || KPI_PHOTO.palm
  return (
    <div
      className={`an-kpi ${tone} ${onClick ? 'clickable' : ''} ${active ? 'active' : ''}`}
      onClick={onClick}
      role={onClick ? 'button' : undefined}
      tabIndex={onClick ? 0 : undefined}
      onKeyDown={onClick ? (e) => e.key === 'Enter' && onClick() : undefined}
    >
      <div className="an-kpi-head">
        <div className="an-kpi-top">
          <span className="an-kpi-photo" style={{ backgroundImage: `url(/photos/${photo}.jpg)`, backgroundPosition: pos }} />
          <span className="an-kpi-ic"><Icon name={icon} size={14} /></span>
        </div>
        <h4>{label}</h4>
      </div>
      <b>{value}</b>
      {sub && <em>{sub}</em>}
      {onClick && <span className="an-kpi-more">Details</span>}
    </div>
  )
}

export function Card({ title, sub, right, children, className = '' }) {
  return (
    <section className={`an-card ${className}`}>
      {(title || right) && (
        <header>
          <div>
            <h3>{title}</h3>
            {sub && <p>{sub}</p>}
          </div>
          {right}
        </header>
      )}
      {children}
    </section>
  )
}

export function Chart({ height = 240, children }) {
  return (
    <div style={{ width: '100%', height }}>
      <ResponsiveContainer>{children}</ResponsiveContainer>
    </div>
  )
}

export const tipEl = (fmt = num) => (
  <Tooltip
    formatter={(v) => fmt(v)}
    cursor={{ fill: 'rgba(26,95,56,0.06)' }}
    contentStyle={{ borderRadius: 14, border: 'none', boxShadow: '0 8px 24px rgba(37,107,69,0.16)', fontSize: 12, padding: '8px 12px' }}
  />
)

export function Segmented({ value, onChange, options }) {
  return (
    <div className="an-seg">
      {options.map(([v, text]) => (
        <button key={v} className={value === v ? 'on' : ''} onClick={() => onChange(v)}>
          {text}
        </button>
      ))}
    </div>
  )
}

export function Chips({ value, onChange, options, all = 'All' }) {
  return (
    <div className="an-chips">
      <button className={!value ? 'on' : ''} onClick={() => onChange('')}>{all}</button>
      {options.map((o) => (
        <button key={o} className={value === o ? 'on' : ''} onClick={() => onChange(value === o ? '' : o)}>
          {o}
        </button>
      ))}
    </div>
  )
}

// ---- reports ---------------------------------------------------------------
function csv(sections) {
  const esc = (v) => `"${String(v ?? '').replaceAll('"', '""')}"`
  return sections
    .map((s) => [esc(s.title), s.columns.map(esc).join(','), ...s.rows.map((r) => r.map(esc).join(','))].join('\n'))
    .join('\n\n')
}

export function ReportBar({ name, sel, sections }) {
  const stamp = new Date().toISOString().slice(0, 10)
  const download = () => {
    const head = `"KapConnect - ${name}"\n"Area","${scopeName(sel)}"\n"Generated","${stamp}"\n\n`
    const blob = new Blob(['﻿' + head + csv(sections())], { type: 'text/csv;charset=utf-8' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = `kapconnect-${name.toLowerCase().replaceAll(' ', '-')}-${stamp}.csv`
    a.click()
    URL.revokeObjectURL(a.href)
  }
  return (
    <div className="an-report an-noprint">
      <button className="an-btn ghost" onClick={() => window.print()}><Icon name="print" size={16} /> Print / PDF</button>
      <button className="an-btn solid" onClick={download}><Icon name="download" size={16} /> Download report</button>
    </div>
  )
}

export function PrintHead({ name, sel }) {
  return (
    <div className="an-printhead">
      <h2>KapConnect · {name}</h2>
      <p>
        Area: {scopeName(sel)} · Generated {new Date().toLocaleDateString()}
      </p>
    </div>
  )
}

export const RegionSlot = createContext(null)

export function PageHead({ title, sub, sel, onSel, name, sections, children }) {
  const regionPanel = useContext(RegionSlot)
  return (
    <>
      <PrintHead name={name} sel={sel} />
      <div className="an-head an-noprint-gap">
        <div>
          <h2>{title}</h2>
          <p>
            {sub} · Showing <b>{scopeName(sel)}</b>
            {(sel.province || sel.district) && (
              <button className="an-reset" onClick={() => onSel({})}>
                Reset to Sri Lanka
              </button>
            )}
          </p>
        </div>
        <ReportBar name={name} sel={sel} sections={sections} />
      </div>
      {sel.region && regionPanel}
      {children}
    </>
  )
}

export function DataTable({ columns, rows, limit = 8 }) {
  const [all, setAll] = useState(false)
  const shown = all ? rows : rows.slice(0, limit)
  return (
    <div className="an-table-wrap">
      <table className="an-table">
        <thead>
          <tr>{columns.map((c) => <th key={c}>{c}</th>)}</tr>
        </thead>
        <tbody>
          {shown.map((r, i) => (
            <tr key={i}>{r.map((v, j) => <td key={j}>{v}</td>)}</tr>
          ))}
        </tbody>
      </table>
      {rows.length > limit && (
        <button className="an-more an-noprint" onClick={() => setAll(!all)}>
          {all ? 'Show less' : `Show all ${rows.length}`}
        </button>
      )}
    </div>
  )
}

export function Modal({ title, sub, onClose, children }) {
  useEffect(() => {
    const h = (e) => e.key === 'Escape' && onClose()
    window.addEventListener('keydown', h)
    return () => window.removeEventListener('keydown', h)
  }, [onClose])
  return (
    <div className="an-modal-back" onClick={onClose}>
      <div className="an-modal" onClick={(e) => e.stopPropagation()}>
        <header>
          <div>
            <h3>{title}</h3>
            {sub && <p>{sub}</p>}
          </div>
          <button onClick={onClose} aria-label="Close">✕</button>
        </header>
        <div className="an-modal-body">{children}</div>
      </div>
    </div>
  )
}

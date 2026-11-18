import { useMemo, useState } from 'react'
import { Bars, Donut, Trend } from './AnalysisPages'
import { compact, label, num, pct, sumBy } from './data'
import { Card, Chips, DataTable, Modal, PageHead } from './ui'

// =============================================================================
// Platform pages: Error Correction and Audit Trail.
// There is no audit log or correction queue in the database yet, so these show
// sample records. They are worked out from the real lands, so ids and names match.
// =============================================================================

const hs = (k, salt) => {
  let x = 2166136261
  for (const c of `${k}|${salt}`) x = Math.imul(x ^ c.charCodeAt(0), 16777619)
  x ^= x >>> 15
  x = Math.imul(x, 2246822519)
  return (((x ^ (x >>> 13)) >>> 0) % 100000) / 100000
}
const pickOf = (arr, r) => arr[Math.min(arr.length - 1, Math.floor(r * arr.length))]
const weighted = (items, r) => {
  let a = 0
  for (const [v, w] of items) { a += w; if (r < a) return v }
  return items[items.length - 1][0]
}
const NOW = Date.parse('2026-11-14T18:00:00Z')
const DAY = 86400000
const stamp = (t) => new Date(t).toISOString().slice(0, 16).replace('T', ' ')
const day = (t) => new Date(t).toISOString().slice(0, 10)

const STAFF = ['Nimali Perera', 'Kasun Rajapaksha', 'Dilani Fernando', 'Ruwan Silva', 'Support desk']

// ----------------------------------------------------------------------------- Audit trail
const ACTIONS = [
  ['Login', 0.2], ['Updated', 0.27], ['Created', 0.13], ['Approved', 0.12], ['Corrected', 0.09], ['Rejected', 0.05], ['Exported', 0.09], ['Deleted', 0.05],
]
const ACTION_COLOR = { Login: '#8a948e', Updated: '#3d85a8', Created: '#2f8a4f', Approved: '#43a047', Corrected: '#7a5c9e', Rejected: '#c0562b', Exported: '#d9a441', Deleted: '#c0392b' }
const SENSITIVE = ['Deleted', 'Exported', 'Rejected']
const MODULES = ['User Management', 'Land', 'Marketplace', 'Disputes', 'Product Setup', 'Reports', 'Error Correction']

function auditRows(d) {
  const lands = d.estates
  const out = []
  for (let i = 0; i < 260; i++) {
    const age = Math.floor(Math.pow(hs(i, 'd'), 1.35) * 45)
    const t = NOW - age * DAY - Math.floor(hs(i, 'm') * 9 * 3600000)
    const action = weighted(ACTIONS, hs(i, 'a'))
    const admin = action === 'Login' && hs(i, 'sys') < 0.05 ? 'System' : pickOf(STAFF, hs(i, 'u'))
    const module = action === 'Login' ? 'Platform' : action === 'Exported' ? 'Reports' : action === 'Corrected' ? 'Error Correction' : pickOf(MODULES.filter((m) => m !== 'Reports' && m !== 'Error Correction'), hs(i, 'mo'))
    const land = pickOf(lands, hs(i, 'l'))
    const n = 1000 + Math.floor(hs(i, 'n') * 8000)
    let item = '-'
    let what = ''
    if (action === 'Login') {
      item = admin
      what = admin === 'System' ? 'Nightly data check ran' : `Signed in from 112.134.${Math.floor(hs(i, 'ip') * 250)}.${Math.floor(hs(i, 'ip2') * 250)}`
    } else if (module === 'Land') {
      item = land.id
      what = { Created: `Added the land ${land.name}`, Updated: `Changed the acreage of ${land.name} to ${land.acres} acres`, Approved: `Approved the registration of ${land.name}`, Rejected: `Rejected the registration of ${land.name}`, Deleted: `Removed the duplicate land ${land.name}`, Corrected: `Fixed the district of ${land.name}` }[action]
    } else if (module === 'User Management') {
      item = `U-${n}`
      what = { Created: `Added the CDO officer account U-${n}`, Updated: `Changed the role of U-${n}`, Approved: `Verified the owner ${land.owner}`, Rejected: `Rejected the verification of ${land.owner}`, Deleted: `Suspended the user U-${n}` }[action]
    } else if (module === 'Marketplace') {
      item = `ORD-${n}`
      what = { Created: `Added a manual order ORD-${n}`, Updated: `Changed the price of order ORD-${n}`, Approved: `Approved the deal ORD-${n}`, Rejected: `Rejected the deal ORD-${n}`, Deleted: `Cancelled the order ORD-${n}` }[action]
    } else if (module === 'Disputes') {
      item = `DSP-${n % 900 + 100}`
      what = { Created: `Opened the dispute DSP-${n % 900 + 100} for an owner`, Updated: `Moved the dispute DSP-${n % 900 + 100} to review`, Approved: `Resolved the dispute DSP-${n % 900 + 100} for the buyer`, Rejected: `Closed the dispute DSP-${n % 900 + 100} with no action`, Deleted: `Withdrew the dispute DSP-${n % 900 + 100}` }[action]
    } else if (module === 'Product Setup') {
      const dis = label(land.district)
      item = `${dis} band`
      what = { Created: `Added a price band for ${dis}`, Updated: `Changed the coconut price band for ${dis}`, Approved: `Published the price band for ${dis}`, Rejected: `Declined a price change for ${dis}`, Deleted: `Removed an old price band for ${dis}` }[action]
    } else if (module === 'Error Correction') {
      item = `EC-${100 + (n % 80)}`
      what = `Fixed the record in ticket EC-${100 + (n % 80)}`
    } else if (module === 'Reports') {
      const r = pickOf(['sales', 'owners', 'fertilizer', 'machinery'], hs(i, 'r'))
      item = `${r} report`
      what = `Downloaded the ${r} report`
    }
    out.push({ id: `AUD-${String(i + 1).padStart(4, '0')}`, t, when: stamp(t), admin, action, module, item, what: what || `${action} in ${module}` })
  }
  return out.sort((a, b) => b.t - a.t)
}

export function AuditTrail({ d, sel, setSel }) {
  const all = useMemo(() => auditRows(d), [d])
  const [action, setAction] = useState('')
  const rows = all.filter((r) => !action || r.action === action)
  const last30 = rows.filter((r) => r.t >= NOW - 30 * DAY)
  const perDay = Array.from({ length: 30 }, (_, i) => {
    const t = NOW - (29 - i) * DAY
    return { name: day(t).slice(5), Events: rows.filter((r) => day(r.t) === day(t)).length }
  })
  const byAction = ACTIONS.map(([a]) => ({ name: a, value: all.filter((r) => r.t >= NOW - 30 * DAY && r.action === a).length, color: ACTION_COLOR[a] })).filter((x) => x.value)
  const byModule = [...new Set(rows.map((r) => r.module))].map((m) => ({ name: m, value: rows.filter((r) => r.module === m).length })).sort((a, b) => b.value - a.value)
  const byAdmin = STAFF.map((s) => ({ name: s, value: rows.filter((r) => r.admin === s).length })).sort((a, b) => b.value - a.value)
  const sensitive = rows.filter((r) => SENSITIVE.includes(r.action))
  const table = rows.map((r) => [r.when, r.admin, r.action, r.module, r.item, r.what])
  const sections = () => [{ title: `Audit trail${action ? ' - ' + action : ''}`, columns: ['When', 'Admin', 'Action', 'Module', 'Item', 'What changed'], rows: table }]
  return (
    <PageHead title="Audit trail" sub="Who changed what, and when" name="Audit trail" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-filterbar">
        <span>Action</span>
        <Chips value={action} onChange={setAction} options={ACTIONS.map(([a]) => a)} all="All actions" />
      </div>
      <div className="an-grid2">
        <Card title="Events each day" sub="The last 30 days">
          <Trend data={perDay} keys={['Events']} colors={['#256b45']} area fmt={num} height={230} />
        </Card>
        <Card title="What admins did" sub="Share of the actions, last 30 days">
          <Donut data={byAction} height={210} />
        </Card>
      </div>
      <div className="an-grid2">
        <Card title="By module" sub="Where the changes were made">
          <Bars data={byModule} horizontal single height={Math.max(200, byModule.length * 34)} nameWidth={140} fmt={num} />
        </Card>
        <Card title="By admin" sub="Who made them">
          <Bars data={byAdmin} horizontal single height={200} nameWidth={140} fmt={num} colors={['#3d85a8']} />
        </Card>
      </div>
      <Card title="Every event" sub={`${num(rows.length)} events, newest first. Search or filter, then export.`}>
        <DataTable columns={['When', 'Admin', 'Action', 'Module', 'Item', 'What changed']} rows={table} limit={12} />
      </Card>
    </PageHead>
  )
}

// ----------------------------------------------------------------------------- Error correction
const FIXES = [
  { type: 'Wrong district', module: 'Land', color: '#3d85a8', make: (e, r) => [`${e.name} is registered in ${label(e.district)} but its GPS point is elsewhere`, label(e.district), pickOf(['Kurunegala', 'Puttalam', 'Gampaha', 'Matale'].filter((x) => x !== label(e.district)), r)] },
  { type: 'Duplicate land', module: 'Land', color: '#7a5c9e', make: (e, r, o) => [`${e.name} appears twice (${e.id} and ${o.id})`, `Two records: ${e.id}, ${o.id}`, `One record: ${e.id}`] },
  { type: 'Wrong phone number', module: 'User Management', color: '#c0562b', make: (e, r) => { const a = `07${Math.floor(r * 8)} ${Math.floor(hs(e.id, 'p1') * 900 + 100)} ${Math.floor(hs(e.id, 'p2') * 900 + 100)}`; return [`The phone number of ${e.owner} is one digit short`, a, `${a}${Math.floor(r * 9)}`] } },
  { type: 'Wrong NIC number', module: 'User Management', color: '#d9a441', make: (e, r) => [`The NIC of ${e.owner} does not match the date of birth`, `${1960 + Math.floor(r * 40)}${Math.floor(hs(e.id, 'n') * 900000000 + 100000000)}`, 'Re-entered from the NIC photo'] },
  { type: 'Wrong acreage', module: 'Land', color: '#2f8a4f', make: (e, r) => [`The size of ${e.name} was entered in perches, not acres`, `${e.acres * 160} acres`, `${e.acres} acres`] },
  { type: 'Price typed wrongly', module: 'Marketplace', color: '#e08a1f', make: (e, r) => { const p = 90 + Math.floor(r * 60); return [`A coconut listing of ${e.owner} has a price with an extra zero`, `Rs. ${p * 10}`, `Rs. ${p}`] } },
  { type: 'Machine listed twice', module: 'Machinery', color: '#8e44ad', make: (e, r) => [`A tractor of ${e.owner} was added two times`, '2 listings', '1 listing'] },
]
const REPORTERS = ['Owner, in the app', 'CDO officer', 'Support desk', 'Nightly data check']
const SEVERITY = [['High', 0.2], ['Medium', 0.45], ['Low', 0.35]]
const STATUS = [['Open', 0.36], ['In review', 0.24], ['Fixed', 0.32], ['Rejected', 0.08]]
const STATUS_COLOR = { Open: '#c0562b', 'In review': '#d9a441', Fixed: '#2f8a4f', Rejected: '#8a948e' }

function fixRows(d) {
  const lands = d.estates
  const out = []
  for (let i = 0; i < 46; i++) {
    const e = pickOf(lands, hs(i, 'e'))
    const o = pickOf(lands, hs(i, 'o'))
    const f = pickOf(FIXES, hs(i, 'f'))
    const [problem, wrong, right] = f.make(e, hs(i, 'v'), o)
    const age = Math.floor(Math.pow(hs(i, 'age'), 1.3) * 40)
    const status = weighted(STATUS, hs(i, 's'))
    const fixedIn = status === 'Fixed' || status === 'Rejected' ? Math.min(age, 1 + Math.floor(hs(i, 'fx') * 6)) : null
    out.push({ id: `EC-${100 + i}`, type: f.type, module: f.module, item: f.type === 'Wrong phone number' || f.type === 'Wrong NIC number' ? e.owner : e.id, land: e, problem, wrong, right, reporter: pickOf(REPORTERS, hs(i, 'r')), severity: weighted(SEVERITY, hs(i, 'sv')), age, status, fixedIn, reported: day(NOW - age * DAY) })
  }
  return out.sort((a, b) => a.age - b.age)
}

export function ErrorCorrection({ d, sel, setSel }) {
  const [items, setItems] = useState(() => fixRows(d))
  const [status, setStatus] = useState('')
  const [type, setType] = useState('')
  const [open, setOpen] = useState(null)
  const set = (id, s) => setItems((list) => list.map((x) => (x.id === id ? { ...x, status: s, fixedIn: x.age ? 1 : 0 } : x)))
  const rows = items.filter((x) => (!status || x.status === status) && (!type || x.type === type))
  const count = (s) => items.filter((x) => x.status === s).length
  const done = items.filter((x) => x.status === 'Fixed' && x.fixedIn != null)
  const avg = done.length ? sumBy(done, (x) => x.fixedIn) / done.length : 0
  const byType = FIXES.map((f) => ({ name: f.type, value: rows.filter((x) => x.type === f.type).length, color: f.color })).filter((x) => x.value)
  const byStatus = STATUS.map(([s]) => ({ name: s, value: items.filter((x) => x.status === s && (!type || x.type === type)).length, color: STATUS_COLOR[s] })).filter((x) => x.value)
  const byModule = [...new Set(items.map((x) => x.module))].map((m) => ({ name: m, value: rows.filter((x) => x.module === m).length })).sort((a, b) => b.value - a.value)
  const weekly = Array.from({ length: 8 }, (_, i) => {
    const w = 7 - i
    const inWeek = (x) => x.age >= w * 7 && x.age < w * 7 + 7
    return { name: w === 0 ? 'This week' : `${w}w ago`, Reported: items.filter(inWeek).length, Fixed: items.filter((x) => inWeek(x) && x.status === 'Fixed').length }
  })
  const table = rows.map((x) => [
    <button key={x.id} type="button" className="an-lid" onClick={() => setOpen(x)}>{x.id}</button>,
    x.type, x.item, x.reporter, x.severity, `${x.age} days`, x.status,
    x.status === 'Open' || x.status === 'In review' ? (
      <span key={`a${x.id}`} className="an-fixbtns">
        <button type="button" className="an-fixbtn ok" onClick={() => set(x.id, 'Fixed')}>Fix</button>
        <button type="button" className="an-fixbtn" onClick={() => set(x.id, 'Rejected')}>Reject</button>
      </span>
    ) : '-',
  ])
  const sections = () => [{ title: 'Error correction queue', columns: ['Ticket', 'Type', 'Item', 'Reported by', 'Severity', 'Age', 'Status', 'Problem', 'Wrong value', 'Correct value'], rows: rows.map((x) => [x.id, x.type, x.item, x.reporter, x.severity, `${x.age} days`, x.status, x.problem, x.wrong, x.right]) }]
  return (
    <PageHead title="Error correction" sub="Records people say are wrong, and what was done about them" name="Error correction" sel={sel} onSel={setSel} sections={sections}>
      <div className="an-filterbar">
        <span>Status</span>
        <Chips value={status} onChange={setStatus} options={STATUS.map(([s]) => s)} all="All" />
        <span>Type</span>
        <Chips value={type} onChange={setType} options={FIXES.map((f) => f.type)} all="All types" />
      </div>
      <div className="an-grid2">
        <Card title="What is wrong" sub={`${num(rows.length)} reports${status ? ' · ' + status : ''}`}>
          <Donut data={byType} height={210} />
        </Card>
        <Card title="Reported and fixed each week" sub="The last 8 weeks">
          <Bars data={weekly} keys={['Reported', 'Fixed']} colors={['#c0562b', '#2f8a4f']} height={230} fmt={num} />
        </Card>
      </div>
      <div className="an-grid2">
        <Card title="Where it is wrong" sub="By part of the system">
          <Bars data={byModule} horizontal single height={Math.max(180, byModule.length * 36)} nameWidth={140} fmt={num} />
        </Card>
        <Card title="Where the reports stand" sub="Status of the reports">
          <Donut data={byStatus} height={190} />
        </Card>
      </div>
      <Card title="Correction queue" sub="Click a ticket to see the wrong and the correct value. Use Fix or Reject to close it.">
        <DataTable columns={['Ticket', 'Type', 'Item', 'Reported by', 'Severity', 'Age', 'Status', 'Action']} rows={table} limit={10} />
      </Card>
      {open && (
        <Modal title={`${open.id} · ${open.type}`} sub={`${open.module} · reported ${open.reported} by ${open.reporter}`} onClose={() => setOpen(null)}>
          <div className="an-prof">
            <h4>Problem</h4>
            <div><span>What was reported</span><b>{open.problem}</b></div>
            <div><span>Severity</span><b>{open.severity}</b></div>
            <div><span>Status</span><b>{open.status}</b></div>
            <h4>The fix</h4>
            <div><span>Wrong value</span><b>{open.wrong}</b></div>
            <div><span>Correct value</span><b>{open.right}</b></div>
            <div><span>Land</span><b>{open.land.id} · {open.land.name} · {label(open.land.district)}</b></div>
          </div>
          {(open.status === 'Open' || open.status === 'In review') && (
            <div className="an-fixbtns" style={{ marginTop: 14 }}>
              <button type="button" className="an-fixbtn ok" onClick={() => { set(open.id, 'Fixed'); setOpen(null) }}>Apply the fix</button>
              <button type="button" className="an-fixbtn" onClick={() => { set(open.id, 'Rejected'); setOpen(null) }}>Reject the report</button>
            </div>
          )}
        </Modal>
      )}
    </PageHead>
  )
}

export default function PlatformPage({ view, ...props }) {
  return view === 'soon-audit-trail' ? <AuditTrail {...props} /> : <ErrorCorrection {...props} />
}

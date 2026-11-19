import { useMemo, useState } from 'react'
import { useData } from './ui'

// Every report the system can hand over, grouped like the main menu.
// Each one is a CSV file made from the rows the dashboard already holds.

const flat = (row) => {
  const out = {}
  for (const [k, v] of Object.entries(row || {})) {
    if (v == null || typeof v !== 'object') out[k] = v
    else if (!Array.isArray(v)) for (const [k2, v2] of Object.entries(v)) if (v2 == null || typeof v2 !== 'object') out[`${k} ${k2}`] = v2
  }
  return out
}

const titleCase = (k) => k.replace(/([a-z])([A-Z])/g, '$1 $2').replace(/[_-]/g, ' ').replace(/^./, (c) => c.toUpperCase())

function toCsv(rows) {
  const flatRows = rows.map(flat)
  const cols = [...new Set(flatRows.flatMap((r) => Object.keys(r)))]
  const q = (v) => `"${String(v ?? '').replaceAll('"', '""')}"`
  return [cols.map((c) => q(titleCase(c))), ...flatRows.map((r) => cols.map((c) => q(r[c])))].map((r) => r.join(',')).join(String.fromCharCode(13, 10))
}

function save(name, rows) {
  const a = document.createElement('a')
  a.href = URL.createObjectURL(new Blob([String.fromCharCode(0xfeff) + toCsv(rows)], { type: 'text/csv;charset=utf-8' }))
  a.download = `kapconnect-${name}.csv`
  a.click()
}

const GENDER = ['Male', 'Female']
const AGE = ['18-25', '26-35', '36-45', '46-55', '56+']

export default function ReportsCatalog({ backend, exportJson, refresh }) {
  const { data: d } = useData()
  const [q, setQ] = useState('')
  const [done, setDone] = useState('')

  const list = useMemo(() => {
    const est = d?.estates || []
    return [
      { g: 'Land', id: 'registered-lands', title: 'Registered lands', desc: 'Every registered land: owner, district, CDO area, acres, palms, crop, plan and registration date', rows: est.map(({ ownerAge, ownerGender, price, volume, ...e }) => e) },
      { g: 'Land', id: 'land-prices-volumes', title: 'Coconut prices and volumes by land', desc: 'Price per nut and nuts per month at the order, deal and transaction steps, for each coconut land', rows: est.filter((e) => e.price).map((e) => ({ id: e.id, land: e.name, district: e.district, 'cdo area': e.region, 'order price': e.price.orders, 'deal price': e.price.deal, 'transaction price': e.price.transactions, 'order nuts': e.volume.orders, 'deal nuts': e.volume.deal, 'transaction nuts': e.volume.transactions })) },
      { g: 'Community', id: 'land-owners', title: 'Land owners by age and gender', desc: 'Each owner with gender, age group, land and district', rows: est.map((e) => ({ owner: e.owner, gender: GENDER[e.ownerGender], 'age group': AGE[e.ownerAge], land: e.name, district: e.district, 'cdo area': e.region, acres: e.acres })) },
      { g: 'Community', id: 'day-workers', title: 'Day workers by district', desc: 'Workers by district and job category, with their age and gender mix', rows: d?.workers || [] },
      { g: 'Community', id: 'machines', title: 'Machinery and suppliers', desc: 'Machines on the platform: type, owner, district and price', rows: d?.machines || [] },
      { g: 'Community', id: 'machine-bookings', title: 'Machine bookings', desc: 'Every machinery booking and its status', rows: d?.bookings || [] },
      { g: 'Resources', id: 'fertilizer-sold', title: 'Fertilizer sold by month and district', desc: 'Kilograms sold, allocated and the farmers reached, by fertilizer type', rows: d?.fert || [] },
      { g: 'Resources', id: 'fertilizer-received', title: 'Fertilizer received from donors', desc: 'What donors gave each month, by fertilizer type', rows: d?.donated || [] },
      { g: 'Subsidies', id: 'subsidy-funders', title: 'Subsidy funders and donations', desc: 'Every funder with its date, subsidy type, amount, distributed and left to distribute', rows: (d?.donations || []).map(({ id, donor, type, date, kg, delivered, usd, lkr, scheme }) => ({ id, funder: donor, type: scheme || type, date, allocated: kg, distributed: delivered, 'yet to distribute': kg - delivered, usd, lkr })) },
      { g: 'Marketplace', id: 'deals', title: 'Deals', desc: 'Offers being negotiated, with category, quantity, unit price and status', rows: backend.deals || [] },
      { g: 'Marketplace', id: 'buy-requests', title: 'Buy requests', desc: 'Every buy request and its bid price', rows: backend.requests || [] },
      { g: 'Marketplace', id: 'sell-listings', title: 'Sell listings', desc: 'Every sell listing and its offer price', rows: backend.listings || [] },
      { g: 'Marketplace', id: 'transactions', title: 'Transactions', desc: 'Completed payments', rows: backend.transactions || [] },
      { g: 'Marketplace', id: 'disputes', title: 'Disputes', desc: 'Open and resolved disputes with severity', rows: backend.disputes || [] },
      { g: 'Marketplace', id: 'sales', title: 'Sales by month', desc: 'Revenue and orders by product, district and month', rows: d?.sales || [] },
      { g: 'Platform', id: 'users', title: 'Users', desc: 'All users with role, status and verification', rows: backend.users || [] },
      { g: 'Platform', id: 'regions-price-bands', title: 'Regions and price bands', desc: 'The price band set for each region', rows: backend.regions || [] },
      { g: 'Platform', id: 'summary', title: 'Platform summary', desc: 'Average deal price, orders, open disputes and verified estates', rows: [backend.reports || {}] },
    ]
  }, [d, backend])

  const shown = list.filter((r) => !q.trim() || `${r.g} ${r.title} ${r.desc}`.toLowerCase().includes(q.trim().toLowerCase()))
  const groups = [...new Set(shown.map((r) => r.g))]

  const get = (r) => {
    save(r.id, r.rows)
    setDone(r.id)
    setTimeout(() => setDone(''), 1800)
  }

  return (
    <>
      <div className="adm-card">
        <div className="adm-card-h">
          <h2>Reports you can download</h2>
          <span className="adm-count">{list.length}</span>
        </div>
        <p className="adm-muted" style={{ margin: '0 0 12px' }}>
          Each report downloads as a CSV file that opens in Excel. Every page also has its own Download report button for the view you are looking at.
        </p>
        <div className="adm-tools">
          <input className="adm-search" placeholder="Search reports" value={q} onChange={(e) => setQ(e.target.value)} />
          <button className="adm-btn green" onClick={exportJson}>Download everything (JSON)</button>
          <button className="adm-btn outline" onClick={refresh}>Refresh data</button>
        </div>
      </div>
      {groups.map((g) => (
        <div key={g} className="adm-card rc-group">
          <div className="adm-card-h"><h2>{g}</h2></div>
          <div className="rc-grid">
            {shown.filter((r) => r.g === g).map((r) => (
              <div key={r.id} className="rc-item">
                <b>{r.title}</b>
                <p>{r.desc}</p>
                <div className="rc-foot">
                  <span>{r.rows.length.toLocaleString('en-US')} rows · CSV</span>
                  <button className="adm-btn green" disabled={!r.rows.length} onClick={() => get(r)}>{done === r.id ? 'Downloaded' : 'Download'}</button>
                </div>
              </div>
            ))}
          </div>
        </div>
      ))}
      {!groups.length && <div className="adm-card"><p className="adm-muted">No reports match your search.</p></div>}
    </>
  )
}

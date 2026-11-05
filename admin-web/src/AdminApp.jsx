import { useCallback, useEffect, useMemo, useState } from 'react'
import { api } from './api'
import './AdminApp.css'

const money = (value) => `Rs. ${Number(value || 0).toLocaleString()}`
const shortDate = (value) => (value ? new Date(value).toLocaleDateString() : '—')
const pill = (status) => <span className={`adm-pill ${String(status || '').toLowerCase()}`}>{String(status || '').replaceAll('_', ' ')}</span>

const NAV = [
  { section: 'Overview', items: [['dashboard', 'Dashboard']] },
  { section: 'People', items: [['users', 'Users'], ['verify', 'Verification']] },
  {
    section: 'Marketplace',
    items: [
      ['orders', 'Orders'],
      ['deal', 'Deal'],
      ['transactions', 'Transactions'],
      ['disputes', 'Disputes'],
    ],
  },
  {
    section: 'System',
    items: [
      ['regions', 'Regions & prices'],
      ['reports', 'Reports'],
      ['settings', 'Settings'],
    ],
  },
]

const TITLES = {
  dashboard: 'Dashboard',
  users: 'Users',
  verify: 'Verification queue',
  orders: 'Orders',
  deal: 'Deal',
  transactions: 'Transactions',
  disputes: 'Disputes',
  regions: 'Regions & prices',
  reports: 'Reports',
  settings: 'Settings',
}

const DEAL_STATUSES = ['NEGOTIATING', 'ACCEPTED', 'PAYMENT_PENDING']
const TXN_STATUSES = ['COMPLETED']
const DISPUTE_LEVELS = ['low', 'medium', 'high']

const disputeLevelLabel = (level) => {
  const s = String(level || 'medium').toLowerCase()
  return s.charAt(0).toUpperCase() + s.slice(1)
}

const disputeLevelTagClass = (level) => {
  const s = String(level || 'medium').toLowerCase()
  if (s === 'high') return 'danger'
  if (s === 'low') return 'ok'
  return 'warn'
}

/** Pin positions as % on the real Sri Lanka map image */
/* Pin % match city dots on /sri-lanka-map.png (your photo map). */
const MAP_CITIES = [
  { name: 'Jaffna', left: 48, top: 8, band: 'Rs. 100 – 125' },
  { name: 'Kilinochchi', left: 48, top: 15, band: 'Rs. 100 – 125' },
  { name: 'Anuradhapura', left: 45, top: 30, band: 'Rs. 108 – 130' },
  { name: 'Trincomalee', left: 64, top: 33, band: 'Rs. 110 – 132' },
  { name: 'Puttalam', left: 30, top: 38, band: 'Rs. 105 – 130' },
  { name: 'Kurunegala', left: 40, top: 46, band: 'Rs. 110 – 135' },
  { name: 'Batticaloa', left: 70, top: 50, band: 'Rs. 108 – 130' },
  { name: 'Kandy', left: 52, top: 54, band: 'Rs. 115 – 138' },
  { name: 'Gampaha', left: 34, top: 58, band: 'Rs. 115 – 140' },
  { name: 'Badulla', left: 58, top: 60, band: 'Rs. 112 – 135' },
  { name: 'Colombo', left: 32, top: 64, band: 'Rs. 120 – 145', capital: true },
  { name: 'Ratnapura', left: 44, top: 70, band: 'Rs. 112 – 136' },
  { name: 'Galle', left: 38, top: 84, band: 'Rs. 118 – 142' },
  { name: 'Matara', left: 48, top: 90, band: 'Rs. 115 – 140' },
]

export default function AdminApp({ user, logout }) {
  const [view, setView] = useState('dashboard')
  const [search, setSearch] = useState('')
  const [userFilter, setUserFilter] = useState('all')
  const [dealFilter, setDealFilter] = useState('ALL')
  const [selectedRegion, setSelectedRegion] = useState(null)
  const [bandDraft, setBandDraft] = useState('')
  const [issueForm, setIssueForm] = useState(null)
  const [toast, setToast] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [selectedOrder, setSelectedOrder] = useState(null)
  const [orderDetail, setOrderDetail] = useState(null)
  const [data, setData] = useState({
    dashboard: {},
    users: [],
    deals: [],
    transactions: [],
    listings: [],
    requests: [],
    disputes: [],
    regions: [],
    reports: {},
    settings: { fee: 2.5, radius: 3, language: 'en', paymentHold: 4, support: 'support@cococonnect.lk' },
  })

  const showToast = (msg) => {
    setToast(msg)
    setTimeout(() => setToast(''), 2200)
  }

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [dashboard, users, deals, transactions, listings, requests, disputes, regions, reports, settings] =
        await Promise.all([
          api('/admin/dashboard'),
          api('/admin/users'),
          api('/admin/deals'),
          api('/admin/transactions'),
          api('/admin/listings'),
          api('/admin/buy-requests'),
          api('/admin/disputes'),
          api('/admin/regions'),
          api('/admin/reports'),
          api('/admin/settings'),
        ])
      setData({
        dashboard,
        users,
        deals,
        transactions,
        listings,
        requests,
        disputes,
        regions,
        reports,
        settings,
      })
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
    const timer = setInterval(load, 15000)
    return () => clearInterval(timer)
  }, [load])

  useEffect(() => {
    if (!selectedOrder) {
      setOrderDetail(null)
      return
    }
    api(`/admin/deals/${selectedOrder.id}`)
      .then(setOrderDetail)
      .catch((err) => setError(err.message))
  }, [selectedOrder])

  useEffect(() => {
    if (!selectedRegion) {
      setBandDraft('')
      return
    }
    const live = data.regions.find((r) => r.name === selectedRegion)
    const mapDefault = MAP_CITIES.find((c) => c.name === selectedRegion)?.band
    setBandDraft(live?.band || mapDefault || '')
  }, [selectedRegion, data.regions])

  const q = search.trim().toLowerCase()
  const users = useMemo(() => {
    let rows = data.users
    if (userFilter === 'buyer') rows = rows.filter((u) => u.role === 'BUYER')
    if (userFilter === 'estate') rows = rows.filter((u) => u.role === 'ESTATE')
    if (userFilter === 'suspended') rows = rows.filter((u) => u.status === 'SUSPENDED')
    if (q) {
      rows = rows.filter(
        (u) =>
          u.name.toLowerCase().includes(q) ||
          u.phone.includes(q) ||
          (u.district || '').toLowerCase().includes(q) ||
          (u.estateName || '').toLowerCase().includes(q)
      )
    }
    return rows
  }, [data.users, userFilter, q])

  const pendingUsers = data.users.filter((u) => u.status === 'PENDING')
  const openDisputes = data.disputes.filter((d) => d.status === 'OPEN')

  const dealRows = useMemo(() => {
    let rows = data.deals.filter((o) => DEAL_STATUSES.includes(o.status) || o.status === 'DISPUTED')
    if (dealFilter !== 'ALL') rows = rows.filter((o) => o.status === dealFilter)
    if (q) rows = rows.filter((o) => o.code.toLowerCase().includes(q) || (o.category || '').toLowerCase().includes(q))
    return rows
  }, [data.deals, dealFilter, q])

  const transactionRows = useMemo(() => {
    let rows = data.transactions
    if (q) rows = rows.filter((o) => o.code.toLowerCase().includes(q) || (o.category || '').toLowerCase().includes(q))
    return rows
  }, [data.transactions, q])

  const requestRows = useMemo(() => {
    let rows = data.requests
    if (q) rows = rows.filter((r) => r.district?.toLowerCase().includes(q) || r.location?.toLowerCase().includes(q) || r.category?.toLowerCase().includes(q))
    return rows
  }, [data.requests, q])

  const listingRows = useMemo(() => {
    let rows = data.listings
    if (q) rows = rows.filter((l) => l.district?.toLowerCase().includes(q) || l.location?.toLowerCase().includes(q) || l.category?.toLowerCase().includes(q))
    return rows
  }, [data.listings, q])

  async function setUserStatus(id, status) {
    await api(`/admin/users/${id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) })
    await load()
    showToast(`User marked ${status}`)
  }

  async function hideItem(kind, id) {
    if (!window.confirm(`Hide this ${kind}?`)) return
    await api(`/admin/${kind}/${id}/hide`, { method: 'PATCH' })
    await load()
    showToast('Hidden from marketplace')
  }

  async function toggleListingVerify(listing) {
    await api(`/admin/listings/${listing.id}/verify`, {
      method: 'PATCH',
      body: JSON.stringify({ verified: !listing.verified }),
    })
    await load()
    showToast(listing.verified ? 'Verification removed' : 'Listing verified')
  }

  async function resolveDispute(id, action) {
    await api(`/admin/disputes/${id}/resolve`, { method: 'PATCH', body: JSON.stringify({ action }) })
    await load()
    showToast('Dispute resolved')
  }

  async function setDisputeSeverity(id, severity) {
    await api(`/admin/disputes/${id}/severity`, { method: 'PATCH', body: JSON.stringify({ severity }) })
    await load()
    showToast(`Level set to ${disputeLevelLabel(severity)}`)
  }

  function openIssueForm(order) {
    setIssueForm({
      order,
      title: `Issue on ${order.code}`,
      body: 'Admin flagged this deal for review.',
      severity: 'medium',
    })
  }

  async function submitIssueForm(event) {
    event.preventDefault()
    if (!issueForm?.order) return
    await api(`/admin/deals/${issueForm.order.id}/disputes`, {
      method: 'POST',
      body: JSON.stringify({
        title: issueForm.title.trim(),
        body: issueForm.body.trim(),
        severity: issueForm.severity,
      }),
    })
    setIssueForm(null)
    await load()
    setView('disputes')
    showToast('Dispute created')
  }

  async function publishRegionBand(name, band) {
    const trimmed = band.trim()
    if (!trimmed) {
      showToast('Enter a price band first')
      return
    }
    await api('/admin/regions/band', { method: 'PUT', body: JSON.stringify({ name, band: trimmed }) })
    await load()
    showToast(`Published ${name} band`)
  }

  async function saveSettings(event) {
    event.preventDefault()
    const form = new FormData(event.target)
    const body = {
      fee: Number(form.get('fee')),
      radius: Number(form.get('radius')),
      language: form.get('language'),
      paymentHold: Number(form.get('paymentHold')),
      support: form.get('support'),
    }
    await api('/admin/settings', { method: 'PUT', body: JSON.stringify(body) })
    await load()
    showToast('Settings saved')
  }

  function exportJson() {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' })
    const a = document.createElement('a')
    a.href = URL.createObjectURL(blob)
    a.download = 'cococonnect-admin-export.json'
    a.click()
    showToast('JSON downloaded')
  }

  let content = null
  if (loading && !data.users.length) {
    content = <div className="adm-empty">Loading admin console…</div>
  } else if (view === 'dashboard') {
    const d = data.dashboard
    content = (
      <>
        <div className="adm-stats">
          <div className="adm-stat"><div className="k">Users</div><div className="v">{d.users || 0}</div><div className="d">{d.pendingVerify || 0} pending verify</div></div>
          <div className="adm-stat"><div className="k">Open requests</div><div className="v">{d.openBuyRequests || 0}</div><div className="d">active demand</div></div>
          <div className="adm-stat"><div className="k">Active listings</div><div className="v">{d.activeListings || 0}</div><div className="d">live supply</div></div>
          <div className="adm-stat"><div className="k">Completed GMV</div><div className="v">{money(d.completedGmv)}</div><div className="d">{d.dealsInProgress || 0} deals in progress</div></div>
        </div>
        <div className="adm-grid-2">
          <div className="adm-card">
            <div className="adm-card-h"><h2>Alerts</h2></div>
            {openDisputes.length === 0 && pendingUsers.length === 0 && <div className="adm-empty">No alerts right now</div>}
            {openDisputes.map((item) => (
              <div className="adm-alert" key={item.id}>
                <span className="adm-tag danger">Dispute</span>
                <div><b>{item.title}</b><p>{item.body}</p></div>
                <button className="adm-btn green" onClick={() => setView('disputes')}>Open</button>
              </div>
            ))}
            {pendingUsers.length > 0 && (
              <div className="adm-alert">
                <span className="adm-tag warn">Verify</span>
                <div><b>{pendingUsers.length} awaiting verification</b><p>Approve applicants to show Verified status in the app</p></div>
                <button className="adm-btn green" onClick={() => setView('verify')}>Open queue</button>
              </div>
            )}
          </div>
          <div className="adm-card">
            <div className="adm-card-h"><h2>Recent deals</h2><button className="adm-link" onClick={() => setView('deal')}>View all</button></div>
            <table className="adm-table">
              <thead><tr><th>Code</th><th>Qty</th><th>Price</th><th>Status</th></tr></thead>
              <tbody>
                {(d.recentOrders || []).filter((o) => !TXN_STATUSES.includes(o.status)).slice(0, 5).map((o) => (
                  <tr key={o.id}><td>{o.code}</td><td>{o.quantity}</td><td>{money(o.unitPrice)}</td><td>{pill(o.status)}</td></tr>
                ))}
                {!(d.recentOrders || []).filter((o) => !TXN_STATUSES.includes(o.status)).length && <tr><td colSpan="4" className="adm-empty">No active deals</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      </>
    )
  } else if (view === 'users') {
    content = (
      <div className="adm-card">
        <div className="adm-toolbar">
          {['all', 'buyer', 'estate', 'suspended'].map((f) => (
            <button key={f} className={`adm-chip ${userFilter === f ? 'active' : ''}`} onClick={() => setUserFilter(f)}>{f}</button>
          ))}
        </div>
        <table className="adm-table">
          <thead><tr><th>User</th><th>Phone</th><th>Role</th><th>District</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.id}>
                <td><div className="adm-user-cell"><span className={`adm-av ${u.role === 'ESTATE' ? 't' : 'b'}`}>{u.name.slice(0, 1)}</span><div><b>{u.name}</b><small>{u.estateName || u.role}</small></div></div></td>
                <td>{u.phone}</td><td>{u.role}</td><td>{u.district || '—'}</td><td>{pill(u.status)}</td>
                <td className="adm-actions">
                  {u.status !== 'VERIFIED' && <button className="adm-btn green" onClick={() => setUserStatus(u.id, 'VERIFIED')}>Verify</button>}
                  {u.status === 'SUSPENDED' ? <button className="adm-btn green" onClick={() => setUserStatus(u.id, 'VERIFIED')}>Restore</button> : <button className="adm-btn red" onClick={() => setUserStatus(u.id, 'SUSPENDED')}>Suspend</button>}
                </td>
              </tr>
            ))}
            {!users.length && <tr><td colSpan="6" className="adm-empty">No users match</td></tr>}
          </tbody>
        </table>
      </div>
    )
  } else if (view === 'verify') {
    content = (
      <div className="adm-card">
        <p className="adm-muted" style={{ marginBottom: 14 }}>Approve documents → Verified badge appears in the mobile app.</p>
        <table className="adm-table">
          <thead><tr><th>Applicant</th><th>Phone</th><th>Role</th><th>District</th><th>Action</th></tr></thead>
          <tbody>
            {pendingUsers.map((u) => (
              <tr key={u.id}>
                <td><b>{u.name}</b><div className="adm-muted">{u.estateName || '—'}</div></td>
                <td>{u.phone}</td><td>{u.role}</td><td>{u.district || '—'}</td>
                <td className="adm-actions">
                  <button className="adm-btn green" onClick={() => setUserStatus(u.id, 'VERIFIED')}>Approve</button>
                  <button className="adm-btn red" onClick={() => setUserStatus(u.id, 'SUSPENDED')}>Reject</button>
                </td>
              </tr>
            ))}
            {!pendingUsers.length && <tr><td colSpan="5" className="adm-empty">Verification queue empty</td></tr>}
          </tbody>
        </table>
      </div>
    )
  } else if (view === 'orders') {
    content = (
      <>
        <p className="adm-muted" style={{ marginBottom: 14 }}>
          Marketplace posts side by side. Buy requests and sell listings live here before negotiation starts.
        </p>
        <div className="adm-orders-split">
          <div className="adm-card">
            <div className="adm-card-h"><h2>Buy requests</h2><span className="adm-count">{requestRows.length}</span></div>
            <table className="adm-table">
              <thead><tr><th>Category</th><th>Qty</th><th>Bid</th><th>District</th><th>Status</th><th></th></tr></thead>
              <tbody>
                {requestRows.map((r) => (
                  <tr key={r.id}>
                    <td>{r.category}</td>
                    <td>{r.quantity?.toLocaleString()}</td>
                    <td>{money(r.bidPrice)}</td>
                    <td>{r.district || '—'}</td>
                    <td>{pill(r.status)}</td>
                    <td>{r.status !== 'HIDDEN' && <button className="adm-btn red" onClick={() => hideItem('buy-requests', r.id)}>Hide</button>}</td>
                  </tr>
                ))}
                {!requestRows.length && <tr><td colSpan="6" className="adm-empty">No buy requests</td></tr>}
              </tbody>
            </table>
          </div>
          <div className="adm-card">
            <div className="adm-card-h"><h2>Sell listings</h2><span className="adm-count">{listingRows.length}</span></div>
            <table className="adm-table">
              <thead><tr><th>Category</th><th>Qty</th><th>Offer</th><th>District</th><th>Status</th><th>Actions</th></tr></thead>
              <tbody>
                {listingRows.map((l) => (
                  <tr key={l.id}>
                    <td>{l.category}{l.verified ? <span className="adm-inline-ok"> Verified</span> : ''}</td>
                    <td>{l.quantity?.toLocaleString()}</td>
                    <td>{money(l.offerPrice)}</td>
                    <td>{l.district || '—'}</td>
                    <td>{pill(l.status)}</td>
                    <td className="adm-actions">
                      <button className={`adm-btn ${l.verified ? 'outline' : 'green'}`} onClick={() => toggleListingVerify(l)}>{l.verified ? 'Unverify' : 'Verify'}</button>
                      {l.status !== 'HIDDEN' && <button className="adm-btn red" onClick={() => hideItem('listings', l.id)}>Hide</button>}
                    </td>
                  </tr>
                ))}
                {!listingRows.length && <tr><td colSpan="6" className="adm-empty">No sell listings</td></tr>}
              </tbody>
            </table>
          </div>
        </div>
      </>
    )
  } else if (view === 'deal') {
    const senderLabel = (m) => {
      if (m.senderName) {
        if (m.senderRole === 'BUYER') return `Buyer · ${m.senderName}`
        if (m.senderRole === 'ESTATE_OWNER') return `Estate · ${m.senderName}`
        return m.senderName
      }
      return 'User'
    }
    content = (
      <>
        <p className="adm-muted" style={{ marginBottom: 14 }}>
          Active negotiations only. Chat and price offers happen here after a seller accepts a request or a buyer opens a listing.
        </p>
        <div className="adm-tip">
          <strong>Tip:</strong> click <b>Open chat</b> on any deal to read the buyer and estate negotiation trail.
        </div>
        <div className="adm-toolbar">
          {['ALL', 'NEGOTIATING', 'ACCEPTED', 'PAYMENT_PENDING', 'DISPUTED'].map((f) => (
            <button key={f} className={`adm-chip ${dealFilter === f ? 'active' : ''}`} onClick={() => setDealFilter(f)}>{f.replaceAll('_', ' ')}</button>
          ))}
        </div>
        <div className="adm-card">
          <table className="adm-table">
            <thead><tr><th>Deal</th><th>Category</th><th>Qty</th><th>Unit price</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {dealRows.map((o) => (
                <tr key={o.id} className={selectedOrder?.id === o.id ? 'adm-row-on' : ''}>
                  <td><b>{o.code}</b><div className="adm-muted">{shortDate(o.createdAt)}</div></td>
                  <td>{o.category}</td>
                  <td>{o.quantity?.toLocaleString()}</td>
                  <td>{money(o.unitPrice)}</td>
                  <td>{pill(o.status)}</td>
                  <td className="adm-actions">
                    <button className="adm-btn outline" onClick={() => setSelectedOrder(o)}>Open chat</button>
                    {o.status !== 'DISPUTED' && (
                      <button className="adm-btn amber" onClick={() => openIssueForm(o)}>Report issue</button>
                    )}
                  </td>
                </tr>
              ))}
              {!dealRows.length && <tr><td colSpan="6" className="adm-empty">No active deals</td></tr>}
            </tbody>
          </table>
        </div>
        {selectedOrder && (
          <div className="adm-card adm-chat-card" style={{ marginTop: 16 }}>
            <div className="adm-card-h">
              <h2>Deal chat · {selectedOrder.code}</h2>
              <button className="adm-link" onClick={() => { setSelectedOrder(null); setOrderDetail(null) }}>Close</button>
            </div>
            <div className="adm-kv">
              <span>Status</span><b>{selectedOrder.status.replaceAll('_', ' ')}</b>
              <span>Quantity</span><b>{selectedOrder.quantity?.toLocaleString()} nuts</b>
              <span>Unit price</span><b>{money(selectedOrder.unitPrice)}</b>
              <span>Category</span><b>{selectedOrder.category}</b>
            </div>
            <p className="adm-muted" style={{ margin: '8px 0 12px' }}>
              This is the same chat the buyer and estate see while they negotiate.
            </p>
            <div className="adm-chat">
              {!orderDetail ? (
                <div className="adm-empty">Loading messages…</div>
              ) : orderDetail.messages?.length ? (
                orderDetail.messages.map((m) => {
                  const fromBuyer = m.senderRole === 'BUYER'
                  return (
                    <div
                      key={m.id}
                      className={`adm-chat-line ${fromBuyer ? 'from-buyer' : 'from-estate'} ${m.type === 'OFFER' ? 'is-offer' : ''}`}
                    >
                      <div className="who">
                        {senderLabel(m)}
                        {m.type === 'OFFER' ? ' · Price offer' : ''}
                        <span className="when">{shortDate(m.createdAt)}</span>
                      </div>
                      {m.type === 'OFFER' ? (
                        <div className="offer-bubble">Offers <b>{money(m.offerPrice)}</b> per nut</div>
                      ) : (
                        <div className="text-bubble">{m.text}</div>
                      )}
                    </div>
                  )
                })
              ) : (
                <div className="adm-empty">No messages yet</div>
              )}
            </div>
          </div>
        )}
        {issueForm && (
          <form className="adm-card adm-issue-form" style={{ marginTop: 16 }} onSubmit={submitIssueForm}>
            <div className="adm-card-h">
              <h2>Report issue · {issueForm.order.code}</h2>
              <button type="button" className="adm-link" onClick={() => setIssueForm(null)}>Cancel</button>
            </div>
            <label>Title<input value={issueForm.title} onChange={(e) => setIssueForm({ ...issueForm, title: e.target.value })} required /></label>
            <label>Details<textarea rows={3} value={issueForm.body} onChange={(e) => setIssueForm({ ...issueForm, body: e.target.value })} required /></label>
            <label>Level
              <select value={issueForm.severity} onChange={(e) => setIssueForm({ ...issueForm, severity: e.target.value })}>
                {DISPUTE_LEVELS.map((level) => (
                  <option key={level} value={level}>{disputeLevelLabel(level)}</option>
                ))}
              </select>
            </label>
            <button type="submit" className="adm-btn amber">Create dispute</button>
          </form>
        )}
      </>
    )
  } else if (view === 'transactions') {
    content = (
      <>
        <p className="adm-muted" style={{ marginBottom: 14 }}>
          Completed deals only — after both sides finish negotiation and mark the deal done.
        </p>
        <div className="adm-card">
          <table className="adm-table">
            <thead><tr><th>Transaction</th><th>Category</th><th>Qty</th><th>Unit price</th><th>Total</th><th>Completed</th></tr></thead>
            <tbody>
              {transactionRows.map((o) => (
                <tr key={o.id}>
                  <td><b>{o.code}</b></td>
                  <td>{o.category}</td>
                  <td>{o.quantity?.toLocaleString()}</td>
                  <td>{money(o.unitPrice)}</td>
                  <td><b>{money(o.total ?? o.quantity * o.unitPrice)}</b></td>
                  <td>{pill(o.status)} <span className="adm-muted">{shortDate(o.updatedAt || o.createdAt)}</span></td>
                </tr>
              ))}
              {!transactionRows.length && <tr><td colSpan="6" className="adm-empty">No completed transactions yet</td></tr>}
            </tbody>
          </table>
        </div>
      </>
    )
  } else if (view === 'disputes') {
    content = (
      <>
        <p className="adm-muted" style={{ marginBottom: 14 }}>
          Deal problems only — for example agreed Rs. 900 but delivered 800. Set level to Low, Medium, or High.
        </p>
        <div className="adm-card">
          {data.disputes.length ? data.disputes.map((d) => (
            <div className="adm-alert" key={d.id}>
              <span className={`adm-tag ${disputeLevelTagClass(d.severity)}`}>{disputeLevelLabel(d.severity)}</span>
              <div style={{ flex: 1 }}>
                <b>{d.title} · Deal CR-{d.orderId} {pill(d.status)}</b>
                <p>{d.body}</p>
                {d.status === 'OPEN' && (
                  <>
                    <label className="adm-severity-row">
                      Level
                      <select
                        value={String(d.severity || 'medium').toLowerCase()}
                        onChange={(e) => setDisputeSeverity(d.id, e.target.value)}
                      >
                        {DISPUTE_LEVELS.map((level) => (
                          <option key={level} value={level}>{disputeLevelLabel(level)}</option>
                        ))}
                      </select>
                    </label>
                    <div className="adm-actions" style={{ marginTop: 10 }}>
                      <button className="adm-btn green" onClick={() => resolveDispute(d.id, 'refund')}>Resolve · refund</button>
                      <button className="adm-btn amber" onClick={() => resolveDispute(d.id, 'warn')}>Warn parties</button>
                      <button className="adm-btn outline" onClick={() => resolveDispute(d.id, 'close')}>Close</button>
                    </div>
                  </>
                )}
              </div>
              <span className={`adm-pill ${disputeLevelTagClass(d.severity)}`}>{disputeLevelLabel(d.severity)}</span>
            </div>
          )) : <div className="adm-empty">No deal disputes reported</div>}
        </div>
      </>
    )
  } else if (view === 'regions') {
    const byName = Object.fromEntries((data.regions || []).map((r) => [r.name, r]))
    const regions = MAP_CITIES.map((city) => {
      const live = byName[city.name]
      return {
        name: city.name,
        left: city.left,
        top: city.top,
        capital: city.capital,
        band: live?.band || city.band,
        buyers: live?.buyers ?? 0,
        estates: live?.estates ?? 0,
        radius: live?.radius ?? 3,
      }
    })
    // include any live API districts not already on the map list
    ;(data.regions || []).forEach((r) => {
      if (!regions.some((x) => x.name === r.name)) {
        regions.push({ name: r.name, left: 50, top: 50, band: r.band, buyers: r.buyers, estates: r.estates, radius: r.radius, capital: false })
      }
    })
    const active = selectedRegion
      ? regions.find((r) => r.name === selectedRegion) || null
      : null
    content = (
      <div className="adm-map-layout">
        <div className="adm-card adm-map-card">
          <div className="adm-card-h">
            <h2>Sri Lanka · regions &amp; prices</h2>
            <span className="adm-muted">Click a pin on the map</span>
          </div>
          <div className="adm-map-wrap">
            <div className="adm-map-stage">
              <img src="/sri-lanka-map.png" alt="Sri Lanka map" className="adm-map-img" />
              {regions.filter((r) => r.left != null).map((r) => (
                <button
                  type="button"
                  key={r.name}
                  className={`adm-map-pin ${selectedRegion === r.name ? 'on' : ''} ${r.capital ? 'capital' : ''}`}
                  style={{ left: `${r.left}%`, top: `${r.top}%` }}
                  onClick={() => setSelectedRegion(r.name)}
                  title={r.name}
                  aria-label={`Open prices for ${r.name}`}
                >
                  <span className="adm-map-pin-dot" />
                  <span className="adm-map-pin-name">{r.name}</span>
                </button>
              ))}
            </div>
            {active && (
              <aside className="adm-price-popup">
                <div className="adm-price-popup-h">
                  <div>
                    <small>Selected district</small>
                    <strong>{active.name}</strong>
                  </div>
                  <button type="button" className="adm-link" onClick={() => setSelectedRegion(null)}>Close</button>
                </div>
                <label className="adm-band-edit">
                  Price band
                  <input
                    type="text"
                    value={bandDraft}
                    onChange={(e) => setBandDraft(e.target.value)}
                    placeholder="e.g. Rs. 110 – 135"
                  />
                </label>
                <p className="adm-muted">Edit the suggested coconut price for this region</p>
                <div className="adm-price-stats">
                  <div><small>Buyers</small><b>{active.buyers ?? 0}</b></div>
                  <div><small>Estates</small><b>{active.estates ?? 0}</b></div>
                  <div><small>Radius</small><b>{active.radius ?? 3} km</b></div>
                </div>
                <button
                  type="button"
                  className="adm-btn green"
                  style={{ width: '100%', marginTop: 12 }}
                  onClick={() => publishRegionBand(active.name, bandDraft)}
                >
                  Publish this band
                </button>
              </aside>
            )}
            {!active && (
              <aside className="adm-price-popup soft">
                <small>Tip</small>
                <strong>Select a city pin</strong>
                <p className="adm-muted" style={{ marginTop: 8 }}>Click Colombo, Kurunegala, Galle, or any marked city to see the price band.</p>
              </aside>
            )}
          </div>
        </div>
        <div className="adm-card">
          <div className="adm-card-h"><h2>All district bands</h2></div>
          {regions.map((r) => (
            <button
              type="button"
              key={r.name}
              className={`adm-price-band-btn ${selectedRegion === r.name ? 'on' : ''}`}
              onClick={() => setSelectedRegion(r.name)}
            >
              <strong>{r.name}</strong>
              <span>{selectedRegion === r.name ? bandDraft : r.band}</span>
            </button>
          ))}
        </div>
      </div>
    )
  } else if (view === 'reports') {
    const r = data.reports
    content = (
      <>
        <div className="adm-stats">
          <div className="adm-stat"><div className="k">Avg deal price</div><div className="v">{money(r.avgDealPrice)}</div><div className="d">from completed deals</div></div>
          <div className="adm-stat"><div className="k">Total orders</div><div className="v">{r.totalOrders || 0}</div><div className="d">{r.completedOrders || 0} completed</div></div>
          <div className="adm-stat"><div className="k">Open disputes</div><div className="v">{r.openDisputes || 0}</div><div className="d">needs attention</div></div>
          <div className="adm-stat"><div className="k">Verified estates</div><div className="v">{r.verifiedEstates || 0}/{r.totalEstates || 0}</div><div className="d">verification queue</div></div>
        </div>
        <div className="adm-card">
          <div className="adm-card-h"><h2>Export</h2></div>
          <div className="adm-actions">
            <button className="adm-btn green" onClick={exportJson}>Download admin JSON</button>
            <button className="adm-btn outline" onClick={load}>Refresh data</button>
          </div>
        </div>
      </>
    )
  } else if (view === 'settings') {
    const s = data.settings
    content = (
      <form className="adm-card" onSubmit={saveSettings}>
        <div className="adm-card-h"><h2>Platform settings</h2></div>
        <div className="adm-form-grid">
          <label>Platform fee (%)<input name="fee" type="number" step="0.1" defaultValue={s.fee} required /></label>
          <label>Default search radius (km)<input name="radius" type="number" defaultValue={s.radius} required /></label>
          <label>Default language
            <select name="language" defaultValue={s.language}>
              <option value="en">English</option>
              <option value="si">Sinhala</option>
              <option value="ta">Tamil</option>
            </select>
          </label>
          <label>Payment hold (hours)<input name="paymentHold" type="number" defaultValue={s.paymentHold} required /></label>
        </div>
        <label className="adm-full">Support contact<input name="support" defaultValue={s.support} required /></label>
        <button className="adm-btn green" style={{ marginTop: 14 }}>Save settings</button>
      </form>
    )
  }

  return (
    <div className="adm-shell">
      <aside className="adm-sidebar">
        <div className="adm-brand">
          <strong>CocoConnect</strong>
          <small>Administration</small>
        </div>
        <nav className="adm-nav">
          {NAV.map((group) => (
            <div key={group.section}>
              <div className="adm-sec">{group.section}</div>
              {group.items.map(([id, label]) => (
                <button key={id} className={`adm-link ${view === id ? 'active' : ''}`} onClick={() => setView(id)}>
                  {label}
                  {id === 'verify' && pendingUsers.length > 0 && <span className="adm-badge">{pendingUsers.length}</span>}
                  {id === 'deal' && dealRows.length > 0 && <span className="adm-badge">{dealRows.length}</span>}
                  {id === 'disputes' && openDisputes.length > 0 && <span className="adm-badge">{openDisputes.length}</span>}
                </button>
              ))}
            </div>
          ))}
        </nav>
        <div className="adm-foot">
          <div className="adm-avatar">{user.name.slice(0, 1)}</div>
          <div><b>{user.name}</b><small>Administrator</small></div>
          <button type="button" className="adm-signout" onClick={logout}>Sign out</button>
        </div>
      </aside>
      <div className="adm-main">
        <header className="adm-topbar">
          <div>
            <h1>{TITLES[view]}</h1>
            <p className="adm-top-sub">Synced {new Date().toLocaleTimeString()}</p>
          </div>
          <div className="adm-top-actions">
            <input className="adm-search" placeholder="Search…" value={search} onChange={(e) => setSearch(e.target.value)} />
            <button className="adm-btn outline" onClick={load}>Refresh</button>
          </div>
        </header>
        <div className="adm-content">
          {error && <div className="adm-error">{error}<button onClick={() => setError('')}>Close</button></div>}
          {content}
        </div>
      </div>
      {toast && <div className="adm-toast">{toast}</div>}
    </div>
  )
}

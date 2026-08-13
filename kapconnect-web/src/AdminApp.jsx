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
      ['requests', 'Buy requests'],
      ['listings', 'Sell listings'],
      ['orders', 'Orders'],
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
  requests: 'Buy requests',
  listings: 'Sell listings',
  orders: 'Orders & transactions',
  disputes: 'Disputes & flags',
  regions: 'Regions & prices',
  reports: 'Reports',
  settings: 'Settings',
}

export default function AdminApp({ user, logout }) {
  const [view, setView] = useState('dashboard')
  const [search, setSearch] = useState('')
  const [userFilter, setUserFilter] = useState('all')
  const [orderFilter, setOrderFilter] = useState('ALL')
  const [toast, setToast] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)
  const [selectedOrder, setSelectedOrder] = useState(null)
  const [orderDetail, setOrderDetail] = useState(null)
  const [data, setData] = useState({
    dashboard: {},
    users: [],
    orders: [],
    listings: [],
    requests: [],
    disputes: [],
    regions: [],
    reports: {},
    settings: { fee: 2.5, radius: 3, language: 'en', paymentHold: 4, support: 'support@kapconnect.lk' },
  })

  const showToast = (msg) => {
    setToast(msg)
    setTimeout(() => setToast(''), 2200)
  }

  const load = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const [dashboard, users, orders, listings, requests, disputes, regions, reports, settings] =
        await Promise.all([
          api('/admin/dashboard'),
          api('/admin/users'),
          api('/admin/orders'),
          api('/admin/listings'),
          api('/admin/buy-requests'),
          api('/admin/disputes'),
          api('/admin/regions'),
          api('/admin/reports'),
          api('/admin/settings'),
        ])
      setData({ dashboard, users, orders, listings, requests, disputes, regions, reports, settings })
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
    api(`/orders/${selectedOrder.id}`)
      .then(setOrderDetail)
      .catch((err) => setError(err.message))
  }, [selectedOrder])

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
  const orders = useMemo(() => {
    let rows = data.orders
    if (orderFilter !== 'ALL') rows = rows.filter((o) => o.status === orderFilter)
    if (q) rows = rows.filter((o) => o.code.toLowerCase().includes(q) || o.category.toLowerCase().includes(q))
    return rows
  }, [data.orders, orderFilter, q])

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

  async function createDispute(order) {
    const title = window.prompt('Dispute title', `Issue on ${order.code}`)
    if (!title) return
    const body = window.prompt('Describe the issue', 'Admin flagged this order for review.')
    if (!body) return
    await api(`/admin/orders/${order.id}/disputes`, {
      method: 'POST',
      body: JSON.stringify({ title, body, severity: 'medium' }),
    })
    await load()
    setView('disputes')
    showToast('Dispute created')
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
    a.download = 'kapconnect-admin-export.json'
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
            <div className="adm-card-h"><h2>Recent orders</h2><button className="adm-link" onClick={() => setView('orders')}>View all</button></div>
            <table className="adm-table">
              <thead><tr><th>Code</th><th>Qty</th><th>Price</th><th>Status</th></tr></thead>
              <tbody>
                {(d.recentOrders || []).map((o) => (
                  <tr key={o.id}><td>{o.code}</td><td>{o.quantity}</td><td>{money(o.unitPrice)}</td><td>{pill(o.status)}</td></tr>
                ))}
                {!d.recentOrders?.length && <tr><td colSpan="4" className="adm-empty">No orders yet</td></tr>}
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
  } else if (view === 'requests') {
    const rows = data.requests.filter((r) => !q || r.district?.toLowerCase().includes(q) || r.location?.toLowerCase().includes(q))
    content = (
      <div className="adm-card">
        <table className="adm-table">
          <thead><tr><th>Category</th><th>Qty</th><th>Bid</th><th>Need date</th><th>District</th><th>Status</th><th></th></tr></thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id}>
                <td>{r.category}</td><td>{r.quantity?.toLocaleString()}</td><td>{money(r.bidPrice)}</td><td>{shortDate(r.needDate)}</td><td>{r.district || '—'}</td><td>{pill(r.status)}</td>
                <td>{r.status !== 'HIDDEN' && <button className="adm-btn red" onClick={() => hideItem('buy-requests', r.id)}>Hide</button>}</td>
              </tr>
            ))}
            {!rows.length && <tr><td colSpan="7" className="adm-empty">No buy requests</td></tr>}
          </tbody>
        </table>
      </div>
    )
  } else if (view === 'listings') {
    const rows = data.listings.filter((l) => !q || l.district?.toLowerCase().includes(q) || l.location?.toLowerCase().includes(q))
    content = (
      <div className="adm-card">
        <table className="adm-table">
          <thead><tr><th>Category</th><th>Qty</th><th>Offer</th><th>Available</th><th>District</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {rows.map((l) => (
              <tr key={l.id}>
                <td>{l.category}{l.verified ? <span className="adm-inline-ok"> Verified</span> : ''}</td><td>{l.quantity?.toLocaleString()}</td><td>{money(l.offerPrice)}</td><td>{shortDate(l.availableAt)}</td><td>{l.district || '—'}</td><td>{pill(l.status)}</td>
                <td className="adm-actions">
                  <button className={`adm-btn ${l.verified ? 'outline' : 'green'}`} onClick={() => toggleListingVerify(l)}>{l.verified ? 'Unverify' : 'Verify'}</button>
                  {l.status !== 'HIDDEN' && <button className="adm-btn red" onClick={() => hideItem('listings', l.id)}>Hide</button>}
                </td>
              </tr>
            ))}
            {!rows.length && <tr><td colSpan="7" className="adm-empty">No sell listings</td></tr>}
          </tbody>
        </table>
      </div>
    )
  } else if (view === 'orders') {
    content = (
      <>
        <div className="adm-toolbar">
          {['ALL', 'NEGOTIATING', 'ACCEPTED', 'PAYMENT_PENDING', 'COMPLETED', 'DISPUTED', 'REJECTED'].map((f) => (
            <button key={f} className={`adm-chip ${orderFilter === f ? 'active' : ''}`} onClick={() => setOrderFilter(f)}>{f.replaceAll('_', ' ')}</button>
          ))}
        </div>
        <div className="adm-card">
          <table className="adm-table">
            <thead><tr><th>Order</th><th>Category</th><th>Qty</th><th>Unit price</th><th>Status</th><th>Actions</th></tr></thead>
            <tbody>
              {orders.map((o) => (
                <tr key={o.id}>
                  <td><b>{o.code}</b><div className="adm-muted">{shortDate(o.createdAt)}</div></td>
                  <td>{o.category}</td><td>{o.quantity?.toLocaleString()}</td><td>{money(o.unitPrice)}</td><td>{pill(o.status)}</td>
                  <td className="adm-actions">
                    <button className="adm-btn outline" onClick={() => setSelectedOrder(o)}>Open</button>
                    <button className="adm-btn amber" onClick={() => createDispute(o)}>Open dispute</button>
                  </td>
                </tr>
              ))}
              {!orders.length && <tr><td colSpan="6" className="adm-empty">No orders</td></tr>}
            </tbody>
          </table>
        </div>
        {selectedOrder && (
          <div className="adm-card" style={{ marginTop: 16 }}>
            <div className="adm-card-h">
              <h2>Order {selectedOrder.code}</h2>
              <button className="adm-link" onClick={() => setSelectedOrder(null)}>Close</button>
            </div>
            <div className="adm-kv">
              <span>Status</span><b>{selectedOrder.status}</b>
              <span>Quantity</span><b>{selectedOrder.quantity}</b>
              <span>Unit price</span><b>{money(selectedOrder.unitPrice)}</b>
              <span>Category</span><b>{selectedOrder.category}</b>
            </div>
            <div className="adm-chat">
              {!orderDetail ? 'Loading messages…' : orderDetail.messages?.length ? orderDetail.messages.map((m) => (
                <div className="adm-chat-line" key={m.id}>
                  <div className="who">{m.type === 'OFFER' ? 'Offer' : 'Message'}</div>
                  <div>{m.type === 'OFFER' ? money(m.offerPrice) : m.text}</div>
                </div>
              )) : <div className="adm-empty">No messages</div>}
            </div>
          </div>
        )}
      </>
    )
  } else if (view === 'disputes') {
    content = (
      <div className="adm-card">
        {data.disputes.length ? data.disputes.map((d) => (
          <div className="adm-alert" key={d.id}>
            <span className={`adm-tag ${d.severity === 'high' ? 'danger' : 'warn'}`}>{d.severity === 'high' ? 'High' : 'Medium'}</span>
            <div style={{ flex: 1 }}>
              <b>{d.title} · {d.orderId.slice(0, 8)} {pill(d.status)}</b>
              <p>{d.body}</p>
              {d.status === 'OPEN' && (
                <div className="adm-actions" style={{ marginTop: 10 }}>
                  <button className="adm-btn green" onClick={() => resolveDispute(d.id, 'refund')}>Resolve · refund</button>
                  <button className="adm-btn amber" onClick={() => resolveDispute(d.id, 'warn')}>Warn parties</button>
                  <button className="adm-btn outline" onClick={() => resolveDispute(d.id, 'close')}>Close</button>
                </div>
              )}
            </div>
            <span className={`adm-pill ${d.severity === 'high' ? 'disputed' : 'pending'}`}>{d.severity}</span>
          </div>
        )) : <div className="adm-empty">No disputes</div>}
      </div>
    )
  } else if (view === 'regions') {
    content = (
      <div className="adm-grid-2">
        <div className="adm-card">
          <div className="adm-card-h"><h2>Active districts</h2></div>
          <table className="adm-table">
            <thead><tr><th>District</th><th>Buyers</th><th>Estates</th><th>Radius</th></tr></thead>
            <tbody>
              {data.regions.map((r) => (
                <tr key={r.name}><td>{r.name}</td><td>{r.buyers}</td><td>{r.estates}</td><td>{r.radius} km</td></tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="adm-card">
          <div className="adm-card-h"><h2>Suggested price bands</h2></div>
          {data.regions.map((r) => (
            <div className="adm-price-band" key={r.name}><strong>{r.name}</strong><span>{r.band}</span></div>
          ))}
          <button className="adm-btn green" style={{ marginTop: 12 }} onClick={() => showToast('Bands published to app (demo)')}>Publish bands</button>
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
          <strong>KapConnect</strong>
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

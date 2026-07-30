import { useCallback, useEffect, useState } from 'react'
import { api, authApi } from './api'
import './App.css'

const demos = [
  { role: 'Buyer', phone: '0771234567', icon: '🛒' },
  { role: 'Estate', phone: '0715550199', icon: '🌴' },
  { role: 'Admin', phone: '0700000000', icon: '🛡️' },
]

const money = (value) => `Rs. ${Number(value || 0).toLocaleString()}`
const shortDate = (value) => value ? new Date(value).toLocaleDateString() : '—'

function Login({ onLogin }) {
  const [phone, setPhone] = useState('0771234567')
  const [code, setCode] = useState('123456')
  const [step, setStep] = useState('phone')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  async function requestOtp(event) {
    event.preventDefault()
    setBusy(true)
    setError('')
    try {
      await authApi.sendOtp(phone)
      setStep('code')
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  async function verify(event, demoPhone) {
    event?.preventDefault()
    const selectedPhone = demoPhone || phone
    setBusy(true)
    setError('')
    try {
      const result = await authApi.verifyOtp(selectedPhone, '123456')
      onLogin(result)
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <main className="login-page">
      <section className="login-hero">
        <div className="brand brand-large"><span>🌴</span> KapConnect</div>
        <p className="eyebrow">Sri Lanka's coconut marketplace</p>
        <h1>Buy and sell coconuts with confidence.</h1>
        <p className="hero-copy">Connect buyers and estate owners, negotiate prices, and manage every deal in one simple place.</p>
        <div className="hero-points">
          <span>✓ Verified users</span><span>✓ Direct negotiation</span><span>✓ Simple order tracking</span>
        </div>
      </section>

      <section className="login-panel">
        <div className="login-card">
          <h2>Welcome back</h2>
          <p>Use your phone number to continue.</p>
          <form onSubmit={step === 'phone' ? requestOtp : verify}>
            <label>Phone number</label>
            <input value={phone} onChange={(e) => setPhone(e.target.value)} disabled={step === 'code'} />
            {step === 'code' && (
              <>
                <label>OTP code</label>
                <input value={code} onChange={(e) => setCode(e.target.value)} />
                <small>For this demo, the code is 123456.</small>
              </>
            )}
            {error && <div className="alert error">{error}</div>}
            <button className="primary full" disabled={busy}>
              {busy ? 'Please wait…' : step === 'phone' ? 'Send OTP' : 'Sign in'}
            </button>
          </form>
          <div className="divider"><span>quick demo login</span></div>
          <div className="demo-grid">
            {demos.map((demo) => (
              <button key={demo.role} className="demo-button" disabled={busy} onClick={() => verify(null, demo.phone)}>
                <span>{demo.icon}</span><b>{demo.role}</b><small>{demo.phone}</small>
              </button>
            ))}
          </div>
        </div>
      </section>
    </main>
  )
}

function Sidebar({ user, tab, setTab, logout }) {
  const roleTabs = [['overview', '▦', 'Overview'], ['users', '👥', 'Users'], ['orders', '📦', 'All orders']]

  return (
    <aside className="sidebar">
      <div className="brand"><span>🌴</span> KapConnect</div>
      <nav>
        {roleTabs.map(([id, icon, label]) => (
          <button key={id} className={tab === id ? 'active' : ''} onClick={() => setTab(id)}>
            <span>{icon}</span>{label}
          </button>
        ))}
      </nav>
      <div className="profile">
        <div className="avatar">{user.name.slice(0, 1)}</div>
        <div><b>{user.name}</b><small>{user.role}</small></div>
        <button className="logout" onClick={logout} title="Sign out">↪</button>
      </div>
    </aside>
  )
}

function MobileHeader({ user, logout, back, title }) {
  return (
    <header className="mobile-header">
      <button className="header-icon" onClick={back || undefined}>{back ? '←' : '☰'}</button>
      <strong>{title || 'KapConnect'}</strong>
      {title ? <span className="header-spacer" /> : (
        <button className="header-avatar" onClick={logout} title="Sign out">{user.name.slice(0, 1)}</button>
      )}
    </header>
  )
}

function MobileNav({ tab, setTab }) {
  const tabs = [['market', '▦', 'Dashboard'], ['orders', '▤', 'Orders'], ['profile', '♙', 'Profile']]
  return (
    <nav className="mobile-nav">
      {tabs.map(([id, icon, label]) => (
        <button key={id} className={tab === id ? 'active' : ''} onClick={() => setTab(id)}>
          <span>{icon}</span><small>{label}</small>
        </button>
      ))}
    </nav>
  )
}

function Header({ title, subtitle, action }) {
  return (
    <header className="page-header">
      <div><h1>{title}</h1><p>{subtitle}</p></div>
      {action}
    </header>
  )
}

function Empty({ text }) {
  return <div className="empty"><span>🌱</span><h3>Nothing here yet</h3><p>{text}</p></div>
}

function BuyerRequestForm({ saved }) {
  const [form, setForm] = useState({ quantity: '1200', price: '110', date: '', location: 'Kurunegala', district: 'Kurunegala' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const field = (name) => ({ value: form[name], onChange: (e) => setForm({ ...form, [name]: e.target.value }) })

  async function submit(event) {
    event.preventDefault()
    setBusy(true)
    setError('')
    try {
      await api('/buy-requests', {
        method: 'POST',
        body: JSON.stringify({
          category: 'RAW',
          quantity: Number(form.quantity),
          bidPrice: Number(form.price),
          needDate: form.date,
          location: form.location,
          district: form.district,
        }),
      })
      saved()
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <form className="client-form-card" onSubmit={submit}>
      <div className="client-form-title"><span>＋</span><h2>Request Raw<br />Coconuts</h2></div>
      <label>Number of Nuts Required<input type="number" min="1" required {...field('quantity')} /></label>
      <label>Required Date<input type="date" required {...field('date')} /></label>
      <label>Bidding Price (Rs. per nut)<input type="number" min="1" required {...field('price')} /></label>
      {error && <div className="alert error">{error}</div>}
      <button className="client-primary full" disabled={busy}>{busy ? 'Submitting…' : 'Submit Request  →'}</button>
      <small className="form-note">Your request will be visible to estate owners within your region.</small>
    </form>
  )
}

function EstateListingRow({ item, onNegotiate }) {
  return (
    <article className="client-listing-card">
      <div className="client-person">
        <span className="client-avatar">E</span>
        <div><b>Verified Estate</b><small>{item.location || item.district || 'Sri Lanka'}</small></div>
        <strong>{money(item.offerPrice)}</strong>
      </div>
      <p className="trust-line">✓ Verified offer price</p>
      <div className="client-card-stats">
        <span><small>QUANTITY</small><b>{item.quantity?.toLocaleString()} nuts</b></span>
        <span><small>AVAILABLE</small><b>{shortDate(item.availableAt)}</b></span>
      </div>
      <button className="card-arrow" onClick={() => onNegotiate(item)}>→</button>
    </article>
  )
}

function BuyerRequestRow({ item, onNegotiate }) {
  return (
    <article className="client-listing-card">
      <div className="client-person">
        <span className="client-avatar buyer">B</span>
        <div><b>Local Buyer</b><small>Trust score: 4.8/5</small></div>
        <strong>{money(item.bidPrice)}</strong>
      </div>
      <div className="client-card-stats">
        <span><small>QUANTITY</small><b>{item.quantity?.toLocaleString()} nuts</b></span>
        <span><small>REQUIRED DATE</small><b>{shortDate(item.needDate)}</b></span>
      </div>
      <button className="card-arrow" onClick={() => onNegotiate(item)}>→</button>
    </article>
  )
}

function BuyerMarketplace({ listings, onNegotiate, saved }) {
  return (
    <>
      <section className="mobile-title">
        <h1>Marketplace</h1>
        <p>Connect with local estate owners and secure your raw coconut supply with transparent pricing.</p>
      </section>
      <BuyerRequestForm saved={saved} />
      <section className="mobile-section">
        <div className="section-heading"><div><h2>Nearby Estate Owner Listings</h2><p>⌖ Within your region</p></div><button className="filter-pill">☷ Filter</button></div>
        <div className="chip-row"><button className="active">Best Price</button><button>Earliest Pickup</button><button>Nearest</button></div>
        <div className="mobile-card-list">
          {listings.length ? listings.map((item) => <EstateListingRow key={item.id} item={item} onNegotiate={onNegotiate} />) : <Empty text="Estate listings will appear here." />}
        </div>
      </section>
    </>
  )
}

const estateTiles = [
  ['coconut', '🌴', 'Coconuts', 'List harvest'],
  ['soon', '🍃', 'Fertilizer', 'Quality nutrients'],
  ['soon', '🧺', 'Vegetables', 'Fresh produce'],
  ['soon', '🚜', 'Machinery', 'Rent or buy'],
  ['soon', '🐾', 'Livestock', 'Animal products'],
  ['soon', '👥', 'Labour', 'Hire workers'],
  ['soon', '📦', 'Other Goods', 'Farm goods'],
  ['soon', '△', 'Miscellaneous', 'Other services'],
]

function EstateDashboard({ openCoconuts }) {
  return (
    <>
      <section className="mobile-title compact">
        <p>Estate owner dashboard</p>
        <span className="title-underline" />
      </section>
      <div className="estate-columns"><div><h2>Selling<br />Categories</h2><p>List products</p></div><div><h2>Provider<br />Services</h2><p>Essential resources</p></div></div>
      <div className="estate-grid">
        {estateTiles.map(([id, icon, title, copy]) => (
          <button key={title} onClick={id === 'coconut' ? openCoconuts : undefined}>
            <span>{icon}</span><b>{title}</b><small>{copy}</small>
          </button>
        ))}
      </div>
    </>
  )
}

function CategoryPicker({ choose, back }) {
  const categories = [
    ['RAW', '🌴', 'Raw Coconuts', 'Fresh harvest coconuts'],
    ['DEHUSKED', '🥥', 'Dehusked Coconuts', 'Ready for processing'],
    ['HUSKS', '🧺', 'Coconut Husks', 'Bulk coconut husks'],
  ]
  return (
    <section className="category-screen">
      <button className="text-back" onClick={back}>← Back</button>
      <h1>Choose Coconut Category</h1>
      <p>Select the type of coconut product you are looking to list.</p>
      <div className="category-stack">{categories.map(([id, icon, title, copy]) => (
        <button key={id} onClick={() => choose(id)}>
          <span>{icon}</span><div><b>→ {title}</b><small>{copy}</small></div>
        </button>
      ))}</div>
    </section>
  )
}

function EstateSellScreen({ category, requests, onNegotiate, openForm, back }) {
  return (
    <>
      <button className="text-back" onClick={back}>← Categories</button>
      <section className="mobile-title compact"><h1>Sell {category === 'RAW' ? 'Raw Coconuts' : category === 'DEHUSKED' ? 'Dehusked Coconuts' : 'Coconut Husks'}</h1><p>Manage your coconut sales and view nearby demand.</p></section>
      <button className="sell-action-card" onClick={openForm}><span>🛒</span><div><b>Create Sale Listing</b><small>Add quantity, date and your price</small></div><strong>＋</strong></button>
      <section className="mobile-section">
        <div className="section-heading"><div><h2>Interested Buyers</h2><p>⌖ Within your region</p></div><button className="filter-pill">☷ Filter</button></div>
        <div className="chip-row"><button className="active">Best Price</button><button>Earliest Pickup</button><button>Nearest</button></div>
        <div className="mobile-card-list">{requests.length ? requests.map((item) => <BuyerRequestRow key={item.id} item={item} onNegotiate={onNegotiate} />) : <Empty text="Buyer requests will appear here." />}</div>
      </section>
    </>
  )
}

function MobileOrders({ orders, openOrder }) {
  const [filter, setFilter] = useState('ALL')
  const visible = filter === 'ALL' ? orders : orders.filter((order) => order.status === filter)
  return (
    <>
      <section className="mobile-title compact"><h1>My Requests</h1><p>Track every negotiation and completed coconut order.</p></section>
      <div className="order-tabs"><button className={filter === 'NEGOTIATING' ? 'active' : ''} onClick={() => setFilter('NEGOTIATING')}>Pending</button><button className={filter === 'ACCEPTED' ? 'active' : ''} onClick={() => setFilter('ACCEPTED')}>Accepted</button><button className={filter === 'COMPLETED' ? 'active' : ''} onClick={() => setFilter('COMPLETED')}>Completed</button><button className={filter === 'ALL' ? 'active' : ''} onClick={() => setFilter('ALL')}>All</button></div>
      <div className="mobile-order-list">{visible.length ? visible.map((order) => (
        <article className="mobile-order-card" key={order.id}>
          <div className="order-code"><span>REQUEST #{order.code}</span><span className={`status ${order.status.toLowerCase()}`}>{order.status.replaceAll('_', ' ')}</span></div>
          <h2>{order.category.replaceAll('_', ' ')} Coconut</h2>
          <p>♙ Marketplace partner</p>
          <div className="order-value"><span><small>QUANTITY</small><b>{order.quantity?.toLocaleString()} <em>nuts</em></b></span><span><small>PRICE</small><b>{money(order.unitPrice)}<em>/nut</em></b></span></div>
          <button className="client-primary full" onClick={() => openOrder(order)}>{order.status === 'ACCEPTED' ? 'Complete Order' : 'Open Negotiation'} →</button>
        </article>
      )) : <Empty text="No orders match this tab yet." />}</div>
    </>
  )
}

function ProfileScreen({ user, logout }) {
  return (
    <section className="profile-screen">
      <div className="profile-hero"><span>{user.name.slice(0, 1)}</span><h1>{user.name}</h1><p>{user.role === 'ESTATE' ? user.estateName || 'Estate Owner' : 'Verified Buyer'}</p></div>
      <div className="profile-details"><p><span>Phone</span><b>{user.phone}</b></p><p><span>District</span><b>{user.district || 'Not set'}</b></p><p><span>Trust score</span><b>{user.trustScore || '—'} / 5</b></p><p><span>Status</span><b>{user.status}</b></p></div>
      <button className="danger-outline full" onClick={logout}>Sign out</button>
    </section>
  )
}

function ListingCard({ item, user, onNegotiate, onHide }) {
  return (
    <article className="market-card">
      <div className="card-top">
        <span className="category">{item.category}</span>
        <span className={`status ${item.status?.toLowerCase()}`}>{item.status}</span>
      </div>
      <div className="coconut">🌴</div>
      <h3>{item.quantity?.toLocaleString()} coconuts</h3>
      <div className="price">{money(item.offerPrice)} <small>each</small></div>
      <dl>
        <div><dt>📍 Location</dt><dd>{item.location || item.district || 'Not given'}</dd></div>
        <div><dt>📅 Available</dt><dd>{shortDate(item.availableAt)}</dd></div>
      </dl>
      {user.role === 'BUYER' && <button className="primary full" onClick={() => onNegotiate(item)}>Start negotiation</button>}
      {user.role === 'ADMIN' && <button className="danger-outline full" onClick={() => onHide(item)}>Hide listing</button>}
    </article>
  )
}

function RequestCard({ item, user, onNegotiate, onHide }) {
  return (
    <article className="request-card">
      <div className="card-top">
        <span className="category">{item.category}</span>
        <span className={`status ${item.status?.toLowerCase()}`}>{item.status}</span>
      </div>
      <h3>Buyer needs {item.quantity?.toLocaleString()} coconuts</h3>
      <div className="price">{money(item.bidPrice)} <small>bid per coconut</small></div>
      <div className="request-meta"><span>📍 {item.location || item.district}</span><span>📅 Needed {shortDate(item.needDate)}</span></div>
      {user.role === 'ESTATE' && <button className="primary" onClick={() => onNegotiate(item)}>Send an offer</button>}
      {user.role === 'ADMIN' && <button className="danger-outline" onClick={() => onHide(item)}>Hide request</button>}
    </article>
  )
}

function CreateForm({ type, initialCategory = 'RAW', close, saved }) {
  const isListing = type === 'listing'
  const [form, setForm] = useState({
    category: initialCategory, quantity: '', price: '', date: '',
    location: '', district: 'Kurunegala',
  })
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)

  function field(name) {
    return { value: form[name], onChange: (e) => setForm({ ...form, [name]: e.target.value }) }
  }

  async function submit(event) {
    event.preventDefault()
    setBusy(true)
    setError('')
    const body = {
      category: form.category,
      quantity: Number(form.quantity),
      [isListing ? 'offerPrice' : 'bidPrice']: Number(form.price),
      [isListing ? 'availableAt' : 'needDate']: form.date,
      location: form.location,
      district: form.district,
    }
    try {
      await api(isListing ? '/listings' : '/buy-requests', { method: 'POST', body: JSON.stringify(body) })
      saved()
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="modal-backdrop" onMouseDown={close}>
      <form className="modal" onSubmit={submit} onMouseDown={(e) => e.stopPropagation()}>
        <button type="button" className="modal-close" onClick={close}>×</button>
        <p className="eyebrow">{isListing ? 'Estate listing' : 'Buyer request'}</p>
        <h2>{isListing ? 'List coconuts for sale' : 'Create a buy request'}</h2>
        <div className="form-grid">
          <label>Category<select {...field('category')}><option>RAW</option><option>DEHUSKED</option><option>HUSKS</option></select></label>
          <label>Quantity<input type="number" min="1" required {...field('quantity')} /></label>
          <label>{isListing ? 'Offer price' : 'Bid price'}<input type="number" min="1" required {...field('price')} /></label>
          <label>{isListing ? 'Available date' : 'Needed date'}<input type="date" required {...field('date')} /></label>
          <label>Location<input required {...field('location')} /></label>
          <label>District<input required {...field('district')} /></label>
        </div>
        {error && <div className="alert error">{error}</div>}
        <div className="modal-actions"><button type="button" className="secondary" onClick={close}>Cancel</button><button className="primary" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button></div>
      </form>
    </div>
  )
}

function Orders({ orders, openOrder }) {
  if (!orders.length) return <Empty text="Start a negotiation from the marketplace and it will appear here." />
  return (
    <div className="table-card">
      <table>
        <thead><tr><th>Order</th><th>Category</th><th>Quantity</th><th>Unit price</th><th>Status</th><th></th></tr></thead>
        <tbody>{orders.map((order) => (
          <tr key={order.id}>
            <td><b>{order.code}</b><small>{shortDate(order.createdAt)}</small></td>
            <td>{order.category}</td><td>{order.quantity?.toLocaleString()}</td><td>{money(order.unitPrice)}</td>
            <td><span className={`status ${order.status?.toLowerCase()}`}>{order.status?.replaceAll('_', ' ')}</span></td>
            <td><button className="link-button" onClick={() => openOrder(order)}>Open deal →</button></td>
          </tr>
        ))}</tbody>
      </table>
    </div>
  )
}

function DealModal({ order, user, close, changed }) {
  const [details, setDetails] = useState(null)
  const [message, setMessage] = useState('')
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    try { setDetails(await api(`/orders/${order.id}`)) } catch (err) { setError(err.message) }
  }, [order.id])

  useEffect(() => { load() }, [load])

  async function send(event) {
    event.preventDefault()
    if (!message.trim()) return
    try {
      await api(`/orders/${order.id}/messages`, { method: 'POST', body: JSON.stringify({ type: 'TEXT', text: message }) })
      setMessage('')
      await load()
    } catch (err) { setError(err.message) }
  }

  async function makeOffer() {
    const value = window.prompt('Enter your new price per coconut')
    if (!value) return
    try {
      await api(`/orders/${order.id}/messages`, { method: 'POST', body: JSON.stringify({ type: 'OFFER', offerPrice: Number(value) }) })
      await load()
      changed()
    } catch (err) { setError(err.message) }
  }

  async function updateStatus(status) {
    try {
      await api(`/orders/${order.id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) })
      await load()
      changed()
    } catch (err) { setError(err.message) }
  }

  const current = details?.order || order
  return (
    <div className="modal-backdrop">
      <section className="modal deal-modal">
        <button className="modal-close" onClick={close}>×</button>
        <p className="eyebrow">Negotiation {current.code}</p>
        <h2>{current.quantity} {current.category.toLowerCase()} coconuts</h2>
        <div className="deal-summary"><span>Current price <b>{money(current.unitPrice)}</b></span><span>Status <b>{current.status.replaceAll('_', ' ')}</b></span></div>
        <div className="messages">
          {!details ? <p>Loading messages…</p> : details.messages.length === 0 ? <p className="muted">No messages yet.</p> : details.messages.map((msg) => (
            <div key={msg.id} className={`message ${msg.senderId === user.id ? 'mine' : ''}`}>
              {msg.type === 'OFFER' ? <b>Offer: {money(msg.offerPrice)} each</b> : msg.text}
              <small>{new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</small>
            </div>
          ))}
        </div>
        {error && <div className="alert error">{error}</div>}
        {current.status === 'NEGOTIATING' && (
          <>
            <form className="message-form" onSubmit={send}><input placeholder="Write a message…" value={message} onChange={(e) => setMessage(e.target.value)} /><button className="primary">Send</button></form>
            <div className="deal-actions"><button className="secondary" onClick={makeOffer}>Make price offer</button><button className="success" onClick={() => updateStatus('ACCEPTED')}>Accept deal</button></div>
          </>
        )}
        {current.status === 'ACCEPTED' && <button className="success full" onClick={() => updateStatus('COMPLETED')}>Mark order completed</button>}
      </section>
    </div>
  )
}

function AdminOverview({ dashboard }) {
  const cards = [
    ['👥', 'Users', dashboard.users], ['🌴', 'Active listings', dashboard.activeListings],
    ['📋', 'Open requests', dashboard.openBuyRequests], ['🤝', 'Deals in progress', dashboard.dealsInProgress],
    ['⚠️', 'Open disputes', dashboard.openDisputes], ['💰', 'Completed value', money(dashboard.completedGmv)],
  ]
  return <div className="stats-grid">{cards.map(([icon, name, value]) => <div className="stat-card" key={name}><span>{icon}</span><div><small>{name}</small><strong>{value ?? 0}</strong></div></div>)}</div>
}

function Users({ users, refresh }) {
  async function setStatus(user, status) {
    await api(`/admin/users/${user.id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) })
    refresh()
  }
  return (
    <div className="table-card"><table><thead><tr><th>User</th><th>Phone</th><th>Role</th><th>District</th><th>Status</th><th>Action</th></tr></thead>
      <tbody>{users.map((user) => <tr key={user.id}><td><b>{user.name}</b><small>{user.estateName}</small></td><td>{user.phone}</td><td>{user.role}</td><td>{user.district}</td><td><span className={`status ${user.status.toLowerCase()}`}>{user.status}</span></td><td>{user.status === 'SUSPENDED' ? <button className="link-button" onClick={() => setStatus(user, 'VERIFIED')}>Restore</button> : <button className="danger-link" onClick={() => setStatus(user, 'SUSPENDED')}>Suspend</button>}</td></tr>)}</tbody>
    </table></div>
  )
}

function App() {
  const [session, setSession] = useState(() => {
    const saved = localStorage.getItem('kapconnect_user')
    return saved ? JSON.parse(saved) : null
  })
  const [tab, setTab] = useState('market')
  const [data, setData] = useState({ listings: [], requests: [], orders: [], dashboard: {}, users: [] })
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [form, setForm] = useState(null)
  const [deal, setDeal] = useState(null)
  const [estateView, setEstateView] = useState('home')
  const [estateCategory, setEstateCategory] = useState('RAW')

  const loadData = useCallback(async () => {
    if (!session) return
    setLoading(true)
    setError('')
    try {
      if (session.role === 'ADMIN') {
        const [dashboard, users, orders, listings, requests] = await Promise.all([
          api('/admin/dashboard'), api('/admin/users'), api('/admin/orders'), api('/listings'), api('/buy-requests'),
        ])
        setData({ dashboard, users, orders, listings, requests })
      } else {
        const [listings, requests, orders] = await Promise.all([api('/listings'), api('/buy-requests'), api('/orders')])
        setData({ listings, requests, orders, dashboard: {}, users: [] })
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [session])

  useEffect(() => { loadData() }, [loadData])

  function login(result) {
    localStorage.setItem('kapconnect_token', result.accessToken)
    localStorage.setItem('kapconnect_user', JSON.stringify(result.user))
    setSession(result.user)
    setTab(result.user.role === 'ADMIN' ? 'overview' : 'market')
  }

  function logout() {
    localStorage.removeItem('kapconnect_token')
    localStorage.removeItem('kapconnect_user')
    setSession(null)
  }

  async function negotiate(item, kind) {
    const price = kind === 'listing' ? item.offerPrice : item.bidPrice
    const body = {
      listingId: kind === 'listing' ? item.id : null,
      requestId: kind === 'request' ? item.id : null,
      category: item.category,
      quantity: item.quantity,
      unitPrice: price,
      counterpartyId: kind === 'listing' ? item.estateId : item.buyerId,
      firstMessage: kind === 'listing' ? 'I am interested in this listing.' : 'I can supply this request.',
    }
    try {
      const result = await api('/orders', { method: 'POST', body: JSON.stringify(body) })
      await loadData()
      setDeal(result.order)
    } catch (err) { setError(err.message) }
  }

  async function hide(item, kind) {
    if (!window.confirm(`Hide this ${kind}?`)) return
    try {
      await api(`/admin/${kind === 'listing' ? 'listings' : 'buy-requests'}/${item.id}/hide`, { method: 'PATCH' })
      loadData()
    } catch (err) { setError(err.message) }
  }

  if (!session) return <Login onLogin={login} />

  const myRequests = data.requests.filter((item) => item.buyerId === session.id)
  const myListings = data.listings.filter((item) => item.estateId === session.id)

  if (session.role !== 'ADMIN') {
    let mobileContent
    if (tab === 'orders') {
      mobileContent = <MobileOrders orders={data.orders} openOrder={setDeal} />
    } else if (tab === 'profile') {
      mobileContent = <ProfileScreen user={session} logout={logout} />
    } else if (session.role === 'BUYER') {
      mobileContent = <BuyerMarketplace listings={data.listings} onNegotiate={(item) => negotiate(item, 'listing')} saved={loadData} />
    } else if (estateView === 'categories') {
      mobileContent = <CategoryPicker back={() => setEstateView('home')} choose={(category) => { setEstateCategory(category); setEstateView('sell') }} />
    } else if (estateView === 'sell') {
      mobileContent = <EstateSellScreen category={estateCategory} requests={data.requests.filter((item) => item.category === estateCategory)} onNegotiate={(item) => negotiate(item, 'request')} openForm={() => setForm('listing')} back={() => setEstateView('categories')} />
    } else {
      mobileContent = <EstateDashboard openCoconuts={() => setEstateView('categories')} listings={myListings} />
    }

    return (
      <div className="client-mobile-shell">
        <MobileHeader user={session} logout={logout} />
        <main className="client-mobile-content">
          {error && <div className="alert error">{error}<button onClick={() => setError('')}>×</button></div>}
          {loading ? <div className="loading">Loading KapConnect…</div> : mobileContent}
        </main>
        <MobileNav tab={tab} setTab={(nextTab) => { setTab(nextTab); if (nextTab === 'market' && session.role === 'ESTATE') setEstateView('home') }} />
        {form && <CreateForm type={form} initialCategory={estateCategory} close={() => setForm(null)} saved={() => { setForm(null); loadData() }} />}
        {deal && <DealModal order={deal} user={session} close={() => setDeal(null)} changed={loadData} />}
      </div>
    )
  }

  const titles = {
    overview: ['Admin overview', 'A quick view of everything happening on KapConnect.'],
    users: ['Manage users', 'Verify, review, or suspend marketplace accounts.'],
    market: session.role === 'BUYER' ? ['Coconut marketplace', 'Browse fresh listings from estate owners.'] : ['Buyer requests', 'Find buyers who are ready to purchase coconuts.'],
    requests: ['My buy requests', 'Post what you need and let estate owners contact you.'],
    listings: ['My sale listings', 'Show buyers what is available from your estate.'],
    orders: [session.role === 'ADMIN' ? 'All orders' : 'My deals', 'Track negotiations, messages, and agreed prices.'],
  }
  const [title, subtitle] = titles[tab] || titles.market

  let content
  if (tab === 'overview') content = <AdminOverview dashboard={data.dashboard} />
  else if (tab === 'users') content = <Users users={data.users} refresh={loadData} />
  else if (tab === 'orders') content = <Orders orders={data.orders} openOrder={setDeal} />
  else if (tab === 'market' && session.role === 'BUYER') content = data.listings.length
    ? <div className="card-grid">{data.listings.map((item) => <ListingCard key={item.id} item={item} user={session} onNegotiate={(x) => negotiate(x, 'listing')} onHide={(x) => hide(x, 'listing')} />)}</div>
    : <Empty text="Estate listings will appear here." />
  else if (tab === 'market') content = data.requests.length
    ? <div className="request-list">{data.requests.map((item) => <RequestCard key={item.id} item={item} user={session} onNegotiate={(x) => negotiate(x, 'request')} onHide={(x) => hide(x, 'request')} />)}</div>
    : <Empty text="Buyer requests will appear here." />
  else if (tab === 'requests') content = myRequests.length
    ? <div className="request-list">{myRequests.map((item) => <RequestCard key={item.id} item={item} user={session} onNegotiate={() => {}} onHide={() => {}} />)}</div>
    : <Empty text="Create your first request to start finding sellers." />
  else content = myListings.length
    ? <div className="card-grid">{myListings.map((item) => <ListingCard key={item.id} item={item} user={session} onNegotiate={() => {}} onHide={() => {}} />)}</div>
    : <Empty text="Create your first estate listing." />

  const canCreateRequest = tab === 'requests' && session.role === 'BUYER'
  const canCreateListing = tab === 'listings' && session.role === 'ESTATE'
  return (
    <div className="app-shell">
      <Sidebar user={session} tab={tab} setTab={setTab} logout={logout} />
      <main className="content">
        <Header title={title} subtitle={subtitle} action={(canCreateRequest || canCreateListing) && <button className="primary" onClick={() => setForm(canCreateListing ? 'listing' : 'request')}>＋ {canCreateListing ? 'New listing' : 'New request'}</button>} />
        {error && <div className="alert error">{error}<button onClick={() => setError('')}>×</button></div>}
        {loading ? <div className="loading">Loading KapConnect…</div> : content}
      </main>
      {form && <CreateForm type={form} close={() => setForm(null)} saved={() => { setForm(null); loadData() }} />}
      {deal && <DealModal order={deal} user={session} close={() => setDeal(null)} changed={loadData} />}
    </div>
  )
}

export default App

import { useCallback, useEffect, useState } from 'react'
import { api, authApi } from './api'
import AdminApp from './AdminApp'
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
      const result = await authApi.verifyOtp(selectedPhone, code || '123456')
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

function Empty({ text }) {
  return <div className="empty"><span>🌱</span><h3>Nothing here yet</h3><p>{text}</p></div>
}

function BuyerRequestForm({ saved, defaultDistrict = 'Kurunegala' }) {
  const today = new Date().toISOString().slice(0, 10)
  const [form, setForm] = useState({
    category: 'RAW',
    quantity: '1200',
    price: '110',
    date: today,
    location: defaultDistrict,
    district: defaultDistrict,
  })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [ok, setOk] = useState('')
  const field = (name) => ({ value: form[name], onChange: (e) => setForm({ ...form, [name]: e.target.value }) })

  async function submit(event) {
    event.preventDefault()
    setBusy(true)
    setError('')
    setOk('')
    const quantity = Number(form.quantity)
    const bidPrice = Number(form.price)
    if (!form.date) {
      setError('Please choose the date you need the coconuts.')
      setBusy(false)
      return
    }
    if (!quantity || quantity < 1) {
      setError('Quantity must be at least 1 nut.')
      setBusy(false)
      return
    }
    if (!bidPrice || bidPrice < 1) {
      setError('Bid price must be at least Rs. 1.')
      setBusy(false)
      return
    }
    try {
      await api('/buy-requests', {
        method: 'POST',
        body: JSON.stringify({
          category: form.category,
          quantity,
          bidPrice,
          needDate: form.date,
          location: form.location || form.district,
          district: form.district,
        }),
      })
      setOk('Request submitted. Estate owners nearby can now see it.')
      setForm({
        category: form.category,
        quantity: '1200',
        price: '110',
        date: today,
        location: form.district,
        district: form.district,
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
      <div className="client-form-title"><span>＋</span><h2>Request<br />Coconuts</h2></div>
      <label>Category
        <select {...field('category')}>
          <option value="RAW">Raw coconuts</option>
          <option value="DEHUSKED">Dehusked</option>
          <option value="HUSKS">Husks</option>
        </select>
      </label>
      <label>Number of Nuts Required<input type="number" min="1" required {...field('quantity')} /></label>
      <label>Required Date<input type="date" required min={today} {...field('date')} /></label>
      <label>Bidding Price (Rs. per nut)<input type="number" min="1" required {...field('price')} /></label>
      <label>District<input required {...field('district')} onChange={(e) => setForm({ ...form, district: e.target.value, location: form.location || e.target.value })} /></label>
      <label>Pickup / delivery area<input required {...field('location')} /></label>
      {error && <div className="alert error">{error}</div>}
      {ok && <div className="alert success">{ok}</div>}
      <button className="client-primary full" disabled={busy}>{busy ? 'Submitting…' : 'Submit Request  →'}</button>
      <small className="form-note">Your request will be visible to estate owners. They can message you to negotiate.</small>
    </form>
  )
}

function EstateListingRow({ item, onNegotiate }) {
  return (
    <article className="client-listing-card">
      <div className="client-person">
        <span className="client-avatar">E</span>
        <div>
          <b>{item.verified ? 'Verified Estate' : 'Estate listing'}</b>
          <small>{item.location || item.district || 'Sri Lanka'} · {item.category}</small>
        </div>
        <strong>{money(item.offerPrice)}</strong>
      </div>
      <p className="trust-line">{item.verified ? '✓ Verified offer price' : '○ Pending verification'}</p>
      <div className="client-card-stats">
        <span><small>QUANTITY</small><b>{item.quantity?.toLocaleString()} nuts</b></span>
        <span><small>AVAILABLE</small><b>{shortDate(item.availableAt)}</b></span>
      </div>
      <button className="card-arrow" onClick={() => onNegotiate(item)} aria-label="Start negotiation">→</button>
    </article>
  )
}

function BuyerRequestRow({ item, onNegotiate }) {
  return (
    <article className="client-listing-card">
      <div className="client-person">
        <span className="client-avatar buyer">B</span>
        <div>
          <b>Buyer request</b>
          <small>{item.location || item.district || 'Sri Lanka'} · {item.category}</small>
        </div>
        <strong>{money(item.bidPrice)}</strong>
      </div>
      <div className="client-card-stats">
        <span><small>QUANTITY</small><b>{item.quantity?.toLocaleString()} nuts</b></span>
        <span><small>REQUIRED DATE</small><b>{shortDate(item.needDate)}</b></span>
      </div>
      <button className="card-arrow" onClick={() => onNegotiate(item)} aria-label="Offer to supply">→</button>
    </article>
  )
}

function sortListings(rows, sort) {
  const list = [...rows]
  if (sort === 'price') list.sort((a, b) => a.offerPrice - b.offerPrice)
  if (sort === 'date') list.sort((a, b) => new Date(a.availableAt) - new Date(b.availableAt))
  return list
}

function sortRequests(rows, sort) {
  const list = [...rows]
  if (sort === 'price') list.sort((a, b) => b.bidPrice - a.bidPrice)
  if (sort === 'date') list.sort((a, b) => new Date(a.needDate) - new Date(b.needDate))
  return list
}

function BuyerMarketplace({ listings, onNegotiate, saved, district }) {
  const [sort, setSort] = useState('price')
  const rows = sortListings(listings, sort)
  return (
    <>
      <section className="mobile-title">
        <h1>Marketplace</h1>
        <p>Connect with local estate owners and secure your coconut supply with transparent pricing.</p>
      </section>
      <BuyerRequestForm saved={saved} defaultDistrict={district || 'Kurunegala'} />
      <section className="mobile-section">
        <div className="section-heading"><div><h2>Nearby Estate Owner Listings</h2><p>⌖ {district || 'Your region'}</p></div></div>
        <div className="chip-row">
          <button className={sort === 'price' ? 'active' : ''} onClick={() => setSort('price')}>Best Price</button>
          <button className={sort === 'date' ? 'active' : ''} onClick={() => setSort('date')}>Earliest Pickup</button>
          <button className={sort === 'newest' ? 'active' : ''} onClick={() => setSort('newest')}>Newest</button>
        </div>
        <div className="mobile-card-list">
          {rows.length ? rows.map((item) => <EstateListingRow key={item.id} item={item} onNegotiate={onNegotiate} />) : <Empty text="Estate listings will appear here." />}
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

function EstateDashboard({ openCoconuts, listings, openOrders }) {
  return (
    <>
      <section className="mobile-title compact">
        <p>Estate owner dashboard</p>
        <span className="title-underline" />
      </section>
      <div className="estate-mini-stats">
        <div><small>My listings</small><b>{listings.length}</b></div>
        <div><small>Open deals</small><b>{openOrders}</b></div>
      </div>
      <div className="estate-columns"><div><h2>Selling<br />Categories</h2><p>List products</p></div><div><h2>Provider<br />Services</h2><p>Essential resources</p></div></div>
      <div className="estate-grid">
        {estateTiles.map(([id, icon, title, copy]) => (
          <button key={title} type="button" onClick={id === 'coconut' ? openCoconuts : undefined} disabled={id !== 'coconut'}>
            <span>{icon}</span><b>{title}</b><small>{id === 'coconut' ? copy : 'Coming soon'}</small>
          </button>
        ))}
      </div>
      <section className="mobile-section">
        <div className="section-heading"><div><h2>My coconut listings</h2><p>What buyers can see from you</p></div>
          <button className="filter-pill" type="button" onClick={openCoconuts}>＋ Add</button>
        </div>
        <div className="mobile-card-list">
          {listings.length ? listings.map((item) => (
            <article className="client-listing-card mine" key={item.id}>
              <div className="client-person">
                <span className="client-avatar">🌴</span>
                <div><b>{item.category}</b><small>{item.location || item.district} · {item.verified ? 'Verified' : 'Unverified'}</small></div>
                <strong>{money(item.offerPrice)}</strong>
              </div>
              <div className="client-card-stats">
                <span><small>QUANTITY</small><b>{item.quantity?.toLocaleString()} nuts</b></span>
                <span><small>AVAILABLE</small><b>{shortDate(item.availableAt)}</b></span>
              </div>
            </article>
          )) : <Empty text="Tap Coconuts above to create your first sale listing." />}
        </div>
      </section>
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

function EstateSellScreen({ category, requests, myListings, onNegotiate, openForm, back }) {
  const [sort, setSort] = useState('price')
  const rows = sortRequests(requests, sort)
  const title = category === 'RAW' ? 'Raw Coconuts' : category === 'DEHUSKED' ? 'Dehusked Coconuts' : 'Coconut Husks'
  return (
    <>
      <button className="text-back" onClick={back}>← Categories</button>
      <section className="mobile-title compact"><h1>Sell {title}</h1><p>List your stock and reply to nearby buyer demand.</p></section>
      <button className="sell-action-card" onClick={openForm}><span>🛒</span><div><b>Create Sale Listing</b><small>Add quantity, date and your price</small></div><strong>＋</strong></button>

      <section className="mobile-section">
        <div className="section-heading"><div><h2>My {title} listings</h2><p>{myListings.length} active</p></div></div>
        <div className="mobile-card-list">
          {myListings.length ? myListings.map((item) => (
            <article className="client-listing-card mine" key={item.id}>
              <div className="client-person">
                <span className="client-avatar">🌴</span>
                <div><b>{money(item.offerPrice)} / nut</b><small>{item.location || item.district}</small></div>
                <strong>{item.quantity?.toLocaleString()}</strong>
              </div>
              <div className="client-card-stats">
                <span><small>AVAILABLE</small><b>{shortDate(item.availableAt)}</b></span>
                <span><small>STATUS</small><b>{item.verified ? 'Verified' : 'Live'}</b></span>
              </div>
            </article>
          )) : <Empty text="Create a sale listing so buyers can find you." />}
        </div>
      </section>

      <section className="mobile-section">
        <div className="section-heading"><div><h2>Interested Buyers</h2><p>⌖ Tap → to message and negotiate</p></div></div>
        <div className="chip-row">
          <button className={sort === 'price' ? 'active' : ''} onClick={() => setSort('price')}>Best Bid</button>
          <button className={sort === 'date' ? 'active' : ''} onClick={() => setSort('date')}>Earliest Need</button>
          <button className={sort === 'newest' ? 'active' : ''} onClick={() => setSort('newest')}>Newest</button>
        </div>
        <div className="mobile-card-list">{rows.length ? rows.map((item) => <BuyerRequestRow key={item.id} item={item} onNegotiate={onNegotiate} />) : <Empty text="Buyer requests will appear here." />}</div>
      </section>
    </>
  )
}

function orderActionLabel(status) {
  if (status === 'ACCEPTED') return 'Open chat / Complete'
  if (status === 'COMPLETED') return 'View order'
  if (status === 'REJECTED') return 'View details'
  if (status === 'DISPUTED') return 'View dispute'
  return 'Open chat'
}

function MobileOrders({ orders, openOrder, role }) {
  const [filter, setFilter] = useState('ALL')
  const visible = filter === 'ALL' ? orders : orders.filter((order) => order.status === filter)
  const isEstate = role === 'ESTATE'
  return (
    <>
      <section className="mobile-title compact">
        <h1>{isEstate ? 'My Deals' : 'My Requests'}</h1>
        <p>{isEstate ? 'Chat with buyers, accept prices, and finish deliveries.' : 'Track every negotiation and completed coconut order.'}</p>
      </section>
      <div className="order-tabs">
        <button className={filter === 'NEGOTIATING' ? 'active' : ''} onClick={() => setFilter('NEGOTIATING')}>Pending</button>
        <button className={filter === 'ACCEPTED' ? 'active' : ''} onClick={() => setFilter('ACCEPTED')}>Accepted</button>
        <button className={filter === 'COMPLETED' ? 'active' : ''} onClick={() => setFilter('COMPLETED')}>Completed</button>
        <button className={filter === 'ALL' ? 'active' : ''} onClick={() => setFilter('ALL')}>All</button>
      </div>
      <div className="mobile-order-list">{visible.length ? visible.map((order) => (
        <article className="mobile-order-card" key={order.id}>
          <div className="order-code"><span>{isEstate ? 'DEAL' : 'REQUEST'} #{order.code}</span><span className={`status ${order.status.toLowerCase()}`}>{order.status.replaceAll('_', ' ')}</span></div>
          <h2>{order.category.replaceAll('_', ' ')} Coconut</h2>
          <p>{isEstate ? 'Buyer negotiation' : 'Estate negotiation'}</p>
          <div className="order-value"><span><small>QUANTITY</small><b>{order.quantity?.toLocaleString()} <em>nuts</em></b></span><span><small>PRICE</small><b>{money(order.unitPrice)}<em>/nut</em></b></span></div>
          <button className="client-primary full" onClick={() => openOrder(order)}>{orderActionLabel(order.status)} →</button>
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

function DealModal({ order, user, close, changed }) {
  const [details, setDetails] = useState(null)
  const [message, setMessage] = useState('')
  const [offer, setOffer] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const load = useCallback(async () => {
    try {
      setDetails(await api(`/orders/${order.id}`))
      setError('')
    } catch (err) {
      setError(err.message)
    }
  }, [order.id])

  useEffect(() => { load() }, [load])
  useEffect(() => {
    const timer = setInterval(load, 4000)
    return () => clearInterval(timer)
  }, [load])

  const current = details?.order || order
  const canChat = ['NEGOTIATING', 'ACCEPTED', 'PAYMENT_PENDING'].includes(current.status)
  const canOffer = current.status === 'NEGOTIATING'

  async function send(event) {
    event.preventDefault()
    if (!message.trim() || busy) return
    setBusy(true)
    setError('')
    try {
      await api(`/orders/${order.id}/messages`, { method: 'POST', body: JSON.stringify({ type: 'TEXT', text: message.trim() }) })
      setMessage('')
      await load()
      changed()
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  async function makeOffer(event) {
    event.preventDefault()
    const value = Number(offer)
    if (!value || value < 1) {
      setError('Enter a valid price offer (Rs. per nut).')
      return
    }
    setBusy(true)
    setError('')
    try {
      await api(`/orders/${order.id}/messages`, { method: 'POST', body: JSON.stringify({ type: 'OFFER', offerPrice: value }) })
      setOffer('')
      await load()
      changed()
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  async function updateStatus(status) {
    setBusy(true)
    setError('')
    try {
      await api(`/orders/${order.id}/status`, { method: 'PATCH', body: JSON.stringify({ status }) })
      await load()
      changed()
    } catch (err) {
      setError(err.message)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="modal-backdrop" onMouseDown={close}>
      <section className="modal deal-modal" onMouseDown={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={close}>×</button>
        <p className="eyebrow">Chat · {current.code}</p>
        <h2>{current.quantity} {current.category.toLowerCase()} coconuts</h2>
        <div className="deal-summary">
          <span>Current price <b>{money(current.unitPrice)}</b></span>
          <span>Status <b>{current.status.replaceAll('_', ' ')}</b></span>
        </div>
        <div className="messages">
          {!details ? <p>Loading messages…</p> : details.messages.length === 0 ? <p className="muted">No messages yet. Say hello to start.</p> : details.messages.map((msg) => (
            <div key={msg.id} className={`message ${msg.senderId === user.id ? 'mine' : ''}`}>
              <em className="msg-who">{msg.senderId === user.id ? 'You' : (user.role === 'BUYER' ? 'Estate' : 'Buyer')}</em>
              {msg.type === 'OFFER' ? <b>Offer: {money(msg.offerPrice)} each</b> : msg.text}
              <small>{new Date(msg.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</small>
            </div>
          ))}
        </div>
        {error && <div className="alert error">{error}</div>}
        {canChat && (
          <form className="message-form" onSubmit={send}>
            <input placeholder="Write a message…" value={message} onChange={(e) => setMessage(e.target.value)} disabled={busy} />
            <button className="primary" disabled={busy || !message.trim()}>Send</button>
          </form>
        )}
        {canOffer && (
          <form className="offer-form" onSubmit={makeOffer}>
            <input type="number" min="1" placeholder="New price Rs./nut" value={offer} onChange={(e) => setOffer(e.target.value)} disabled={busy} />
            <button className="secondary" disabled={busy}>Send offer</button>
            <button type="button" className="success" disabled={busy} onClick={() => updateStatus('ACCEPTED')}>Accept deal</button>
            <button type="button" className="danger-outline" disabled={busy} onClick={() => updateStatus('REJECTED')}>Reject</button>
          </form>
        )}
        {current.status === 'ACCEPTED' && (
          <div className="deal-actions">
            <button className="success full" disabled={busy} onClick={() => updateStatus('COMPLETED')}>Mark order completed</button>
          </div>
        )}
        {!canChat && <p className="muted center-note">This order is closed. Messaging is locked.</p>}
      </section>
    </div>
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
    if (!session || session.role === 'ADMIN') return
    setLoading(true)
    setError('')
    try {
      const [listings, requests, orders] = await Promise.all([api('/listings'), api('/buy-requests'), api('/orders')])
      setData({ listings, requests, orders, dashboard: {}, users: [] })
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
    setTab('market')
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
      setError('')
      const result = await api('/orders', { method: 'POST', body: JSON.stringify(body) })
      await loadData()
      setDeal(result.order)
      setTab('orders')
    } catch (err) { setError(err.message) }
  }

  if (!session) return <Login onLogin={login} />
  if (session.role === 'ADMIN') return <AdminApp user={session} logout={logout} />

  const myListings = data.listings.filter((item) => item.estateId === session.id)
  const openOrders = data.orders.filter((o) => ['NEGOTIATING', 'ACCEPTED', 'PAYMENT_PENDING'].includes(o.status)).length

  let mobileContent
  if (tab === 'orders') {
    mobileContent = <MobileOrders orders={data.orders} openOrder={setDeal} role={session.role} />
  } else if (tab === 'profile') {
    mobileContent = <ProfileScreen user={session} logout={logout} />
  } else if (session.role === 'BUYER') {
    mobileContent = <BuyerMarketplace listings={data.listings} onNegotiate={(item) => negotiate(item, 'listing')} saved={loadData} district={session.district} />
  } else if (estateView === 'categories') {
    mobileContent = <CategoryPicker back={() => setEstateView('home')} choose={(category) => { setEstateCategory(category); setEstateView('sell') }} />
  } else if (estateView === 'sell') {
    mobileContent = (
      <EstateSellScreen
        category={estateCategory}
        requests={data.requests.filter((item) => item.category === estateCategory)}
        myListings={myListings.filter((item) => item.category === estateCategory)}
        onNegotiate={(item) => negotiate(item, 'request')}
        openForm={() => setForm('listing')}
        back={() => setEstateView('categories')}
      />
    )
  } else {
    mobileContent = <EstateDashboard openCoconuts={() => setEstateView('categories')} listings={myListings} openOrders={openOrders} />
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

export default App

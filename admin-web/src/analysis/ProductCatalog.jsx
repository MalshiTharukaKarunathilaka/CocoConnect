import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'

// Products the admin adds here are saved in the backend; the mobile app reads the ones
// switched on from GET /api/products.

const CATEGORIES = ['Coconut', 'Husk and coir', 'Fertilizer', 'Machinery', 'Instruments', 'Irrigation equipment', 'Planting materials', 'Chemicals', 'Other']
const UNITS = ['nut', 'kg', 'ton', 'bag', 'litre', 'plant', 'item']
const EMPTY = { name: '', category: 'Coconut', unit: 'nut', minPrice: '', maxPrice: '', description: '', imageUrl: '' }

const price = (p) => (p.minPrice == null && p.maxPrice == null ? 'No price set' : `Rs. ${p.minPrice ?? '-'} – ${p.maxPrice ?? '-'} per ${p.unit}`)

export default function ProductCatalog() {
  const [items, setItems] = useState(null)
  const [form, setForm] = useState(EMPTY)
  const [busy, setBusy] = useState(false)
  const [msg, setMsg] = useState({ text: '', bad: false })
  const [q, setQ] = useState('')

  const load = useCallback(async () => {
    try {
      setItems(await api('/admin/products'))
    } catch (e) {
      setItems([])
      setMsg({ text: e.message, bad: true })
    }
  }, [])
  useEffect(() => { load() }, [load])

  const say = (text, bad = false) => {
    setMsg({ text, bad })
    setTimeout(() => setMsg({ text: '', bad: false }), 3000)
  }
  const set = (k) => (e) => setForm({ ...form, [k]: e.target.value })

  async function add(e) {
    e.preventDefault()
    if (!form.name.trim()) return say('Give the product a name', true)
    setBusy(true)
    try {
      await api('/admin/products', { method: 'POST', body: JSON.stringify(form) })
      setForm(EMPTY)
      await load()
      say('Product added. It now shows in the mobile app')
    } catch (err) {
      say(err.message, true)
    } finally {
      setBusy(false)
    }
  }

  async function toggle(p) {
    try {
      await api(`/admin/products/${p.id}`, { method: 'PATCH', body: JSON.stringify({ active: !p.active }) })
      await load()
      say(p.active ? `${p.name} hidden from the app` : `${p.name} is live in the app`)
    } catch (err) {
      say(err.message, true)
    }
  }

  async function remove(p) {
    if (!window.confirm(`Remove ${p.name} from the app?`)) return
    try {
      await api(`/admin/products/${p.id}`, { method: 'DELETE' })
      await load()
      say(`${p.name} removed`)
    } catch (err) {
      say(err.message, true)
    }
  }

  const shown = (items || []).filter((p) => !q.trim() || `${p.name} ${p.category}`.toLowerCase().includes(q.trim().toLowerCase()))
  const live = (items || []).filter((p) => p.active).length

  return (
    <div className="adm-card pcat">
      <div className="adm-card-h">
        <h2>Products in the mobile app</h2>
        <span className="adm-count">{live} live</span>
      </div>
      <p className="adm-muted" style={{ margin: '0 0 12px' }}>
        Add a product here and it appears in the mobile app for buyers and estate owners. Switch it off to hide it without deleting it. Raw coconut, dehusked coconut and coconut husk are built into the app already.
      </p>

      <form className="pcat-form" onSubmit={add}>
        <label className="pcat-wide">Product name<input value={form.name} onChange={set('name')} placeholder="e.g. Coconut oil" maxLength={80} /></label>
        <label>Category<select value={form.category} onChange={set('category')}>{CATEGORIES.map((c) => <option key={c}>{c}</option>)}</select></label>
        <label>Sold by<select value={form.unit} onChange={set('unit')}>{UNITS.map((c) => <option key={c}>{c}</option>)}</select></label>
        <label>Lowest price (Rs.)<input type="number" min="0" step="any" value={form.minPrice} onChange={set('minPrice')} /></label>
        <label>Highest price (Rs.)<input type="number" min="0" step="any" value={form.maxPrice} onChange={set('maxPrice')} /></label>
        <label className="pcat-wide">Picture link (optional)<input value={form.imageUrl} onChange={set('imageUrl')} placeholder="https://…" /></label>
        <label className="pcat-full">Description (optional)<input value={form.description} onChange={set('description')} placeholder="What buyers should know" maxLength={240} /></label>
        <div className="pcat-actions">
          <button className="adm-btn green" disabled={busy}>{busy ? 'Adding…' : 'Add product'}</button>
          {msg.text && <span className={`pcat-msg ${msg.bad ? 'bad' : ''}`}>{msg.text}</span>}
        </div>
      </form>

      <div className="adm-tools" style={{ marginTop: 16 }}>
        <input className="adm-search" placeholder="Search products" value={q} onChange={(e) => setQ(e.target.value)} />
      </div>
      <table className="adm-table">
        <thead><tr><th>Product</th><th>Category</th><th>Price</th><th>In the app</th><th></th></tr></thead>
        <tbody>
          {shown.map((p) => (
            <tr key={p.id}>
              <td><b>{p.name}</b>{p.description && <div className="adm-muted">{p.description}</div>}</td>
              <td>{p.category}</td>
              <td>{price(p)}</td>
              <td><button type="button" className={`adm-btn ${p.active ? 'green' : 'outline'}`} onClick={() => toggle(p)}>{p.active ? 'Live' : 'Hidden'}</button></td>
              <td><button type="button" className="adm-btn red" onClick={() => remove(p)}>Remove</button></td>
            </tr>
          ))}
          {items && !shown.length && <tr><td colSpan="5" className="adm-empty">{items.length ? 'No products match.' : 'No products added yet.'}</td></tr>}
          {!items && <tr><td colSpan="5" className="adm-empty">Loading…</td></tr>}
        </tbody>
      </table>
    </div>
  )
}

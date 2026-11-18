import { useMemo, useState } from 'react'
import { Bar, CartesianGrid, Cell, ComposedChart, Legend, ReferenceArea, ReferenceLine, Tooltip, XAxis, YAxis } from 'recharts'
import DrillMap from './DrillMap'
import { DISTRICTS, compact, inScope, label, sumBy } from './data'
import { Card, Chart, Kpi, Loading, useData } from './ui'

const BLUE = ['#e4eff5', '#bad7e6', '#86b6cf', '#4f8fb0', '#25607f']
const hash = (t) => [...t].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 997, 7)

const ax = { tick: { fontSize: 11, fill: '#66736c' }, axisLine: false, tickLine: false }
const rs = (n) => `Rs. ${Number(n).toLocaleString('en-LK', { maximumFractionDigits: 0 })}`
const rs1 = (n) => `Rs. ${Number(n).toFixed(1)}`
const nuts = (n) => `${Math.round(n).toLocaleString('en-US')} nuts`

// =============================================================================
// ORDERS: the order book, as a cumulative supply and demand picture.
// Sellers at Rs.110 also accept Rs.120, so supply at a price = everything asked at or below it.
// Buyers who bid Rs.130 also accept Rs.120, so demand at a price = everything bid at or above it.
// =============================================================================
const PRICES = Array.from({ length: 12 }, (_, i) => 80 + i * 5) // 80 .. 135
const SPLIT = 107.5 // below this a row is a buy side price, above it a sell side price

function bookFor(scope) {
  const h = scope ? hash(scope) : 0
  const k = scope ? 0.25 + (h % 10) / 14 : 1 // each area is a share of the island
  const shift = scope ? (h % 5) - 2 : 0
  const hump = (p, mid, w, h) => h * Math.exp(-(((p - mid) / w) ** 2))
  const rows = PRICES.map((p) => {
    const buy = p < SPLIT
    // buyers bid low, sellers ask high; each side has one big spike
    const v = buy
      ? hump(p, 92 + shift, 8, 800) + (p === 90 ? 1100 : 0)
      : hump(p, 123 + shift, 9, 700) + (p === 125 ? 1300 : 0) + (p === 110 ? 500 : 0)
    return { price: p, side: buy ? 'Buy' : 'Sell', exact: Math.max(10, Math.round((v * k) / 10) * 10) }
  })
  // sell: every seller asking this price or less. buy: every buyer bidding this price or more
  return rows.map((r, i) => {
    const cum = r.side === 'Sell'
      ? rows.slice(0, i + 1).filter((x) => x.side === 'Sell').reduce((s, x) => s + x.exact, 0)
      : rows.slice(i).filter((x) => x.side === 'Buy').reduce((s, x) => s + x.exact, 0)
    return { ...r, cum, extra: cum - r.exact }
  })
}

// the centre of gravity is the price where the most nuts sit: the biggest spike on that side
const centre = (rows) => rows.reduce((a, b) => (b.exact > a.exact ? b : a), rows[0]).price
const peak = (rows) => Math.max(...rows.map((r) => r.exact))
const nearest = (v) => PRICES.reduce((a, b) => (Math.abs(b - v) < Math.abs(a - v) ? b : a))
const SIDE = { Buy: { exact: '#b9770a', extra: '#f0d49a' }, Sell: { exact: '#1f6b3d', extra: '#b7dcc3' } }

function BookTip({ active, payload }) {
  if (!active || !payload?.length) return null
  const r = payload[0].payload
  const who = r.side === 'Sell' ? 'Sellers asking' : 'Buyers bidding'
  return (
    <div className="mb-tip">
      <b>Rs. {r.price} per nut · {r.side} side</b>
      <div><i style={{ background: SIDE[r.side].exact }} />{who} exactly this: <b>{nuts(r.exact)}</b></div>
      <div><i style={{ background: SIDE[r.side].extra }} />{r.side === 'Sell' ? 'Supply' : 'Demand'} at this price (cumulative): <b>{nuts(r.cum)}</b></div>
    </div>
  )
}

export function OrderBook() {
  const { data: d } = useData()
  const [sel, setSel] = useState({})
  const scope = sel.region || sel.district || sel.province || ''
  const rows = useMemo(() => bookFor(scope), [scope])
  const lands = useMemo(() => (d ? d.estates.filter((e) => e.volume) : []), [d])
  const buys = rows.filter((r) => r.side === 'Buy')
  const sells = rows.filter((r) => r.side === 'Sell')
  const sellCentre = centre(sells)
  const buyCentre = centre(buys)
  const bestBid = Math.max(...buys.map((r) => r.price))
  const bestAsk = Math.min(...sells.map((r) => r.price))
  if (!d) return <Loading />
  const where = sel.region || (sel.district ? label(sel.district) : sel.province ? `${sel.province} Province` : 'Sri Lanka')
  const perD = Object.fromEntries(DISTRICTS.map((x) => [x.name, sumBy(lands.filter((e) => e.district === x.name), (e) => e.volume.orders)]))
  const cdoNames = d.cdo ? d.cdo.features.map((f) => f.properties.region) : []
  const cdoValues = Object.fromEntries(cdoNames.map((n) => [n, sumBy(lands.filter((e) => e.region === n), (e) => e.volume.orders)]))
  const markers = lands.map((e) => ({
    lat: e.lat, lng: e.lng, icon: 'coconut', size: 20 + Math.min(14, Math.round(e.volume.orders / 450)), color: '#8b5a2b',
    dim: !((!sel.province || inScope(sel, e.district)) && (!sel.region || e.region === sel.region)),
    tip: <div className="an-tip"><b>{e.name}</b><br />{label(e.district)} · {nuts(e.volume.orders)} in orders</div>,
  }))
  const badge = { html: (v) => `<b>${v >= 1000 ? (v / 1000).toFixed(v >= 10000 ? 0 : 1) + 'k' : Math.round(v || 0)}</b>` }

  return (
    <div className="an-root an-solo">
      <div className="an-kpis an-kpis-auto">
        <Kpi photo="rotary" icon="palm" label="Sell side centre of gravity" value={rs(sellCentre)} sub={`biggest spike · ${nuts(peak(sells))}`} />
        <Kpi photo="husking" icon="wallet" tone="amber" label="Buy side centre of gravity" value={rs(buyCentre)} sub={`biggest spike · ${nuts(peak(buys))}`} />
        <Kpi photo="trailer" icon="trend" tone="blue" label="Gap between best bid and best ask" value={rs(bestAsk - bestBid)} sub={`bid ${rs(bestBid)} · ask ${rs(bestAsk)}`} />
        <Kpi photo="copra" icon="receipt" tone="purple" label="Sell push over buy" value={`+${rs(sellCentre - buyCentre)}`} sub="a nut, sellers ask more than buyers bid" />
      </div>

      <div className="mb-split">
      <Card title="Pick an area" sub="Click a province, then a district, then a CDO area. The graph follows your pick" className="mb-map">
        <DrillMap
          geo={d.geo} values={perD} cdoValues={cdoValues} fmt={(v) => nuts(v)} unit="listed in orders" sel={sel} onSel={setSel}
          scale={BLUE} markers={markers} markerKey="ob" badge={badge} height={680}
          legend={[{ icon: 'coconut', color: '#8b5a2b', text: 'Coconut land (bigger nut, more nuts)' }]}
        />
      </Card>
      <Card
        title={`Buy and sell orders · ${where}`}
        sub="Price runs down the side, number of nuts across. The dark bar is the nuts at exactly that price; the pale part adds every order that would also accept it"
      >
        <Chart height={680}>
          <ComposedChart data={rows} layout="vertical" margin={{ top: 10, right: 40, left: 10, bottom: 4 }} barCategoryGap="22%">
            <CartesianGrid horizontal={false} stroke="#e8efe9" />
            <XAxis type="number" {...ax} tickFormatter={(v) => (v >= 1000 ? `${v / 1000}k` : v)} label={{ value: 'Number of nuts', position: 'insideBottomRight', offset: -2, fontSize: 11, fill: '#66736c' }} />
            <YAxis type="category" dataKey="price" {...ax} width={64} tickFormatter={(v) => `Rs.${v}`} />
            <Tooltip content={<BookTip />} cursor={{ fill: 'rgba(26,95,56,0.06)' }} />
            <ReferenceArea y1={80} y2={105} fill="#f6b73c" fillOpacity={0.07} label={{ value: 'BUY', position: 'insideTopRight', fontSize: 13, fontWeight: 700, fill: '#b9770a' }} />
            <ReferenceArea y1={110} y2={135} fill="#2f8a4f" fillOpacity={0.07} label={{ value: 'SELL', position: 'insideBottomRight', fontSize: 13, fontWeight: 700, fill: '#1f6b3d' }} />
            <Bar dataKey="exact" stackId="v" name="Exactly this price">
              {rows.map((r) => <Cell key={r.price} fill={SIDE[r.side].exact} />)}
            </Bar>
            <Bar dataKey="extra" stackId="v" name="Also acceptable (cumulative)" radius={[0, 6, 6, 0]}>
              {rows.map((r) => <Cell key={r.price} fill={SIDE[r.side].extra} />)}
            </Bar>
            <ReferenceLine y={nearest(buyCentre)} stroke="#b9770a" strokeDasharray="5 4" label={{ value: `Buy centre ${rs(buyCentre)}`, position: 'insideTopRight', fontSize: 11, fill: '#b9770a' }} />
            <ReferenceLine y={nearest(sellCentre)} stroke="#1f6b3d" strokeDasharray="5 4" label={{ value: `Sell centre ${rs(sellCentre)}`, position: 'insideTopRight', fontSize: 11, fill: '#1f6b3d' }} />
          </ComposedChart>
        </Chart>
        <p className="mb-note">
          Buyers sit above and sellers below, and the two never touch on the order page: sellers push toward their biggest spike at Rs. {sellCentre}, buyers toward theirs at Rs. {buyCentre}.
          When a bid reaches an ask the order becomes a deal. Hover any bar to read the exact figure and the cumulative total.
        </p>
      </Card>
      </div>
    </div>
  )
}

// =============================================================================
// TRANSACTIONS and DISPUTES: the deal price must be the price paid.
// =============================================================================
const SAMPLE_TXNS = [
  { id: 'TX-5101', deal: 'CR-1187', buyer: 'Nimal Perera', seller: 'Green Palm Land', qty: 1200, dealPrice: 130, paid: 130, reason: '', fault: '' },
  { id: 'TX-5102', deal: 'CR-1175', buyer: 'Sunrise Coir Mills', seller: 'Kapruka Plantation', qty: 800, dealPrice: 126, paid: 116, reason: 'Nuts smaller than agreed', fault: 'Seller' },
  { id: 'TX-5103', deal: 'CR-1169', buyer: 'Ruwan Traders', seller: 'Sea Breeze Gardens', qty: 1500, dealPrice: 124, paid: 124, reason: '', fault: '' },
  { id: 'TX-5104', deal: 'CR-1160', buyer: 'Ruwan Traders', seller: 'Palm Grove Estate', qty: 900, dealPrice: 122, paid: 114, reason: 'Buyer arrived late, nuts sat in the sun', fault: 'Buyer' },
  { id: 'TX-5105', deal: 'CR-1152', buyer: 'Lanka Oil Mills', seller: 'Hill View Coconut', qty: 2000, dealPrice: 128, paid: 128, reason: '', fault: '' },
  { id: 'TX-5106', deal: 'CR-1148', buyer: 'Kamal Fernando', seller: 'Southern Palms', qty: 600, dealPrice: 120, paid: 112, reason: 'Quality below the listing', fault: 'Seller' },
  { id: 'TX-5107', deal: 'CR-1139', buyer: 'Sunrise Coir Mills', seller: 'Green Palm Land', qty: 1000, dealPrice: 125, paid: 119, reason: 'Buyer asked for a discount at the gate', fault: 'Buyer' },
  { id: 'TX-5108', deal: 'CR-1131', buyer: 'Nimal Perera', seller: 'Kapruka Plantation', qty: 700, dealPrice: 127, paid: 127, reason: '', fault: '' },
]
const RATING_HIT = { Seller: -0.3, Buyer: -0.3, Both: -0.15, 'No fault': 0 }

const withDispute = (list) => {
  let n = 2041
  return list.map((t) => {
    const dev = t.paid - t.dealPrice
    return { ...t, dev, loss: dev * t.qty, dispute: dev ? `DSP-${n++}` : '' }
  })
}

export function DealVsPaid() {
  const rows = useMemo(() => withDispute(SAMPLE_TXNS), [])
  const off = rows.filter((r) => r.dev)
  const exact = rows.length - off.length
  const lost = off.reduce((s, r) => s + r.loss, 0)
  const byReason = ['Seller', 'Buyer'].map((who) => ({
    name: `${who} fault`,
    Deviation: Math.abs(off.filter((r) => r.fault === who).reduce((s, r) => s + r.loss, 0)),
  }))
  const chart = rows.map((r) => ({ name: r.id.replace('TX-', ''), Deal: r.dealPrice, Paid: r.paid }))

  return (
    <div className="an-root an-solo">
      <div className="an-kpis an-kpis-auto">
        <Kpi photo="trailer" icon="receipt" label="Paid exactly the deal price" value={`${Math.round((exact / rows.length) * 100)}%`} sub={`${exact} of ${rows.length} transactions`} />
        <Kpi photo="husking" icon="flask" tone="amber" label="Slipped from the deal" value={off.length} sub="each one opens a dispute" />
        <Kpi photo="copra" icon="wallet" tone="purple" label="Money lost to slippage" value={rs(Math.abs(lost))} sub="vs what the deals promised" />
      </div>

      <div className="an-grid2">
        <Card title="Deal price vs price paid" sub="Rupees per nut. The two bars should be the same height">
          <Chart height={240}>
            <ComposedChart data={chart} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
              <CartesianGrid vertical={false} stroke="#e8efe9" />
              <XAxis dataKey="name" {...ax} />
              <YAxis {...ax} width={40} domain={[100, 140]} />
              <Tooltip formatter={(v) => rs(v)} contentStyle={{ borderRadius: 12, border: 'none', fontSize: 12 }} />
              <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} />
              <Bar dataKey="Deal" fill="#2f8a4f" radius={[5, 5, 0, 0]} barSize={12} />
              <Bar dataKey="Paid" fill="#cf9526" radius={[5, 5, 0, 0]} barSize={12} />
            </ComposedChart>
          </Chart>
        </Card>
        <Card title="Whose fault the slippage was" sub="Total rupees lost, split by who caused it">
          <Chart height={240}>
            <ComposedChart data={byReason} layout="vertical" margin={{ top: 8, right: 16, left: 20, bottom: 0 }}>
              <CartesianGrid horizontal={false} stroke="#e8efe9" />
              <XAxis type="number" {...ax} tickFormatter={(v) => `${v / 1000}k`} />
              <YAxis type="category" dataKey="name" {...ax} width={90} />
              <Tooltip formatter={(v) => rs(v)} contentStyle={{ borderRadius: 12, border: 'none', fontSize: 12 }} />
              <Bar dataKey="Deviation" fill="#b4531f" radius={[0, 6, 6, 0]} barSize={22} />
            </ComposedChart>
          </Chart>
        </Card>
      </div>

      <Card title="Transactions against their deals" sub="The standard: the transaction price equals the deal price, exactly. Any difference triggers a dispute and a rating penalty">
        <div className="mb-scroll">
          <table className="adm-table">
            <thead><tr><th>Transaction</th><th>Deal</th><th>Buyer</th><th>Seller</th><th>Qty</th><th>Deal price</th><th>Paid</th><th>Difference</th><th>Result</th></tr></thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td><b>{r.id}</b></td>
                  <td>{r.deal}</td>
                  <td>{r.buyer}</td>
                  <td>{r.seller}</td>
                  <td>{r.qty.toLocaleString()}</td>
                  <td>{rs(r.dealPrice)}</td>
                  <td>{rs(r.paid)}</td>
                  <td className={r.dev ? 'mb-neg' : 'mb-ok'}>{r.dev ? `${r.dev} (${rs(r.loss)})` : 'None'}</td>
                  <td>
                    {r.dev
                      ? <span className="adm-pill disputed">Dispute {r.dispute} · {r.fault} fault</span>
                      : <span className="adm-pill completed">On the deal price</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  )
}

export function FaultBoard() {
  const base = useMemo(() => withDispute(SAMPLE_TXNS).filter((r) => r.dev), [])
  const [fault, setFault] = useState(() => Object.fromEntries(base.map((r) => [r.dispute, r.fault])))
  const rating = { Seller: 4.6, Buyer: 4.4 }

  const hit = (r) => {
    const f = fault[r.dispute]
    return { Seller: f === 'Seller' || f === 'Both' ? RATING_HIT[f] : 0, Buyer: f === 'Buyer' || f === 'Both' ? RATING_HIT[f] : 0 }
  }
  const score = {}
  base.forEach((r) => {
    const h = hit(r)
    score[r.seller] = (score[r.seller] ?? rating.Seller) + h.Seller
    score[r.buyer] = (score[r.buyer] ?? rating.Buyer) + h.Buyer
  })

  return (
    <Card title="Why the price moved, and who pays for it" sub="Every transaction that missed its deal price becomes a dispute. Decide whose fault it was; that side gets a negative rating">
      <div className="mb-scroll">
        <table className="adm-table">
          <thead><tr><th>Dispute</th><th>Deal → paid</th><th>Why it deviated</th><th>At fault</th><th>Rating penalty</th></tr></thead>
          <tbody>
            {base.map((r) => {
              const h = hit(r)
              const who = fault[r.dispute]
              const target = [h.Seller && r.seller, h.Buyer && r.buyer].filter(Boolean)
              return (
                <tr key={r.dispute}>
                  <td><b>{r.dispute}</b><div className="adm-muted">{r.id} · {r.deal}</div></td>
                  <td>{rs(r.dealPrice)} → <b>{rs(r.paid)}</b><div className="mb-neg">{r.dev} a nut · {rs(r.loss)}</div></td>
                  <td>{r.reason}</td>
                  <td>
                    <select value={who} onChange={(e) => setFault({ ...fault, [r.dispute]: e.target.value })}>
                      {['Seller', 'Buyer', 'Both', 'No fault'].map((o) => <option key={o}>{o}</option>)}
                    </select>
                  </td>
                  <td>
                    {target.length
                      ? target.map((t) => <div key={t} className="mb-neg">{t}: {RATING_HIT[who]} stars</div>)
                      : <span className="mb-ok">No penalty</span>}
                  </td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
      <h4 className="mb-h">Ratings after the penalties</h4>
      <div className="mb-scores">
        {Object.entries(score).map(([name, v]) => (
          <span key={name} className={v < 4.3 ? 'low' : ''}><b>{name}</b>{v.toFixed(1)} ★</span>
        ))}
      </div>
    </Card>
  )
}

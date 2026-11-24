import { useMemo, useState } from 'react'
import { Bar, CartesianGrid, Cell, ComposedChart, Legend, ReferenceArea, ReferenceLine, Tooltip, XAxis, YAxis } from 'recharts'
import DrillMap from './DrillMap'
import { DISTRICTS, compact, inScope, label, sumBy } from './data'
import { Card, Chart, ExportBtn, Kpi, Loading, useData } from './ui'
import { PricePicker, periodInfo, usePeriod } from './AnalysisPages'

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

function bookFor(scope, period = 'today') {
  const h = scope ? hash(scope) : 0
  const dh = period === 'today' ? 0 : hash(period) // another day or month: a different book
  const k = (scope ? 0.25 + (h % 10) / 14 : 1) * (dh ? 0.75 + (dh % 10) / 20 : 1) // each area is a share of the island
  const shift = (scope ? (h % 5) - 2 : 0) + (dh ? (dh % 3) - 1 : 0)
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
  const [period, setPeriod] = usePeriod()
  const now = new Date()
  const rows = useMemo(() => bookFor(scope, period), [scope, period])
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
          scale={BLUE} markers={markers} markerKey="ob" badge={badge} height={740}
          legend={[{ icon: 'coconut', color: '#8b5a2b', text: 'Coconut land (bigger nut, more nuts)' }]}
        />
      </Card>
      <Card
        title={`Buy and sell orders · ${where}`}
        sub="Price runs down the side, number of nuts across. The dark bar is the nuts at exactly that price; the pale part adds every order that would also accept it"
        right={<span className="mb-datebox an-noprint"><span className="mp-when">{periodInfo(period, now).text}</span><PricePicker period={period} setPeriod={setPeriod} now={now} /></span>}
      >
        <Chart height={680}>
          <ComposedChart data={rows} layout="vertical" margin={{ top: 10, right: 40, left: 10, bottom: 4 }} barCategoryGap="22%">
            <CartesianGrid horizontal={false} stroke="#e8efe9" />
            <XAxis type="number" {...ax} tickFormatter={(v) => (v >= 1000 ? `${v / 1000}k` : v)} label={{ value: 'Number of nuts', position: 'insideBottomRight', offset: -2, fontSize: 11, fill: '#66736c' }} />
            <YAxis type="category" dataKey="price" {...ax} width={78} label={{ value: 'Price per nut (Rs.)', angle: -90, position: 'insideLeft', offset: 4, fontSize: 11, fill: '#66736c', style: { textAnchor: 'middle' } }} tickFormatter={(v) => `Rs.${v}`} />
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
const RATING_HIT = { Seller: -0.3, Buyer: -0.3, Both: -0.15, 'No fault': 0 }

// Sample transactions, the same every time. Most pay the deal price and deliver the deal quantity.
const BUYERS = ['Nimal Perera', 'Sunrise Coir Mills', 'Ruwan Traders', 'Lanka Oil Mills', 'Kamal Fernando', 'Ocean Copra Co.']
const SELLERS = ['Green Palm Land', 'Kapruka Plantation', 'Sea Breeze Gardens', 'Palm Grove Estate', 'Hill View Coconut', 'Southern Palms']
const PRICE_WHY = { Seller: ['Nuts smaller than agreed', 'Quality below the listing', 'Wet or damaged nuts'], Buyer: ['Buyer arrived late, nuts sat in the sun', 'Buyer asked for a discount at the gate'] }
const QTY_WHY = { Seller: ['Short delivery, fewer nuts loaded', 'Nuts lost on the road'], Buyer: ['Buyer took fewer nuts than agreed'] }

function makeTxns() {
  let seed = 7
  const rnd = () => ((seed = (seed * 9301 + 49297) % 233280) / 233280)
  const pick = (list) => list[Math.floor(rnd() * list.length)]
  return Array.from({ length: 48 }, (_, i) => {
    const qty = 400 + Math.floor(rnd() * 20) * 100
    const dealPrice = 118 + Math.floor(rnd() * 15)
    const r = rnd()
    let paid = dealPrice
    let got = qty
    const why = []
    let fault = ''
    const priceFault = rnd() < 0.65 ? 'Seller' : 'Buyer'
    const qtyFault = rnd() < 0.8 ? 'Seller' : 'Buyer'
    if (r >= 0.58) {
      const price = r < 0.8 || r >= 0.93
      const quantity = r >= 0.72
      if (price) { paid = dealPrice - (2 + Math.floor(rnd() * 11)); why.push(pick(PRICE_WHY[priceFault])) }
      if (quantity) { got = Math.round((qty * (1 - (0.02 + rnd() * 0.14))) / 10) * 10; why.push(pick(QTY_WHY[qtyFault])) }
      fault = price && quantity && priceFault !== qtyFault ? 'Both' : price ? priceFault : qtyFault
    }
    return {
      id: `TX-${5101 + i}`, deal: `CR-${1187 - i * 3}`, buyer: BUYERS[i % BUYERS.length], seller: SELLERS[(i * 5 + 2) % SELLERS.length],
      qty, got, dealPrice, paid, reason: why.join('. '), fault,
    }
  })
}

const TXNS = (() => {
  let n = 2041
  return makeTxns().map((t) => {
    const dev = t.paid - t.dealPrice // rupees a nut
    const qdev = t.got - t.qty // nuts
    const off = dev !== 0 || qdev !== 0
    return { ...t, dev, qdev, qpct: Math.abs(qdev) / t.qty, loss: t.paid * t.got - t.dealPrice * t.qty, dispute: off ? `DSP-${n++}` : '' }
  })
})()
const OFF = TXNS.filter((r) => r.dispute)
const sign = (v) => (v > 0 ? `+${v}` : `${v}`)

/** Count transactions into equal bands, split by who was at fault. */
function histogram(rows, valueOf, lo, width, count, nameOf) {
  const bins = Array.from({ length: count }, (_, i) => ({ name: nameOf(lo + i * width, lo + (i + 1) * width), Seller: 0, Buyer: 0, Both: 0 }))
  rows.forEach((r) => {
    const i = Math.max(0, Math.min(count - 1, Math.floor((valueOf(r) - lo) / width)))
    bins[i][r.fault || 'Seller'] += 1
  })
  return bins
}
const FAULT_COLORS = { Seller: '#b4531f', Buyer: '#0288d1', Both: '#8e44ad' }

function Spread({ title, sub, data, unit }) {
  return (
    <Card title={title} sub={sub}>
      <Chart height={250}>
        <ComposedChart data={data} margin={{ top: 8, right: 8, left: 0, bottom: 0 }}>
          <CartesianGrid vertical={false} stroke="#e8efe9" />
          <XAxis dataKey="name" {...ax} />
          <YAxis {...ax} width={30} allowDecimals={false} />
          <Tooltip formatter={(v, k) => [`${v} ${unit}`, `${k} fault`]} contentStyle={{ borderRadius: 12, border: 'none', fontSize: 12 }} cursor={{ fill: 'rgba(26,95,56,0.06)' }} />
          <Legend iconType="circle" wrapperStyle={{ fontSize: 12 }} />
          {Object.keys(FAULT_COLORS).map((k) => <Bar key={k} dataKey={k} stackId="f" fill={FAULT_COLORS[k]} barSize={26} />)}
        </ComposedChart>
      </Chart>
    </Card>
  )
}

export function DealVsPaid() {
  const { data: d } = useData()
  const [sel, setSel] = useState({})
  const lands = useMemo(() => (d ? d.estates.filter((e) => e.lat != null) : []), [d])
  // every sample transaction happened at one of the dashboard's coconut lands
  const all = useMemo(() => (lands.length ? TXNS.map((t, i) => ({ ...t, land: lands[(i * 7 + 3) % lands.length] })) : []), [lands])
  if (!d) return <Loading />
  const inArea = (t) => inScope(sel, t.land.district) && (!sel.region || t.land.region === sel.region)
  const TX = all.filter(inArea)
  const OFFH = TX.filter((r) => r.dispute)
  const where = sel.region || (sel.district ? label(sel.district) : sel.province ? `${sel.province} Province` : 'Sri Lanka')
  const allOff = all.filter((r) => r.dispute)
  const perD = Object.fromEntries(DISTRICTS.map((x) => [x.name, allOff.filter((r) => r.land.district === x.name).length]))
  const cdoNames = d.cdo ? d.cdo.features.map((f) => f.properties.region) : []
  const cdoValues = Object.fromEntries(cdoNames.map((n) => [n, allOff.filter((r) => r.land.region === n).length]))
  const badge = { html: (v) => `<b>${Math.round(v || 0)}</b>` }
  const markers = allOff.map((r) => ({
    lat: r.land.lat, lng: r.land.lng, icon: 'coconut', size: 22 + Math.min(12, Math.round(Math.abs(r.loss) / 4000)), color: '#b4531f',
    dim: !inArea(r),
    tip: <div className="an-tip"><b>{r.id} · {r.dispute}</b><br />{r.land.name} · {label(r.land.district)}<br />{r.fault} fault · {rs(r.loss)}</div>,
  }))
  const exact = TX.length - OFFH.length
  const priceOff = OFFH.filter((r) => r.dev)
  const qtyOff = OFFH.filter((r) => r.qdev)
  const lost = OFFH.reduce((s, r) => s + r.loss, 0)
  const short = qtyOff.reduce((s, r) => s + Math.abs(r.qdev), 0)
  // price: rupees below the deal price, in Rs. 2 bands. quantity: percent short, in 3% bands
  const priceBins = histogram(priceOff, (r) => r.dev, -12, 2, 6, (a, b) => `${a} to ${b}`)
  const qtyBins = histogram(qtyOff, (r) => -r.qpct * 100, -18, 3, 6, (a, b) => `${Math.abs(b)}-${Math.abs(a)}%`)
  const chart = TX.slice(0, 10).map((r) => ({ name: r.id.replace('TX-', ''), Deal: r.dealPrice, Paid: r.paid }))
  const faultTotals = ['Seller', 'Buyer', 'Both'].map((who) => ({ name: `${who} fault`, Lost: Math.abs(OFFH.filter((r) => r.fault === who).reduce((s, r) => s + r.loss, 0)) }))

  return (
    <div className="an-root an-solo">
      <div className="an-kpis an-kpis-auto">
        <Kpi photo="trailer" icon="receipt" label="Matched the deal exactly" value={`${Math.round((exact / Math.max(1, TX.length)) * 100)}%`} sub={`${exact} of ${TX.length} transactions`} />
        <Kpi photo="husking" icon="flask" tone="amber" label="Price slipped" value={priceOff.length} sub="paid less than the deal price" />
        <Kpi photo="rotary" icon="palm" tone="blue" label="Quantity short" value={qtyOff.length} sub={`${nuts(short)} missing in total`} />
        <Kpi photo="copra" icon="wallet" tone="purple" label="Money lost to slippage" value={rs(Math.abs(lost))} sub="every one opens a dispute" />
      </div>

      <div className="mb-split">
        <Card title="Pick an area" sub="Each coconut is a transaction that left its deal; the number is the disputes in that area. Click to drill down, and everything on this page follows" className="mb-map">
          <DrillMap
            geo={d.geo} values={perD} cdoValues={cdoValues} fmt={(v) => `${v} disputes`} unit="disputes" sel={sel} onSel={setSel}
            scale={['#fbeee6', '#f1cdb8', '#e2a37c', '#c9733f', '#8f4417']} markers={markers} markerKey="tx" badge={badge} height={620}
            legend={[{ icon: 'coconut', color: '#b4531f', text: 'Transaction that left its deal (bigger = more money lost)' }]}
          />
        </Card>
        <div className="mb-stack">
          <Spread title={`How far the price slipped · ${where}`} sub="Transactions by rupees below the deal price (a nut). Colour shows who caused it" data={priceBins} unit="transactions" />
          <Spread title={`How many nuts were short · ${where}`} sub="Transactions by share of the agreed quantity not delivered. Colour shows who caused it" data={qtyBins} unit="transactions" />
        </div>
      </div>

      <div className="an-grid2">
        <Card title="Deal price vs price paid" sub="Rupees per nut, first ten transactions. The two bars should be the same height">
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
        <Card title="Money lost, by who caused it" sub="Total rupees short of what the deals promised">
          <Chart height={240}>
            <ComposedChart data={faultTotals} layout="vertical" margin={{ top: 8, right: 16, left: 20, bottom: 0 }}>
              <CartesianGrid horizontal={false} stroke="#e8efe9" />
              <XAxis type="number" {...ax} tickFormatter={(v) => `${Math.round(v / 1000)}k`} />
              <YAxis type="category" dataKey="name" {...ax} width={90} />
              <Tooltip formatter={(v) => rs(v)} contentStyle={{ borderRadius: 12, border: 'none', fontSize: 12 }} />
              <Bar dataKey="Lost" radius={[0, 6, 6, 0]} barSize={22}>
                {faultTotals.map((f) => <Cell key={f.name} fill={FAULT_COLORS[f.name.split(' ')[0]]} />)}
              </Bar>
            </ComposedChart>
          </Chart>
        </Card>
      </div>

      <Card
        title="Transactions that left their deal"
        sub={`The standard: the price and the quantity must be exactly what the deal says. These ${OFFH.length} did not, so each opened a dispute. Latest 12 shown`}
        right={<ExportBtn name="transactions-that-left-their-deal" columns={['Transaction', 'Deal', 'Buyer', 'Seller', 'Nuts in deal', 'Nuts received', 'Nuts difference', 'Price in deal (Rs)', 'Price paid (Rs)', 'Price difference (Rs a nut)', 'Money difference (Rs)', 'Dispute', 'Fault']} rows={OFFH.map((r) => [r.id, r.deal, r.buyer, r.seller, r.qty, r.got, r.qdev, r.dealPrice, r.paid, r.dev, r.loss, r.dispute, r.fault])} />}
      >
        <div className="mb-scroll">
          <table className="adm-table">
            <thead><tr><th>Transaction</th><th>Buyer / seller</th><th>Nuts: deal → received</th><th>Price: deal → paid</th><th>Money difference</th><th>Result</th></tr></thead>
            <tbody>
              {OFFH.slice(0, 12).map((r) => (
                <tr key={r.id}>
                  <td><b>{r.id}</b><div className="adm-muted">{r.deal}</div></td>
                  <td>{r.buyer}<div className="adm-muted">{r.seller}</div></td>
                  <td>{r.qty.toLocaleString()} → <b>{r.got.toLocaleString()}</b>{r.qdev ? <div className="mb-neg">{sign(r.qdev)} nuts</div> : <div className="mb-ok">as agreed</div>}</td>
                  <td>{rs(r.dealPrice)} → <b>{rs(r.paid)}</b>{r.dev ? <div className="mb-neg">{sign(r.dev)} a nut</div> : <div className="mb-ok">as agreed</div>}</td>
                  <td className="mb-neg">{rs(r.loss)}</td>
                  <td><span className="adm-pill disputed">Dispute {r.dispute} · {r.fault} fault</span></td>
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
  const base = useMemo(() => OFF.slice(0, 8), [])
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
    <Card
      title="Why the deal changed, and who pays for it"
      sub="Every transaction that missed its deal price or quantity becomes a dispute. Decide whose fault it was; that side gets a negative rating"
      right={<ExportBtn name="dispute-fault-and-rating-penalty" columns={['Dispute', 'Transaction', 'Deal', 'Buyer', 'Seller', 'Price in deal (Rs)', 'Price paid (Rs)', 'Nuts in deal', 'Nuts received', 'Money difference (Rs)', 'Why', 'At fault', 'Rating penalty (stars)']} rows={base.map((r) => [r.dispute, r.id, r.deal, r.buyer, r.seller, r.dealPrice, r.paid, r.qty, r.got, r.loss, r.reason, fault[r.dispute], RATING_HIT[fault[r.dispute]] ?? 0])} />}
    >
      <div className="mb-scroll">
        <table className="adm-table">
          <thead><tr><th>Dispute</th><th>What changed</th><th>Why</th><th>At fault</th><th>Rating penalty</th></tr></thead>
          <tbody>
            {base.map((r) => {
              const h = hit(r)
              const who = fault[r.dispute]
              const target = [h.Seller && r.seller, h.Buyer && r.buyer].filter(Boolean)
              return (
                <tr key={r.dispute}>
                  <td><b>{r.dispute}</b><div className="adm-muted">{r.id} · {r.deal}</div></td>
                  <td>
                    {r.dev ? <div>Price {rs(r.dealPrice)} → <b>{rs(r.paid)}</b> <span className="mb-neg">({sign(r.dev)} a nut)</span></div> : null}
                    {r.qdev ? <div>Nuts {r.qty.toLocaleString()} → <b>{r.got.toLocaleString()}</b> <span className="mb-neg">({sign(r.qdev)})</span></div> : null}
                    <div className="mb-neg">{rs(r.loss)}</div>
                  </td>
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

import { useEffect, useMemo, useRef, useState } from 'react'
import './DisputeFlow.css'

// Demo only: sample disputes that move through a live, delivery-app style tracker.
const STEPS = [
  ['Reported', 'Buyer raised the problem'],
  ['Evidence', 'Photos and notes collected'],
  ['Under review', 'Admin is checking both sides'],
  ['Decision', 'Outcome chosen'],
  ['Resolved', 'Money moved, both sides told'],
]

const SAMPLE = [
  {
    id: 'DSP-2041', title: 'Short delivery', detail: 'Agreed 1,200 nuts, received 1,040', deal: 'CR-1187',
    buyer: 'Nimal Perera', seller: 'Green Palm Land', district: 'Kurunegala', amount: 156000, claim: 24000, level: 'High',
    photo: 'trailer', step: 1, at: 'Today, 9:12 AM',
    chat: [
      ['buyer', 'Nimal Perera', 'The truck was weighed at my gate. 160 nuts are missing.'],
      ['seller', 'Green Palm Land', 'We loaded 1,200 at the estate. Some fell during the road trip.'],
    ],
  },
  {
    id: 'DSP-2040', title: 'Quality below agreed', detail: 'Husks were wet and mouldy', deal: 'CR-1175',
    buyer: 'Sunrise Coir Mills', seller: 'Kapruka Plantation', district: 'Gampaha', amount: 48000, claim: 15000, level: 'Medium',
    photo: 'husking', step: 2, at: 'Today, 7:40 AM',
    chat: [
      ['buyer', 'Sunrise Coir Mills', 'Half of the husks are wet. We cannot use them.'],
      ['admin', 'KapConnect Admin', 'Please upload photos of the load so we can compare with the listing.'],
    ],
  },
  {
    id: 'DSP-2038', title: 'Late delivery', detail: 'Arrived 3 days after the agreed date', deal: 'CR-1160',
    buyer: 'Ruwan Traders', seller: 'Sea Breeze Gardens', district: 'Kalutara', amount: 82000, claim: 8000, level: 'Low',
    photo: 'rotary', step: 0, at: 'Yesterday, 4:25 PM',
    chat: [['buyer', 'Ruwan Traders', 'Delivery was 3 days late and we lost a sale because of it.']],
  },
]

const rs = (n) => `Rs. ${Math.round(n).toLocaleString('en-LK')}`
const NEXT_NOTE = [
  'Waiting for you to ask both sides for evidence.',
  'Waiting for photos. Admin response due in about 2 hours.',
  'Reviewing the evidence. Pick an outcome when ready.',
  'Outcome chosen. Close the dispute to pay out and notify.',
  'Done. Both sides have been notified.',
]

export default function DisputeFlow() {
  const [items, setItems] = useState(() => SAMPLE.map((d) => ({ ...d, events: [[d.at, 'Dispute reported by the buyer']], outcome: null })))
  const [open, setOpen] = useState(SAMPLE[0].id)
  const [partial, setPartial] = useState(50)
  const [play, setPlay] = useState(false)
  const [now, setNow] = useState(() => new Date())
  const timer = useRef(null)
  const d = items.find((x) => x.id === open)

  useEffect(() => {
    const t = setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(t)
  }, [])
  const clock = () => now.toLocaleTimeString('en-LK', { hour: 'numeric', minute: '2-digit' })

  const update = (id, fn) => setItems((list) => list.map((x) => (x.id === id ? fn(x) : x)))
  const advance = (id, note, extra = {}) =>
    update(id, (x) => ({ ...x, step: Math.min(4, x.step + 1), events: [...x.events, [`Today, ${clock()}`, note]], ...extra }))

  const act = (kind) => {
    if (!d) return
    if (kind === 'evidence') advance(d.id, 'Admin asked both sides for evidence')
    if (kind === 'review') advance(d.id, 'Evidence received. Review started')
    if (kind === 'full') advance(d.id, `Decision: full refund of ${rs(d.claim)} to the buyer`, { outcome: { kind: 'Full refund', amount: d.claim } })
    if (kind === 'partial') advance(d.id, `Decision: partial refund of ${rs((d.claim * partial) / 100)} to the buyer`, { outcome: { kind: 'Partial refund', amount: (d.claim * partial) / 100 } })
    if (kind === 'reject') advance(d.id, 'Decision: claim rejected. The seller keeps the full payment', { outcome: { kind: 'Claim rejected', amount: 0 } })
    if (kind === 'close') advance(d.id, 'Payout done. Buyer and seller notified')
  }

  // auto play: runs the selected dispute to the end
  useEffect(() => {
    clearInterval(timer.current)
    if (!play || !d) return undefined
    timer.current = setInterval(() => {
      setItems((list) =>
        list.map((x) => {
          if (x.id !== open) return x
          if (x.step >= 4) {
            setPlay(false)
            return x
          }
          const notes = ['Admin asked both sides for evidence', 'Evidence received. Review started', `Decision: partial refund of ${rs(x.claim / 2)} to the buyer`, 'Payout done. Buyer and seller notified']
          const k = Math.max(0, x.step - 0) // 0..3
          const idx = Math.min(3, k)
          return { ...x, step: x.step + 1, events: [...x.events, [`Today, ${clock()}`, notes[idx]]], outcome: x.step === 2 ? { kind: 'Partial refund', amount: x.claim / 2 } : x.outcome }
        }),
      )
    }, 1800)
    return () => clearInterval(timer.current)
  }, [play, open]) // eslint-disable-line

  const reset = () => {
    setPlay(false)
    setItems(SAMPLE.map((x) => ({ ...x, events: [[x.at, 'Dispute reported by the buyer']], outcome: null })))
  }
  const counts = useMemo(() => ({ open: items.filter((x) => x.step < 4).length, done: items.filter((x) => x.step >= 4).length }), [items])
  const pct = d ? (d.step / (STEPS.length - 1)) * 100 : 0

  return (
    <div className="df">
      <div className="df-top">
        <div>
          <h3>Dispute tracker <span className="df-demo">Demo</span></h3>
          <p>Follow a dispute from the first report to the payout, the way you follow an order in a delivery app.</p>
        </div>
        <div className="df-top-r">
          <span className="df-count"><b>{counts.open}</b> open</span>
          <span className="df-count"><b>{counts.done}</b> resolved</span>
          <button className="adm-btn outline" onClick={() => setPlay(!play)}>{play ? 'Pause demo' : 'Play demo'}</button>
          <button className="adm-btn outline" onClick={reset}>Reset</button>
        </div>
      </div>

      <div className="df-body">
        <aside className="df-list">
          {items.map((x) => (
            <button key={x.id} className={`df-card ${x.id === open ? 'on' : ''}`} onClick={() => { setOpen(x.id); setPlay(false) }}>
              <span className="df-card-h">
                <b>{x.id}</b>
                <i className={`df-level ${x.level.toLowerCase()}`}>{x.level}</i>
              </span>
              <strong>{x.title}</strong>
              <small>{x.buyer} vs {x.seller}</small>
              <span className="df-mini"><i style={{ width: `${(x.step / 4) * 100}%` }} /></span>
              <em>{x.step >= 4 ? 'Resolved' : STEPS[x.step][0]} · claim {rs(x.claim)}</em>
            </button>
          ))}
        </aside>

        {d && (
          <section className="df-detail">
            <header className="df-head">
              <img src={`/photos/${d.photo}.jpg`} alt="" />
              <div>
                <h4>{d.title} <small>{d.id} · Deal {d.deal}</small></h4>
                <p>{d.detail}</p>
                <div className="df-meta">
                  <span>Buyer <b>{d.buyer}</b></span>
                  <span>Seller <b>{d.seller}</b></span>
                  <span>{d.district}</span>
                  <span>Deal value <b>{rs(d.amount)}</b></span>
                  <span>Claimed <b>{rs(d.claim)}</b></span>
                </div>
              </div>
            </header>

            <div className="df-track">
              <div className="df-rail"><i style={{ width: `${pct}%` }} /></div>
              <ol>
                {STEPS.map(([name, note], i) => (
                  <li key={name} className={i < d.step ? 'done' : i === d.step ? 'now' : ''}>
                    <span>{i < d.step ? '✓' : i + 1}</span>
                    <b>{name}</b>
                    <small>{note}</small>
                  </li>
                ))}
              </ol>
            </div>
            <div className="df-eta"><i className={d.step < 4 ? 'live' : ''} />{NEXT_NOTE[d.step]}</div>

            <div className="df-cols">
              <div className="df-feed">
                <h5>Activity</h5>
                <ul>
                  {[...d.events].reverse().map(([t, text], i) => (
                    <li key={i} className={i === 0 ? 'new' : ''}><time>{t}</time><span>{text}</span></li>
                  ))}
                </ul>
                <h5>Messages</h5>
                <div className="df-chat">
                  {d.chat.map(([who, name, text], i) => (
                    <div key={i} className={`df-msg ${who}`}><b>{name}</b><p>{text}</p></div>
                  ))}
                </div>
              </div>

              <div className="df-act">
                <h5>Next action</h5>
                {d.step === 0 && <button className="adm-btn green" onClick={() => act('evidence')}>Ask both sides for evidence</button>}
                {d.step === 1 && <button className="adm-btn green" onClick={() => act('review')}>Evidence received, start review</button>}
                {d.step === 2 && (
                  <div className="df-decide">
                    <button className="adm-btn green" onClick={() => act('full')}>Full refund {rs(d.claim)}</button>
                    <label>
                      Partial refund: <b>{partial}%</b> = {rs((d.claim * partial) / 100)}
                      <input type="range" min="10" max="90" step="10" value={partial} onChange={(e) => setPartial(Number(e.target.value))} />
                    </label>
                    <button className="adm-btn outline" onClick={() => act('partial')}>Refund {partial}%</button>
                    <button className="adm-btn red" onClick={() => act('reject')}>Reject the claim</button>
                  </div>
                )}
                {d.step === 3 && <button className="adm-btn green" onClick={() => act('close')}>Pay out and close</button>}
                {d.step === 4 && d.outcome && (
                  <div className="df-done">
                    <span>{'✓'}</span>
                    <b>{d.outcome.kind}</b>
                    <p>{d.outcome.amount ? `${rs(d.outcome.amount)} returned to ${d.buyer}` : `${d.seller} keeps the payment`}</p>
                    <small>Buyer and seller were notified in the app.</small>
                  </div>
                )}
              </div>
            </div>
          </section>
        )}
      </div>
    </div>
  )
}

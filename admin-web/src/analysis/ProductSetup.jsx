import { useEffect, useMemo, useState } from 'react'
import DrillMap from './DrillMap'
import { Bars, PhotoRow, Split } from './AnalysisPages'
import { DISTRICTS, compact, label, num, provinceOf, scopeName, sumBy } from './data'
import { Card, DataTable, Loading, PageHead, RegionSlot, useData } from './ui'

// Product setup: the coconut price band of every district, on a map you can click,
// with one place to change a band and publish it. The bands, buyers and estates
// are the real ones from the admin backend; publishing saves them there.

const nums = (band) => {
  const m = String(band || '').match(/\d+(?:\.\d+)?/g)
  if (!m) return [0, 0]
  const a = Number(m[0])
  const b = Number(m[1] ?? m[0])
  return [Math.min(a, b), Math.max(a, b)]
}
const bandText = (lo, hi) => `Rs. ${lo} – ${hi}`
const rs0 = (v) => `Rs. ${Number(v).toFixed(0)}`
const BAND_BADGE = { html: (v) => `<b class="solo">${v ? 'Rs. ' + Number(v).toFixed(0) : '-'}</b>` }
const GREENS = ['#e7f3ea', '#bfdfc8', '#8cc59f', '#4f9d6e', '#1f6a3f']

export default function ProductSetup({ regions, onPublish }) {
  const { data: d, error } = useData()
  const [sel, setSel] = useState({})
  const [picked, setPicked] = useState(null)
  const [draft, setDraft] = useState('')
  const [saving, setSaving] = useState(false)

  const rows = useMemo(
    () => regions.map((r) => {
      const [lo, hi] = nums(r.band)
      const dist = DISTRICTS.find((x) => x.name.toLowerCase() === String(r.name).toLowerCase())
      return { ...r, lo, hi, mid: (lo + hi) / 2, district: dist ? dist.name : null, province: dist ? dist.province : '-' }
    }),
    [regions],
  )
  const active = rows.find((r) => r.name === picked) || null
  useEffect(() => { setDraft(active ? active.band : '') }, [picked]) // eslint-disable-line

  if (!d) return <Loading error={error} />

  const priced = rows.filter((r) => r.mid > 0)
  const island = priced.length ? sumBy(priced, (r) => r.mid) / priced.length : 0
  const perD = Object.fromEntries(rows.filter((r) => r.district).map((r) => [r.district, r.mid]))
  const lowest = priced.length ? [...priced].sort((a, b) => a.mid - b.mid)[0] : null
  const highest = priced.length ? [...priced].sort((a, b) => b.mid - a.mid)[0] : null
  const inScope = (r) => !sel.province || r.province === sel.province
  const here = rows.filter((r) => inScope(r) && (!sel.district || r.district === sel.district))
  const bars = [...here].filter((r) => r.mid > 0).sort((a, b) => b.mid - a.mid).map((r) => ({ name: r.name, Low: r.lo, High: r.hi }))

  const pick = (name) => {
    setPicked(name === picked ? null : name)
    const r = rows.find((x) => x.name === name)
    if (r && r.district && name !== picked) setSel({ province: r.province, district: r.district })
  }
  const onSel = (s) => {
    setSel(s)
    if (s.district) {
      const r = rows.find((x) => x.district === s.district)
      setPicked(r ? r.name : null)
    } else {
      setPicked(null)
    }
  }
  const shift = (delta) => {
    const [lo, hi] = nums(draft)
    setDraft(bandText(Math.max(0, lo + delta), Math.max(0, hi + delta)))
  }
  const publish = async () => {
    if (!active) return
    setSaving(true)
    try { await onPublish(active.name, draft) } finally { setSaving(false) }
  }
  const [dlo, dhi] = nums(draft)
  const dmid = (dlo + dhi) / 2
  const changed = active && draft.trim() !== String(active.band).trim()

  const table = [...here].sort((a, b) => b.mid - a.mid).map((r) => [
    <button key={r.name} type="button" className="an-lid" onClick={() => pick(r.name)}>{r.name}</button>,
    r.province, r.band, r.lo, r.hi, r.mid ? `${r.mid >= island ? '+' : '-'}${Math.abs(((r.mid - island) / (island || 1)) * 100).toFixed(1)}%` : '-', r.buyers ?? 0, r.estates ?? 0, `${r.radius ?? 3} km`,
  ])
  const sections = () => [
    { title: `Coconut price bands - ${scopeName(sel)}`, columns: ['District', 'Province', 'Band', 'Low (Rs)', 'High (Rs)', 'Mid (Rs)', 'Buyers', 'Estates', 'Radius (km)'], rows: [...here].sort((a, b) => b.mid - a.mid).map((r) => [r.name, r.province, r.band, r.lo, r.hi, r.mid, r.buyers ?? 0, r.estates ?? 0, r.radius ?? 3]) },
  ]

  return (
    <RegionSlot.Provider value={null}>
      <PageHead title="Product setup" sub="The price band shown to buyers and owners in every district" name="Product setup" sel={sel} onSel={setSel} sections={sections}>
        <PhotoRow
          items={[
            ['koku_nagula', 'pin', 'green', 'Districts with a band', num(priced.length), `of ${num(DISTRICTS.length)} districts`],
            ['rotary', 'tag', 'blue', 'Island average', rs0(island), 'middle of the bands'],
            ['disc_plough', 'trophy', 'amber', 'Highest', highest ? highest.name : '-', highest ? highest.band : ''],
            ['slasher', 'scale', 'brown', 'Lowest', lowest ? lowest.name : '-', lowest ? lowest.band : ''],
          ]}
        />
        <Split
          map={
            <Card title="Coconut price bands" sub="The number on each district is the middle of its band. Click a district to edit it." className="an-card-map">
              <DrillMap geo={d.geo} values={perD} fmt={rs0} unit="a nut" sel={sel} onSel={onSel} agg="avg" scale={GREENS} height={560} badge={BAND_BADGE} noSub />
            </Card>
          }
          side={
            <>
              <Card title={active ? `${active.name} price band` : 'Edit a price band'} sub={active ? `${active.province} Province` : 'Click a district on the map, or a name in the table'}>
                {active ? (
                  <div className="an-ps">
                    <label className="an-ps-label">
                      Price band
                      <input className="an-search" value={draft} onChange={(e) => setDraft(e.target.value)} placeholder="e.g. Rs. 110 – 135" />
                    </label>
                    <div className="an-ps-steps">
                      <button type="button" className="an-more" onClick={() => shift(-5)}>-5</button>
                      <button type="button" className="an-more" onClick={() => shift(-1)}>-1</button>
                      <button type="button" className="an-more" onClick={() => shift(1)}>+1</button>
                      <button type="button" className="an-more" onClick={() => shift(5)}>+5</button>
                    </div>
                    <div className="an-ps-stats">
                      <div><small>Now</small><b>{active.band}</b></div>
                      <div><small>New middle</small><b>{rs0(dmid)}</b></div>
                      <div><small>Island average</small><b>{rs0(island)}</b></div>
                      <div><small>Against the average</small><b>{island ? `${dmid >= island ? '+' : '-'}${Math.abs(((dmid - island) / island) * 100).toFixed(1)}%` : '-'}</b></div>
                      <div><small>Buyers</small><b>{num(active.buyers ?? 0)}</b></div>
                      <div><small>Estates</small><b>{num(active.estates ?? 0)}</b></div>
                    </div>
                    <div className="an-fixbtns" style={{ marginTop: 12 }}>
                      <button type="button" className="an-fixbtn ok" disabled={!changed || saving} onClick={publish}>{saving ? 'Publishing...' : 'Publish this band'}</button>
                      <button type="button" className="an-fixbtn" onClick={() => setDraft(active.band)}>Undo</button>
                    </div>
                    <p className="an-hint" style={{ textAlign: 'left' }}>Publishing saves the band and shows it to buyers and owners in {active.name}.</p>
                  </div>
                ) : (
                  <p className="an-empty">No district picked yet.</p>
                )}
              </Card>
              <Card title="Low and high by district" sub={sel.province ? sel.province + ' Province' : 'Every district, highest first'}>
                <Bars data={bars} keys={['Low', 'High']} colors={['#a9cdb7', '#256b45']} horizontal height={Math.max(220, bars.length * 30)} nameWidth={96} fmt={compact} />
              </Card>
            </>
          }
        />
        <Card title="All district bands" sub={`${here.length} districts · ${scopeName(sel)}. Click a name to edit its band.`}>
          <DataTable columns={['District', 'Province', 'Band', 'Low (Rs)', 'High (Rs)', 'Against average', 'Buyers', 'Estates', 'Radius']} rows={table} limit={10} />
        </Card>
      </PageHead>
    </RegionSlot.Provider>
  )
}

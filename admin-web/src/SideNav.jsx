import { useState } from 'react'
import { MENU, menuOf } from './menu'

// 24x24 line icons, one per group and per page.
const ICONS = {
  land: 'M12 21V10m0 0C12 6 9 4 5 4c0 4 2 6 7 6Zm0 3c0-3 2.5-5 7-5 0 4-2.5 6-7 6M4 21h16',
  community: 'M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20M10 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm10 8v-1.5a3.5 3.5 0 0 0-2.5-3.3M15.5 5.2a3.5 3.5 0 0 1 0 6.6',
  resources: 'M21 8 12 3 3 8v8l9 5 9-5V8ZM3 8l9 5m0 0 9-5m-9 5v8',
  marketplace: 'M4 9l1.5-5h13L20 9M4 9v11h16V9M4 9c0 1.7 1.3 3 3 3s3-1.3 3-3c0 1.7 1.3 3 3 3s3-1.3 3-3c0 1.7 1.3 3 3 3',
  platform: 'M4 7h9m4 0h3M4 17h3m4 0h9M15 4v6M9 14v6',
  'an-overview': 'M12 21s7-5.5 7-11a7 7 0 0 0-14 0c0 5.500 7 11 7 11Zm0-8.500a2.500 2.500 0 1 0 0-5 2.500 2.500 0 0 0 0 5Z',
  'soon-cultivation-type': 'M12 21v-8m0 0c0-3 2-5 6-5 0 3-2 5-6 5Zm0 2c0-2.500-1.500-4-5-4 0 2.500 1.500 4 5 4Z',
  'soon-agri-tourism': 'M3 20 12 5l9 15H3Zm9 0v-6',
  'soon-aquaculture': 'M3 12c3-5 8-6 12-3l4-2v10l-4-2c-4 3-9 2-12-3Zm10-1h.01',
  'soon-animal-husbandry': 'M5 8c0-2 1-3 3-3h8c2 0 3 1 3 3v5c0 3-2 5-7 5s-7-2-7-5V8Zm4 5h.01M15 13h.01',
  'soon-green-energy': 'M13 3 5 14h6l-1 7 8-11h-6l1-7Z',
  'soon-environment': 'M12 3s6 6 6 11a6 6 0 0 1-12 0c0-5 6-11 6-11Z',
  'an-owners': 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 9a7 7 0 0 1 14 0',
  'an-workers': 'M16 20v-1.5a3.5 3.5 0 0 0-3.5-3.5h-5A3.5 3.5 0 0 0 4 18.5V20M10 12a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm10 8v-1.5a3.5 3.5 0 0 0-2.5-3.3M15.5 5.2a3.5 3.5 0 0 1 0 6.6',
  'an-suppliers': 'M3 7h11v9H3zM14 10h4l3 3v3h-7M7 19.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Zm10 0a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z',
  'an-clients': 'M5 8h14l-1 12H6L5 8Zm4 0a3 3 0 0 1 6 0',
  'an-fert': 'M9 3h6M10 3v6L5 19a1.5 1.5 0 0 0 1.300 2h11.400a1.500 1.500 0 0 0 1.300-2l-5-10V3',
  'an-mach': 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm0-12v3m0 12v3M3 12h3m12 0h3M5.600 5.600l2.100 2.100m8.600 8.600 2.100 2.100M18.400 5.600l-2.100 2.100M7.700 16.300l-2.100 2.100',
  'soon-instruments': 'M14.500 6.500a4 4 0 0 0 5 5L11 20a2 2 0 0 1-3-3l8.500-8.500',
  'soon-irrigation': 'M12 3s5 5 5 9a5 5 0 0 1-10 0c0-4 5-9 5-9ZM4 21h16',
  'soon-guns': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm0-5a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM12 2v4m0 12v4M2 12h4m12 0h4',
  'soon-planting-materials': 'M5 19c0-8 5-14 14-14 0 9-6 14-14 14Zm0 0 7-7',
  'soon-chemicals': 'M8 3h8M9 3v5l-4 9a2 2 0 0 0 2 3h10a2 2 0 0 0 2-3l-4-9V3M7 14h10',
  orders: 'M9 4h6v3H9V4ZM9 5H6v16h12V5h-3M9 13h6m-6 4h4',
  deal: 'M4 12l4-4 4 3 4-3 4 4-8 8-8-8Z',
  transactions: 'M7 4 3 8l4 4M3 8h14m0 4 4 4-4 4m4-4H7',
  disputes: 'M12 3 2 20h20L12 3Zm0 7v5m0 3h.01',
  'an-sales': 'M3 17l6-6 4 4 8-9M15 6h6v6',
  users: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-7 9a7 7 0 0 1 14 0',
  'soon-error-correction': 'M4 20h4L19 9l-4-4L4 16v4Zm9-13 4 4',
  regions: 'M4 7h9m4 0h3M4 17h3m4 0h9M15 4v6M9 14v6',
  'soon-audit-trail': 'M12 7v5l3 2m6-2a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z',
  reports: 'M7 3h8l4 4v14H7V3Zm8 0v4h4M10 12h6m-6 4h6',
  settings: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm7.400-3a7.400 7.400 0 0 0-.1-1.200l2-1.600-2-3.400-2.400 1a7 7 0 0 0-2-1.200L14.500 3h-4l-.4 2.500a7 7 0 0 0-2 1.200l-2.400-1-2 3.400 2 1.600a7.400 7.400 0 0 0 0 2.400l-2 1.600 2 3.400 2.400-1a7 7 0 0 0 2 1.200l.4 2.500h4l.4-2.500a7 7 0 0 0 2-1.200l2.400 1 2-3.400-2-1.600c.1-.4.100-.8.100-1.200Z',
  help: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Zm-2.500-12a2.500 2.500 0 1 1 3.500 2.300c-.7.4-1 1-1 1.700M12 17h.01',
}

const Icon = ({ name, size = 20 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d={ICONS[name] || 'M12 12h.01'} />
  </svg>
)

const Chevron = ({ open }) => (
  <svg className={`sn-chev ${open ? 'open' : ''}`} width="14" height="14" viewBox="0 0 12 12" aria-hidden="true">
    <path d="M2.5 4.5 6 8l3.5-3.5" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
  </svg>
)

export const initialsOf = (name = '') =>
  name.trim().split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0].toUpperCase()).join('') || 'A'

export default function SideNav({ view, setView, badgeFor, user, logout, collapsed, setCollapsed, drawer, setDrawer }) {
  const active = menuOf(view)
  const [openId, setOpenId] = useState(active || 'land')
  const countOf = (m) => m.items.reduce((n, [id]) => n + (badgeFor(id) || 0), 0)

  const toggle = (id) => {
    if (collapsed) {
      setCollapsed(false)
      setOpenId(id)
    } else {
      setOpenId(openId === id ? null : id)
    }
  }
  const go = (id) => {
    setView(id)
    setDrawer(false)
  }

  return (
    <>
      {drawer && <div className="sn-scrim" onClick={() => setDrawer(false)} />}
      <aside className={`sn ${collapsed ? 'collapsed' : ''} ${drawer ? 'drawer-open' : ''}`}>
        <div className="sn-brand">
          <div className="sn-logo"><img src="/logo.png" alt="KapConnect" /></div>
          {!collapsed && <small>Admin Analysis</small>}
        </div>

        <nav className="sn-nav" aria-label="Main">
          {MENU.map((m) => {
            const open = !collapsed && openId === m.id
            return (
              <div key={m.id} className="sn-group">
                <button
                  className={`sn-main ${active === m.id ? 'active' : ''}`}
                  aria-expanded={open}
                  title={collapsed ? m.label : undefined}
                  onClick={() => toggle(m.id)}
                >
                  <Icon name={m.id} />
                  {!collapsed && (
                    <>
                      <span>{m.label}</span>
                      {countOf(m) > 0 && <span className="adm-badge">{countOf(m)}</span>}
                      <Chevron open={open} />
                    </>
                  )}
                </button>
                {open && (
                  <div className="sn-subs">
                    {m.items.map(([id, label]) => (
                      <button key={id} className={`sn-sub ${view === id ? 'active' : ''}`} onClick={() => go(id)}>
                        <Icon name={id} size={16} />
                        <span>{label}</span>
                        {badgeFor(id) > 0 && <span className="adm-badge">{badgeFor(id)}</span>}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )
          })}
        </nav>

        <div className="sn-foot">
          {[['settings', 'Settings'], ['help', 'Help']].map(([id, label]) => (
            <button
              key={id}
              className={`sn-main sn-small ${view === id ? 'active' : ''}`}
              title={collapsed ? label : undefined}
              onClick={() => go(id)}
            >
              <Icon name={id} size={18} />
              {!collapsed && <span>{label}</span>}
            </button>
          ))}

          <div className="sn-user">
            <div className="sn-avatar" title={user.name}>{initialsOf(user.name)}</div>
            {!collapsed && (
              <>
                <div className="sn-who">
                  <b>{user.name}</b>
                  <small>Administrator</small>
                </div>
                <button type="button" className="sn-out" onClick={logout} title="Sign out" aria-label="Sign out">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4m7 14 5-5-5-5m5 5H9" />
                  </svg>
                </button>
              </>
            )}
          </div>

          <button type="button" className="sn-collapse" onClick={() => setCollapsed(!collapsed)}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" style={{ transform: collapsed ? 'rotate(180deg)' : 'none' }}>
              <path d="m15 6-6 6 6 6" />
            </svg>
            {!collapsed && 'Collapse sidebar'}
          </button>
        </div>
      </aside>
    </>
  )
}

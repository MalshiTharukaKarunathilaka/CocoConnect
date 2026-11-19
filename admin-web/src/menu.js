// The five main menus. Items with a real page use its view id; the rest use a
// 'soon-' id and show a placeholder until their data exists.
export const MENU = [
  {
    id: 'land',
    label: 'Land',
    items: [
      ['an-overview', 'Cultivation Footprint', 'Estates, acres and palms on the map'],
      ['soon-cultivation-type', 'Cultivation Type', 'Crops grown across estates'],
      ['soon-agri-tourism', 'Agri Tourism', 'Estate visits and tourism income'],
      ['soon-aquaculture', 'Aquaculture', 'Fish and prawn farming'],
      ['soon-animal-husbandry', 'Animal Husbandry', 'Livestock on estates'],
      ['soon-green-energy', 'Green Energy', 'Solar and biogas use'],
      ['soon-environment', 'Environment', 'Rainfall, soil and climate'],
    ],
  },
  {
    id: 'community',
    label: 'Community',
    items: [
      ['an-owners', 'Owner Demography', 'Who owns the land, by age and gender'],
      ['an-workers', 'Employee Demography', 'Day workers by district'],
      ['an-suppliers', 'Supplier Demography', 'Machinery and fertilizer suppliers'],
      ['an-clients', 'Client Demography', 'Buyers of coconuts and husks'],
    ],
  },
  {
    id: 'resources',
    label: 'Resources',
    items: [
      ['an-fert', 'Fertilizer', 'Donations and usage by district'],
      ['an-mach', 'Machinery', 'Machines, prices and availability'],
      ['an-finance', 'Financial Products', 'Loans, insurance and carbon credits'],
      ['soon-instruments', 'Instruments', 'Tools and instruments'],
      ['soon-irrigation', 'Irrigation Equipment', 'Pumps, pipes and sprinklers'],
      ['soon-guns', 'Guns', 'Spray and other guns'],
      ['soon-planting-materials', 'Planting Materials', 'Seedlings and plants'],
      ['soon-chemicals', 'Chemicals', 'Pesticides and chemicals'],
    ],
  },
  {
    id: 'subsidies',
    label: 'Subsidies',
    direct: 'an-subsidies', // opens its page straight away, no sub-menu
    items: [['an-subsidies', 'Subsidies', 'Fertilizer, machinery and other farm inputs']],
  },
  {
    id: 'marketplace',
    label: 'Marketplace',
    items: [
      ['deal', 'Deals', 'Offers being negotiated'],
      ['orders', 'Orders', 'Machinery and service orders'],
      ['transactions', 'Transactions', 'Completed payments'],
      ['disputes', 'Dispute Management', 'Open and resolved disputes'],
    ],
  },
  {
    id: 'platform',
    label: 'Platform',
    items: [
      ['users', 'User Management', 'Users and verification'],
      ['soon-error-correction', 'Error Correction', 'Fix wrong records'],
      ['regions', 'Product Setup', 'Add the products shown in the mobile app'],
      ['prices', 'Price Bands', 'Coconut price band of each district'],
      ['soon-audit-trail', 'Audit Trail', 'Who changed what'],
      ['reports', 'Reports', 'Summary and export'],
    ],
  },
]

// Views that belong to a menu even though they are not listed in it.
const EXTRA = { verify: 'platform' }

export const menuOf = (view) =>
  MENU.find((m) => m.items.some(([id]) => id === view))?.id || EXTRA[view]

const FOOTER_LABELS = { settings: 'Settings', help: 'Help' }

export const itemLabel = (view) => {
  if (FOOTER_LABELS[view]) return FOOTER_LABELS[view]
  for (const m of MENU) {
    const hit = m.items.find(([id]) => id === view)
    if (hit) return hit[1]
  }
  return null
}


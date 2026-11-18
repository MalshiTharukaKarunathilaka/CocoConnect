# KapConnect Admin Dashboard: Requirements and Features Built

Branch: `admin-dashboard-reordered-senuji`. Stack: React 19 + Vite (`admin-web`), Node/Express API (`backend`, port 5000), dashboard on port 5174.

This document lists what the admin dashboard was asked to do and what has been built. The last section is honest about which numbers are real and which are sample data.

---

## 1. Purpose

A web dashboard for KapConnect administrators to see the whole coconut sector in Sri Lanka in one place: land, people, farm inputs, the marketplace and the platform itself. Everything can be explored on a map of Sri Lanka and drilled down from province to district to CDO (Coconut Development Officer) area.

---

## 2. Navigation structure (sidebar)

| Menu | Pages |
|---|---|
| **Land** | Cultivation Footprint, Cultivation Type, Agri Tourism, Aquaculture, Animal Husbandry, Green Energy, Environment |
| **Community** | Owner Demography, Employee Demography, Supplier Demography, Client Demography |
| **Resources** | Fertilizer, Machinery, Financial Products, Subsidies, plus placeholders for Instruments, Irrigation Equipment, Guns, Planting Materials, Chemicals |
| **Marketplace** | Orders, Deals, Transactions, Dispute Management |
| **Platform** | User Management, Error Correction, Product Setup, Audit Trail, Reports |

Each menu has its own icon, and a page title and short description appear under each item.

---

## 3. Requirements and what was delivered

### 3.1 Map and drill-down (shared by many pages)

| Requirement | Delivered |
|---|---|
| Map of Sri Lanka with drill-down province, district and CDO area | Interactive map with badges, markers and sub-areas; click to go deeper |
| Show a CDO office on the map when drilled to a CDO | A house icon marks each CDO office, labelled **"CDO office"** only (no area name) |
| Illustrated, recognisable pins instead of plain dots | Pin icons drawn for coconut, peanut, bank, shield, coin, wrench, spray gun, flask and gift |
| Map with two characters (people) for demographic views | Owner, Supplier and Client demography use a map with two characters on the left and age and gender charts on the right |

### 3.2 Land

**Cultivation Footprint (coconut only)**
- Shows coconut land only, with two pie charts, a land-type breakdown and a tree-age histogram.
- **Land types** are named and ordered: Non-systematic cultivation, Systematic cultivation, Institutional plantation.
- **Tree age histogram** uses 5-year bins (0-5, 5-10 and so on) with the number of trees in each bin. Picking a land type updates the histogram.
- Life-stage tree pictures sit beside the histogram (young, growing, mature, aged), with proper stage names rather than just age numbers.
- Pie charts are taller so the pictures read clearly.
- **Registered lands table:**
  - Land ID is a hyperlink. Hovering shows a small card near the cursor.
  - Clicking opens an owner private-details popup: gender, religion, date of birth, NIC, passport, mobile, home and estate address, estate GPS.
  - Columns for CDO region and CDO area, and an Orders column (some lands have more than 2 orders).
  - Search, filters and CSV export.

**Cultivation Type**
- The same page layout as Footprint, with a crop picker for Coconut, Pepper, Pineapple and Peanut.
- A **"Land by crop" pie** sits after the land-type pie and follows the selected land type.
- A peanut icon was added (made smaller, from the supplied image).

**Agri Tourism, Aquaculture, Animal Husbandry**: pages built with their own stats and charts.

**Green Energy, Environment**: placeholder pages (see section 5).

### 3.3 Community

| Page | Delivered |
|---|---|
| **Owner Demography** | Stat cards for land-type stats only. Chips per land type. Split layout: map plus age and gender pies. Stats change with the chosen land type. |
| **Supplier Demography** | Same split format, with machine-type and fertilizer-type chips. |
| **Client Demography** | Same split format, with product chips (coconuts, husks). |
| **Employee Demography** | Same split format, without the CDO drill-down, with fewer sample workers. |

All four have consistent map format and alignment.

### 3.4 Resources

**Fertilizer** (normal supplier fertilizer sales, no donation stats)
- Cards: fertilizer sold, revenue, orders, farmers, with real fertilizer-related photos.
- Metric switcher, province strip, brand and estate views, CDO map.
- Table with search, filters and export.

**Machinery**: machines, prices and availability, with machinery icons.

**Financial Products** has tabs for Loans, Insurance and Carbon credits, each with its own stats, map and table.

**Subsidies**
- Funding-source cards first, then subsidy-type selection. Cards scroll smoothly (no scroll bar).
- Funding sources, in order: Government Budget Allocation, World Bank, Asian Development Bank, Global Environment Facility, Green Climate Fund, Government of Japan, Government of Australia, Russian Government. Each has a plain-language description.
- Tabs: All, Fertilizer, Machinery, Instruments, Irrigation Equipment, Guns, Planting Materials, Chemicals.
- Every tab uses the same "donation" page format, and the Fertilizer tab shows "By donation".
- The All tab has its own icon, and the cards use real photos.

### 3.5 Marketplace

Orders, Deals, Transactions and Dispute Management, plus marketplace prices, a dispute tracker and a price map (these use the live backend).

### 3.6 Platform

| Page | Delivered |
|---|---|
| **User Management** | Users and verification. |
| **Product Setup** | New page with a Sri Lanka map. Shows each region's price band (low to high), midpoint shading on the map, an edit panel (plus or minus 1 and 5, Publish), low and high bars and a table. **Publish saves to the real backend.** |
| **Audit Trail** | Who changed what: filterable log table, search and CSV export. |
| **Error Correction** | Queue of wrong records: Fix and Reject actions and a ticket detail popup. |
| **Reports** | Summary and export. |

Stat cards at the top of Audit Trail and Error Correction were removed at the user's request.

### 3.7 Tables (system-wide requirement)

Every data table has: **search, column filters, and CSV export**.

### 3.8 Visual and UX requirements

- Real, suitable photos on the KPI cards (Fertilizer and Subsidies), with credits in `admin-web/public/photos/ATTRIBUTION.txt`.
- Consistent design system (see `DESIGN_SYSTEM.md`).
- Sales calendar with holidays.
- Cards use smooth scrolling instead of a scroll bar.

---

## 4. Backend support

- Express API with auth, admin, owner, buyer, listing and chat routes.
- SQL migrations 001 to 008 (users and negotiations, estate owners, order fulfilment, user coordinates, chat offers, price disputes, offer chats, admin extensions).
- Admin endpoints used by the dashboard include `/admin/regions` and `PUT /admin/regions/band` (Product Setup).

---

## 5. Known limitations and honest status

| Area | Status |
|---|---|
| Product Setup bands, regions, buyers and estates | **Real data** from the backend and database |
| Marketplace pages (Orders, Deals, Transactions, Disputes), users | Backed by the live API |
| Most Land, Community and Resources analysis numbers (footprint, tree age, demography, subsidies, finance, fertilizer) | **Sample data** (seeded or generated) shaped like real data, not from the database yet |
| Audit Trail and Error Correction | Pages are built with sample rows. They are not yet connected to real change logging |
| Green Energy, Environment, Instruments, Irrigation Equipment, Guns, Planting Materials, Chemicals | Placeholder "coming soon" pages |
| Photos | Wikimedia Commons stand-ins, many not Sri Lankan. They can be swapped for the project's own photos |
| Some estate names show a doubled "Estate Estate" | Not yet fixed |

---

## 6. How to run

```powershell
# API
cd D:\Cococonnect\CocoConnect-admin\backend
node server.js            # port 5000

# Dashboard
cd D:\Cococonnect\CocoConnect-admin\admin-web
npx vite --port 5174 --host 127.0.0.1
```

Open http://127.0.0.1:5174.

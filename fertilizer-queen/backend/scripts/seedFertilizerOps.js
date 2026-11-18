/**
 * Seed demo fertilizer users + operational rows into Supabase.
 * Usage: node scripts/seedFertilizerOps.js
 */
require("dotenv").config({ path: require("path").join(__dirname, "../.env") });
const bcrypt = require("bcryptjs");
const { Pool } = require("pg");
const fs = require("fs");
const path = require("path");

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.DATABASE_SSL === "false"
      ? false
      : { rejectUnauthorized: false },
});

async function ensureUser({ name, phone, role, location, lat, lng }) {
  const existing = await pool.query(
    "SELECT id FROM public.users WHERE phone = $1",
    [phone]
  );
  const hash = await bcrypt.hash("demo123", 10);
  if (existing.rows[0]) {
    await pool.query(
      `UPDATE public.users
       SET name=$2, password_hash=$3, role=$4, location=$5, latitude=$6, longitude=$7
       WHERE id=$1`,
      [existing.rows[0].id, name, hash, role, location, lat, lng]
    );
    return existing.rows[0].id;
  }
  const inserted = await pool.query(
    `INSERT INTO public.users (name, phone, password_hash, role, location, latitude, longitude)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
    [name, phone, hash, role, location, lat, lng]
  );
  return inserted.rows[0].id;
}

async function main() {
  const sql = fs.readFileSync(
    path.join(__dirname, "../sql/013_fertilizer_ops.sql"),
    "utf8"
  );
  await pool.query(sql);
  console.log("schema 013 applied");

  const ownerId = await ensureUser({
    name: "Nushrath Silva",
    phone: "0712000011",
    role: "ESTATE_OWNER",
    location: "Colombo",
    lat: 6.9271,
    lng: 79.8612,
  });
  const supplierId = await ensureUser({
    name: "Ravi Jayasuriya",
    phone: "0772100001",
    role: "FERTILIZER_SUPPLIER",
    location: "Colombo",
    lat: 6.935,
    lng: 79.87,
  });
  const cdoId = await ensureUser({
    name: "CDO Colombo",
    phone: "0772300001",
    role: "CDO",
    location: "Colombo",
    lat: 6.93,
    lng: 79.865,
  });
  console.log("users", { ownerId, supplierId, cdoId });

  await pool.query(
    `INSERT INTO fertilizer_suppliers
      (user_id, shop_name, identity_number, email, district, radius_km, willing_far,
       shop_type, brands, coverage_note)
     VALUES ($1,'Colombo Agro Mart','861234567V','ravi@colomboagro.lk','Colombo',5,false,
       'Physical shop','CIC, Baurs','Near Kaduwela / Colombo estates')
     ON CONFLICT (user_id) DO UPDATE SET
       shop_name = EXCLUDED.shop_name,
       brands = EXCLUDED.brands,
       coverage_note = EXCLUDED.coverage_note`,
    [supplierId]
  );

  await pool.query(
    `INSERT INTO cdo_officers
      (user_id, identity_number, email, employee_id, designation, regional_office,
       assigned_district, assigned_divisional_areas)
     VALUES ($1,'900123456V','cdo.colombo@ccb.gov.lk','CDO-CMB-01',
       'Coconut Development Officer','Western Province Regional Office',
       'Colombo','Kaduwela, Kolonnawa, Homagama')
     ON CONFLICT (user_id) DO UPDATE SET
       assigned_district = EXCLUDED.assigned_district,
       assigned_divisional_areas = EXCLUDED.assigned_divisional_areas`,
    [cdoId]
  );

  // Replace demo ops rows for the Colombo trio.
  await pool.query(
    `DELETE FROM fertilizer_orders WHERE id LIKE 'PO-61%' OR place_id = 'PL-CMB-1'`
  );
  await pool.query(
    `DELETE FROM fertilizer_gov_requests WHERE id LIKE 'FR-COL-%'`
  );
  await pool.query(
    `DELETE FROM fertilizer_shop_talks WHERE place_id = 'PL-CMB-1'`
  );
  await pool.query(
    `DELETE FROM fertilizer_complaints WHERE id = 'QC-COL-301'`
  );

  const itemsUrea = [
    {
      name: "CIC Urea",
      brand: "CIC",
      type: "Urea",
      price: 5950,
      unit: "50 kg bag",
      stock: 24,
      qty50: 8,
    },
  ];
  const itemsYpm = [
    {
      name: "Baurs YPM",
      brand: "Baurs",
      type: "YPM",
      price: 6900,
      unit: "50 kg bag",
      stock: 12,
      qty50: 5,
    },
  ];

  const orders = [
    {
      id: "PO-610",
      place_id: "PL-CMB-1",
      owner_key: "Colombo Palm Estate",
      product: "CIC Urea (50 kg)",
      qty50: 8,
      price: 47600,
      preferred_date: "2026-11-19",
      slot: "Morning 8–11",
      status: "Pending Ack",
      message: "Need urea for the Kaduwela block this week.",
      items: itemsUrea.map((i) => ({ ...i, qty50: 8 })),
      negotiation: [],
    },
    {
      id: "PO-611",
      place_id: "PL-CMB-1",
      owner_key: "Colombo Palm Estate",
      product: "Baurs YPM (50 kg)",
      qty50: 5,
      price: 34500,
      preferred_date: "2026-11-20",
      slot: "Afternoon 12–3",
      status: "Negotiating",
      message: "Can you do a better price for 5 bags?",
      items: itemsYpm,
      negotiation: [
        {
          from: "You",
          text: "Can you do Rs. 6,500 / bag for Baurs YPM?",
          time: "10:05",
        },
        {
          from: "Colombo Agro Mart",
          text: "I can do Rs. 6,700 if you take 5 bags this week.",
          time: "10:12",
        },
      ],
    },
    {
      id: "PO-612",
      place_id: "PL-CMB-1",
      owner_key: "Colombo Palm Estate",
      product: "CIC Urea (50 kg)",
      qty50: 4,
      price: 23800,
      preferred_date: "2026-11-18",
      slot: "Morning 8–11",
      status: "Accepted",
      message: "Accepted · awaiting delivery",
      items: itemsUrea.map((i) => ({ ...i, qty50: 4 })),
      negotiation: [],
    },
    {
      id: "PO-613",
      place_id: "PL-CMB-1",
      owner_key: "Colombo Palm Estate",
      product: "Baurs YPM (50 kg)",
      qty50: 3,
      price: 20700,
      preferred_date: "2026-11-15",
      slot: "Morning 8–11",
      status: "Distributed",
      message: "Marked delivered · waiting for owner to confirm",
      items: itemsYpm.map((i) => ({ ...i, qty50: 3 })),
      negotiation: [],
    },
    {
      id: "PO-614",
      place_id: "PL-CMB-1",
      owner_key: "Colombo Palm Estate",
      product: "CIC Urea (50 kg)",
      qty50: 10,
      price: 59500,
      preferred_date: "2026-11-10",
      slot: "Afternoon 12–3",
      status: "Completed",
      message: "Owner confirmed receipt · order completed",
      items: itemsUrea.map((i) => ({ ...i, qty50: 10 })),
      negotiation: [],
      owner_stars: 5,
      supplier_stars: 4,
      owner_rate_note: "On time and bags were sealed.",
      supplier_rate_note: "Clear instructions and easy access.",
    },
  ];

  for (const o of orders) {
    await pool.query(
      `INSERT INTO fertilizer_orders (
        id, place_id, owner_key, owner_user_id, supplier_user_id, company, agent,
        product, qty50, price, preferred_date, slot, status, message, items,
        negotiation, owner_stars, supplier_stars, owner_rate_note, supplier_rate_note
      ) VALUES (
        $1,$2,$3,$4,$5,'Colombo Agro Mart','Ravi Jayasuriya',$6,$7,$8,$9,$10,$11,$12,
        $13::jsonb,$14::jsonb,$15,$16,$17,$18
      )`,
      [
        o.id,
        o.place_id,
        o.owner_key,
        ownerId,
        supplierId,
        o.product,
        o.qty50,
        o.price,
        o.preferred_date,
        o.slot,
        o.status,
        o.message,
        JSON.stringify(o.items),
        JSON.stringify(o.negotiation),
        o.owner_stars ?? null,
        o.supplier_stars ?? null,
        o.owner_rate_note || "",
        o.supplier_rate_note || "",
      ]
    );
  }

  await pool.query(
    `INSERT INTO fertilizer_shop_talks (place_id, owner_key, messages, unread_supplier)
     VALUES ($1,$2,$3::jsonb,2)`,
    [
      "PL-CMB-1",
      "Colombo Palm Estate",
      JSON.stringify([
        {
          from: "You",
          text: "Hi Ravi — what colour are the CIC bags, and your phone number?",
          time: "9:40",
        },
        {
          from: "Colombo Agro Mart",
          text: "Green and white bags. Call 077 210 0001 anytime.",
          time: "9:45",
        },
        {
          from: "You",
          text: "Can you deliver 8 × CIC Urea on 19 Nov morning?",
          time: "9:50",
        },
        {
          from: "Colombo Agro Mart",
          text: "Yes — I can confirm after you place the order.",
          time: "9:55",
        },
        {
          from: "You",
          text: "Also looking at Baurs YPM — can you do a better price for 5 bags?",
          time: "10:05",
        },
      ]),
    ]
  );

  const govs = [
    {
      id: "FR-COL-2001",
      status: "Pending Ack",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 10,
      approved: 0,
      distributed: 0,
      date: "2026-11-17",
      preferred: "17 Nov 2026 · Morning",
      chat: [
        {
          from: "Colombo Palm Estate",
          text: "Submitted Annex 01 for 10 bags of ERP for Kaduwela block.",
          time: "17 Nov · 09:05",
        },
      ],
    },
    {
      id: "FR-COL-2002",
      status: "Negotiation",
      fertilizer: "Urea subsidy (50 kg)",
      requested: 6,
      approved: 6,
      distributed: 0,
      date: "2026-11-14",
      preferred: "14 Nov 2026 · Afternoon",
      chat: [
        {
          from: "Colombo Palm Estate",
          text: "Can we collect urea on 21 Nov afternoon?",
          time: "14 Nov · 11:20",
        },
        {
          from: "CDO - Colombo",
          text: "Checking stock at CCB. Can you take morning instead?",
          time: "14 Nov · 15:40",
        },
      ],
    },
    {
      id: "FR-COL-2003",
      status: "Accepted",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 8,
      approved: 8,
      distributed: 0,
      date: "2026-11-08",
      preferred: "08 Nov 2026 · Morning",
      delivery_at: "2026-11-19T10:30:00Z",
      chat: [
        {
          from: "CDO - Colombo",
          text: "Accepted. Delivery on 19 Nov at 10:30 AM.",
          time: "09 Nov · 10:12",
        },
      ],
    },
    {
      id: "FR-COL-2004",
      status: "Distributed",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 12,
      approved: 12,
      distributed: 12,
      date: "2026-10-28",
      preferred: "28 Oct 2026 · Morning",
      chat: [
        {
          from: "CDO - Colombo",
          text: "Marked as delivered · please confirm you received the 12 bags.",
          time: "05 Nov · 11:20",
        },
      ],
    },
    {
      id: "FR-COL-2005",
      status: "Receipt Confirmed",
      fertilizer: "Urea subsidy (50 kg)",
      requested: 5,
      approved: 5,
      distributed: 5,
      date: "2026-10-05",
      preferred: "05 Oct 2026 · Morning",
      chat: [
        {
          from: "Colombo Palm Estate",
          text: "Bags received in good condition. Thank you.",
          time: "12 Oct · 10:05",
        },
      ],
    },
    {
      id: "FR-COL-2006",
      status: "Cancelled",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 4,
      approved: 0,
      distributed: 0,
      date: "2026-09-18",
      preferred: "18 Sep 2026 · Afternoon",
      chat: [
        {
          from: "CDO - Colombo",
          text: "Cancelled · land title scan was unclear. Please re-upload.",
          time: "19 Sep · 09:40",
        },
      ],
    },
  ];

  for (const g of govs) {
    await pool.query(
      `INSERT INTO fertilizer_gov_requests (
        id, owner_key, owner_user_id, cdo_user_id, cdo_label, fertilizer,
        requested, approved, distributed, status, district, request_date,
        delivery_at, preferred, outlet, estate_name, acres, beneficiary_name,
        address, phone, nic_number, land_address, deed_number, coconut_trees,
        coconut_saplings, annual_harvest_nuts, chat
      ) VALUES (
        $1,'Colombo Palm Estate',$2,$3,'CDO - Colombo',$4,$5,$6,$7,$8,'Colombo',$9,
        $10,$11,'CCB','Colombo Palm Estate',6,'Nushrath Silva',
        '42 Marine Drive, Colombo 03','0712000011','199012345678',
        'Colombo Palm Estate, Kaduwela, Colombo','COL/KDW/2020/1188',480,60,28000,$12::jsonb
      )`,
      [
        g.id,
        ownerId,
        cdoId,
        g.fertilizer,
        g.requested,
        g.approved,
        g.distributed,
        g.status,
        g.date,
        g.delivery_at || null,
        g.preferred,
        JSON.stringify(g.chat),
      ]
    );
  }

  await pool.query(
    `INSERT INTO fertilizer_complaints (
      id, owner_key, owner_user_id, category, product, status, description, district, complaint_date
    ) VALUES (
      'QC-COL-301','Colombo Palm Estate',$1,'Product quality','CIC Urea (50 kg)',
      'Submitted','One bag from PO-614 had a torn seal. Rest were fine.','Colombo','2026-11-12'
    )`,
    [ownerId]
  );

  console.log("seed complete");
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

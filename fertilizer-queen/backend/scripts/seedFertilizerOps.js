/**
 * Seed all fertilizer demo users + cross-role ops rows into Supabase.
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

async function upsertSupplier(userId, row) {
  await pool.query(
    `INSERT INTO fertilizer_suppliers
      (user_id, shop_name, identity_number, email, district, radius_km, willing_far,
       shop_type, brands, coverage_note)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     ON CONFLICT (user_id) DO UPDATE SET
       shop_name = EXCLUDED.shop_name,
       identity_number = EXCLUDED.identity_number,
       email = EXCLUDED.email,
       district = EXCLUDED.district,
       radius_km = EXCLUDED.radius_km,
       willing_far = EXCLUDED.willing_far,
       shop_type = EXCLUDED.shop_type,
       brands = EXCLUDED.brands,
       coverage_note = EXCLUDED.coverage_note`,
    [
      userId,
      row.shop,
      row.nic,
      row.email,
      row.district,
      row.radius,
      row.willingFar,
      row.shopType || "Physical shop",
      row.brands,
      row.note,
    ]
  );
}

async function upsertCdo(userId, row) {
  await pool.query(
    `INSERT INTO cdo_officers
      (user_id, identity_number, email, employee_id, designation, regional_office,
       assigned_district, assigned_divisional_areas, id_card_filename, employment_doc_filename)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
     ON CONFLICT (user_id) DO UPDATE SET
       identity_number = EXCLUDED.identity_number,
       email = EXCLUDED.email,
       employee_id = EXCLUDED.employee_id,
       designation = EXCLUDED.designation,
       regional_office = EXCLUDED.regional_office,
       assigned_district = EXCLUDED.assigned_district,
       assigned_divisional_areas = EXCLUDED.assigned_divisional_areas,
       id_card_filename = EXCLUDED.id_card_filename,
       employment_doc_filename = EXCLUDED.employment_doc_filename`,
    [
      userId,
      row.nic,
      row.email,
      row.employeeId,
      row.designation || "Coconut Development Officer",
      row.office,
      row.district,
      row.areas,
      row.idCard || "ccb_id_card.pdf",
      row.employment || "appointment_letter.pdf",
    ]
  );
}

async function insertOrder(o) {
  await pool.query(
    `INSERT INTO fertilizer_orders (
      id, place_id, owner_key, owner_user_id, supplier_user_id, company, agent,
      product, qty50, price, preferred_date, slot, status, message, items,
      negotiation, owner_stars, supplier_stars, owner_rate_note, supplier_rate_note
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15::jsonb,$16::jsonb,$17,$18,$19,$20
    )
    ON CONFLICT (id) DO UPDATE SET
      status = EXCLUDED.status,
      message = EXCLUDED.message,
      negotiation = EXCLUDED.negotiation,
      owner_stars = EXCLUDED.owner_stars,
      supplier_stars = EXCLUDED.supplier_stars,
      updated_at = now()`,
    [
      o.id,
      o.place_id,
      o.owner_key,
      o.owner_user_id,
      o.supplier_user_id,
      o.company,
      o.agent,
      o.product,
      o.qty50,
      o.price,
      o.preferred_date,
      o.slot,
      o.status,
      o.message,
      JSON.stringify(o.items || []),
      JSON.stringify(o.negotiation || []),
      o.owner_stars ?? null,
      o.supplier_stars ?? null,
      o.owner_rate_note || "",
      o.supplier_rate_note || "",
    ]
  );
}

async function insertGov(g) {
  await pool.query(
    `INSERT INTO fertilizer_gov_requests (
      id, owner_key, owner_user_id, cdo_user_id, cdo_label, fertilizer,
      requested, approved, distributed, status, district, request_date,
      delivery_at, preferred, outlet, estate_name, acres, beneficiary_name,
      address, phone, nic_number, land_address, deed_number, coconut_trees,
      coconut_saplings, annual_harvest_nuts, chat
    ) VALUES (
      $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,'CCB',$15,$16,$17,
      $18,$19,$20,$21,$22,$23,$24,$25,$26::jsonb
    )
    ON CONFLICT (id) DO UPDATE SET
      status = EXCLUDED.status,
      approved = EXCLUDED.approved,
      distributed = EXCLUDED.distributed,
      chat = EXCLUDED.chat,
      updated_at = now()`,
    [
      g.id,
      g.owner_key,
      g.owner_user_id,
      g.cdo_user_id,
      g.cdo_label,
      g.fertilizer,
      g.requested,
      g.approved || 0,
      g.distributed || 0,
      g.status,
      g.district,
      g.date,
      g.delivery_at || null,
      g.preferred,
      g.estate_name || g.owner_key,
      g.acres || 6,
      g.beneficiary_name,
      g.address || "",
      g.phone,
      g.nic_number || "",
      g.land_address || "",
      g.deed_number || "",
      g.coconut_trees || 400,
      g.coconut_saplings || 40,
      g.annual_harvest_nuts || 20000,
      JSON.stringify(g.chat || []),
    ]
  );
}

async function main() {
  const sql = fs.readFileSync(
    path.join(__dirname, "../sql/013_fertilizer_ops.sql"),
    "utf8"
  );
  await pool.query(sql);
  console.log("schema 013 applied");

  // --- Owners ---
  const nushId = await ensureUser({
    name: "Nushrath Silva",
    phone: "0712000011",
    role: "ESTATE_OWNER",
    location: "Colombo",
    lat: 6.9271,
    lng: 79.8612,
  });
  const kamalId = await ensureUser({
    name: "Kamal Fernando",
    phone: "0712000022",
    role: "ESTATE_OWNER",
    location: "Puttalam",
    lat: 8.0362,
    lng: 79.8283,
  });
  const demoOwnerId = await ensureUser({
    name: "Demo Estate Owner",
    phone: "0711000001",
    role: "ESTATE_OWNER",
    location: "Kurunegala",
    lat: 7.4863,
    lng: 80.3647,
  });

  // --- Colombo suppliers ---
  const colomboShops = [
    {
      phone: "0772100001",
      name: "Ravi Jayasuriya",
      shop: "Colombo Agro Mart",
      place: "PL-CMB-1",
      nic: "861234567V",
      email: "ravi@colomboagro.lk",
      brands: "CIC, Baurs",
      note: "Near Kaduwela / Colombo estates",
      lat: 6.935,
      lng: 79.87,
    },
    {
      phone: "0772100002",
      name: "Sithara Perera",
      shop: "Green Leaf Colombo",
      place: "PL-CMB-2",
      nic: "905678901V",
      email: "sithara@greenleaf.lk",
      brands: "Hayleys",
      note: "Colombo south delivery",
      lat: 6.915,
      lng: 79.88,
    },
    {
      phone: "0772100003",
      name: "Nuwan Dias",
      shop: "CIC Point Colombo",
      place: "PL-CMB-3",
      nic: "882345678V",
      email: "nuwan@cicpoint.lk",
      brands: "CIC",
      note: "Willing to go farther",
      willingFar: true,
      lat: 6.945,
      lng: 79.85,
    },
    {
      phone: "0772100004",
      name: "Malsha Fernando",
      shop: "Baurs Depot Colombo",
      place: "PL-CMB-4",
      nic: "917890123V",
      email: "malsha@baursdepot.lk",
      brands: "Baurs",
      note: "Depot near Battaramulla",
      lat: 6.9,
      lng: 79.89,
    },
    {
      phone: "0772100005",
      name: "Ishara Gunasekara",
      shop: "Hayleys Colombo Hub",
      place: "PL-CMB-5",
      nic: "875432109V",
      email: "ishara@hayleyshub.lk",
      brands: "Hayleys, CIC",
      note: "Hub for Colombo estates",
      lat: 6.96,
      lng: 79.87,
    },
  ];
  const colomboSupplierIds = {};
  for (const s of colomboShops) {
    const id = await ensureUser({
      name: s.name,
      phone: s.phone,
      role: "FERTILIZER_SUPPLIER",
      location: "Colombo",
      lat: s.lat,
      lng: s.lng,
    });
    colomboSupplierIds[s.place] = { id, ...s };
    await upsertSupplier(id, {
      shop: s.shop,
      nic: s.nic,
      email: s.email,
      district: "Colombo",
      radius: 5,
      willingFar: !!s.willingFar,
      brands: s.brands,
      note: s.note,
    });
  }

  // --- Puttalam suppliers ---
  const puttalamShops = [
    {
      phone: "0772200001",
      name: "Asanka Silva",
      shop: "Puttalam Fertilizer",
      place: "PL-PUT-1",
      nic: "841111222V",
      email: "asanka@putfert.lk",
      brands: "CIC",
      note: "Chilaw / Puttalam coast",
      lat: 8.04,
      lng: 79.83,
    },
    {
      phone: "0772200002",
      name: "Dilani Jay",
      shop: "Chilaw Agro",
      place: "PL-PUT-2",
      nic: "926666777V",
      email: "dilani@chilawagro.lk",
      brands: "Baurs, Hayleys",
      note: "Chilaw town",
      lat: 7.58,
      lng: 79.8,
    },
    {
      phone: "0772200003",
      name: "Ruwan Perera",
      shop: "Coastline Supplies",
      place: "PL-PUT-3",
      nic: "873333444V",
      email: "ruwan@coastline.lk",
      brands: "CIC, Baurs",
      note: "Coast delivery",
      lat: 8.02,
      lng: 79.84,
    },
    {
      phone: "0772200004",
      name: "Nimali Fernando",
      shop: "Palm Care Puttalam",
      place: "PL-PUT-4",
      nic: "914444555V",
      email: "nimali@palmcare.lk",
      brands: "Hayleys",
      note: "Palm estates",
      lat: 8.05,
      lng: 79.82,
    },
    {
      phone: "0772200005",
      name: "Kasun Bandara",
      shop: "Wennappuwa Agro",
      place: "PL-PUT-5",
      nic: "865555666V",
      email: "kasun@wennagro.lk",
      brands: "CIC",
      note: "Wennappuwa / Marawila",
      lat: 7.35,
      lng: 79.84,
    },
  ];
  const puttalamSupplierIds = {};
  for (const s of puttalamShops) {
    const id = await ensureUser({
      name: s.name,
      phone: s.phone,
      role: "FERTILIZER_SUPPLIER",
      location: "Puttalam",
      lat: s.lat,
      lng: s.lng,
    });
    puttalamSupplierIds[s.place] = { id, ...s };
    await upsertSupplier(id, {
      shop: s.shop,
      nic: s.nic,
      email: s.email,
      district: "Puttalam",
      radius: 5,
      willingFar: false,
      brands: s.brands,
      note: s.note,
    });
  }

  // Mawathagama supplier
  const nadeeshaId = await ensureUser({
    name: "Nadeesha Perera",
    phone: "0771112233",
    role: "FERTILIZER_SUPPLIER",
    location: "Kurunegala",
    lat: 7.498,
    lng: 80.356,
  });
  await upsertSupplier(nadeeshaId, {
    shop: "Nadeesha Stores",
    nic: "851234567V",
    email: "nadeesha@stores.lk",
    district: "Kurunegala",
    radius: 5,
    willingFar: false,
    brands: "CIC, Baurs",
    note: "Mawathagama town",
  });

  // --- CDOs ---
  const cdoColomboId = await ensureUser({
    name: "CDO Colombo",
    phone: "0772300001",
    role: "CDO",
    location: "Colombo",
    lat: 6.93,
    lng: 79.865,
  });
  await upsertCdo(cdoColomboId, {
    nic: "900123456V",
    email: "cdo.colombo@ccb.gov.lk",
    employeeId: "CDO-CMB-01",
    office: "Western Province Regional Office",
    district: "Colombo",
    areas: "Kaduwela, Kolonnawa, Homagama",
  });

  const cdoPuttalamId = await ensureUser({
    name: "CDO Puttalam",
    phone: "0772300002",
    role: "CDO",
    location: "Puttalam",
    lat: 8.035,
    lng: 79.83,
  });
  await upsertCdo(cdoPuttalamId, {
    nic: "880987654V",
    email: "cdo.puttalam@ccb.gov.lk",
    employeeId: "CDO-PUT-01",
    office: "North Western Regional Office",
    district: "Puttalam",
    areas: "Chilaw, Wennappuwa, Puttalam",
  });

  const cdoMawatId = await ensureUser({
    name: "CDO Mawathagama",
    phone: "0372223344",
    role: "CDO",
    location: "Kurunegala",
    lat: 7.54,
    lng: 80.4,
  });
  await upsertCdo(cdoMawatId, {
    nic: "791112223V",
    email: "cdo.mawathagama@ccb.gov.lk",
    employeeId: "CDO-KUR-01",
    office: "North Western Regional Office",
    district: "Kurunegala",
    areas: "Mawathagama, Narammala, Polgahawela",
  });

  console.log("users + profiles ready");

  // Clear previous demo ops, then reseed linked data.
  await pool.query(
    `DELETE FROM fertilizer_orders WHERE id LIKE 'PO-%' OR id LIKE 'PO-M%' OR id LIKE 'PO-P%'`
  );
  await pool.query(
    `DELETE FROM fertilizer_gov_requests WHERE id LIKE 'FR-COL-%' OR id LIKE 'FR-PUT-%' OR id LIKE 'FR-KUR-%' OR id LIKE 'FR-1099' OR id LIKE 'FR-110%'`
  );
  await pool.query(`DELETE FROM fertilizer_shop_talks`);
  await pool.query(
    `DELETE FROM fertilizer_complaints WHERE id LIKE 'QC-%' OR id LIKE 'DP-%'`
  );

  const ravi = colomboSupplierIds["PL-CMB-1"];
  const green = colomboSupplierIds["PL-CMB-2"];
  const put1 = puttalamSupplierIds["PL-PUT-1"];

  // Colombo owner ↔ Colombo Agro Mart (full lifecycle)
  const colomboOrders = [
    {
      id: "PO-610",
      place_id: "PL-CMB-1",
      status: "Pending Ack",
      product: "CIC Urea (50 kg)",
      qty50: 8,
      price: 47600,
      preferred_date: "2026-11-19",
      slot: "Morning 8–11",
      message: "Need urea for Kaduwela block",
    },
    {
      id: "PO-611",
      place_id: "PL-CMB-1",
      status: "Negotiating",
      product: "Baurs YPM (50 kg)",
      qty50: 5,
      price: 34500,
      preferred_date: "2026-11-20",
      slot: "Afternoon 12–3",
      message: "Can you do a better price?",
      negotiation: [
        { from: "You", text: "Can you do Rs. 6,500 / bag?", time: "10:05" },
        {
          from: "Colombo Agro Mart",
          text: "I can do Rs. 6,700 for 5 bags this week.",
          time: "10:12",
        },
      ],
    },
    {
      id: "PO-612",
      place_id: "PL-CMB-1",
      status: "Accepted",
      product: "CIC Urea (50 kg)",
      qty50: 4,
      price: 23800,
      preferred_date: "2026-11-18",
      slot: "Morning 8–11",
      message: "Accepted · awaiting delivery",
    },
    {
      id: "PO-613",
      place_id: "PL-CMB-1",
      status: "Distributed",
      product: "Baurs YPM (50 kg)",
      qty50: 3,
      price: 20700,
      preferred_date: "2026-11-15",
      slot: "Morning 8–11",
      message: "Marked delivered · waiting for owner to confirm",
    },
    {
      id: "PO-614",
      place_id: "PL-CMB-1",
      status: "Completed",
      product: "CIC Urea (50 kg)",
      qty50: 10,
      price: 59500,
      preferred_date: "2026-11-10",
      slot: "Afternoon 12–3",
      message: "Owner confirmed receipt · order completed",
      owner_stars: 5,
      supplier_stars: 4,
      owner_rate_note: "On time and bags were sealed.",
      supplier_rate_note: "Clear instructions and easy access.",
    },
    {
      id: "PO-615",
      place_id: "PL-CMB-2",
      status: "Pending Ack",
      product: "Hayleys Organic (25 kg)",
      qty50: 6,
      price: 31200,
      preferred_date: "2026-11-22",
      slot: "Morning 8–11",
      message: "Trying Green Leaf for organic bags",
      company: "Green Leaf Colombo",
      agent: "Sithara Perera",
      supplier_user_id: green.id,
    },
  ];

  for (const o of colomboOrders) {
    await insertOrder({
      ...o,
      owner_key: "Colombo Palm Estate",
      owner_user_id: nushId,
      supplier_user_id: o.supplier_user_id || ravi.id,
      company: o.company || "Colombo Agro Mart",
      agent: o.agent || "Ravi Jayasuriya",
      items: [
        {
          name: o.product.split(" (")[0],
          brand: "CIC",
          type: "Urea",
          price: Math.round(o.price / o.qty50),
          unit: "50 kg bag",
          stock: 20,
          qty50: o.qty50,
        },
      ],
    });
  }

  await pool.query(
    `INSERT INTO fertilizer_shop_talks (place_id, owner_key, messages, unread_supplier)
     VALUES ($1,$2,$3::jsonb,2)
     ON CONFLICT (place_id, owner_key) DO UPDATE SET messages = EXCLUDED.messages, unread_supplier = 2`,
    [
      "PL-CMB-1",
      "Colombo Palm Estate",
      JSON.stringify([
        {
          from: "You",
          text: "Hi Ravi — bag colour and phone number?",
          time: "9:40",
        },
        {
          from: "Colombo Agro Mart",
          text: "Green/white bags. Call 077 210 0001.",
          time: "9:45",
        },
        {
          from: "You",
          text: "Can you deliver 8 × CIC Urea on 19 Nov morning?",
          time: "9:50",
        },
      ]),
    ]
  );

  // Puttalam owner ↔ Puttalam Fertilizer
  for (const o of [
    {
      id: "PO-P10",
      status: "Pending Ack",
      product: "CIC Urea (50 kg)",
      qty50: 7,
      price: 41650,
      preferred_date: "2026-11-21",
      message: "Coast block urea request",
    },
    {
      id: "PO-P11",
      status: "Accepted",
      product: "Baurs Coconut Blend (50 kg)",
      qty50: 4,
      price: 28000,
      preferred_date: "2026-11-18",
      message: "Accepted · awaiting delivery",
    },
    {
      id: "PO-P12",
      status: "Distributed",
      product: "CIC Urea (50 kg)",
      qty50: 5,
      price: 29750,
      preferred_date: "2026-11-12",
      message: "Delivered · confirm receipt",
    },
    {
      id: "PO-P13",
      status: "Completed",
      product: "Hayleys Dolomite (50 kg)",
      qty50: 8,
      price: 19200,
      preferred_date: "2026-11-05",
      message: "Completed",
      owner_stars: 4,
      supplier_stars: 5,
    },
  ]) {
    await insertOrder({
      ...o,
      place_id: "PL-PUT-1",
      owner_key: "Puttalam Coast Estate",
      owner_user_id: kamalId,
      supplier_user_id: put1.id,
      company: "Puttalam Fertilizer",
      agent: "Asanka Silva",
      slot: "Morning 8–11",
      items: [],
      negotiation: [],
    });
  }

  await pool.query(
    `INSERT INTO fertilizer_shop_talks (place_id, owner_key, messages, unread_supplier)
     VALUES ('PL-PUT-1','Puttalam Coast Estate',$1::jsonb,1)
     ON CONFLICT (place_id, owner_key) DO UPDATE SET messages = EXCLUDED.messages, unread_supplier = 1`,
    [
      JSON.stringify([
        {
          from: "You",
          text: "Do you deliver to Chilaw coast estates?",
          time: "8:10",
        },
        {
          from: "Puttalam Fertilizer",
          text: "Yes — morning slots this week.",
          time: "8:22",
        },
      ]),
    ]
  );

  // Mawathagama owner ↔ Nadeesha
  for (const o of [
    {
      id: "PO-M01",
      status: "Pending Ack",
      product: "CIC Urea (50 kg)",
      qty50: 6,
      price: 35400,
      preferred_date: "2026-11-19",
      message: "Temple road block",
    },
    {
      id: "PO-M02",
      status: "Accepted",
      product: "Baurs YPM (50 kg)",
      qty50: 4,
      price: 27600,
      preferred_date: "2026-11-17",
      message: "Accepted",
    },
    {
      id: "PO-M03",
      status: "Completed",
      product: "CIC Urea (50 kg)",
      qty50: 10,
      price: 59000,
      preferred_date: "2026-11-08",
      message: "Completed",
      owner_stars: 5,
      supplier_stars: 5,
    },
  ]) {
    await insertOrder({
      ...o,
      place_id: "PL4",
      owner_key: "Mawathagama Palm Estate",
      owner_user_id: demoOwnerId,
      supplier_user_id: nadeeshaId,
      company: "Nadeesha Stores",
      agent: "Nadeesha Perera",
      slot: "Morning 8–11",
      items: [],
      negotiation: [],
    });
  }

  // Gov requests per CDO ↔ matching estate
  const govRows = [
    {
      id: "FR-COL-2001",
      owner_key: "Colombo Palm Estate",
      owner_user_id: nushId,
      cdo_user_id: cdoColomboId,
      cdo_label: "CDO - Colombo",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 10,
      status: "Pending Ack",
      district: "Colombo",
      date: "2026-11-17",
      preferred: "17 Nov 2026 · Morning",
      beneficiary_name: "Nushrath Silva",
      phone: "0712000011",
      chat: [
        {
          from: "Colombo Palm Estate",
          text: "Submitted Annex 01 for 10 bags.",
          time: "17 Nov · 09:05",
        },
      ],
    },
    {
      id: "FR-COL-2002",
      owner_key: "Colombo Palm Estate",
      owner_user_id: nushId,
      cdo_user_id: cdoColomboId,
      cdo_label: "CDO - Colombo",
      fertilizer: "Urea subsidy (50 kg)",
      requested: 6,
      approved: 6,
      status: "Negotiation",
      district: "Colombo",
      date: "2026-11-14",
      preferred: "14 Nov 2026 · Afternoon",
      beneficiary_name: "Nushrath Silva",
      phone: "0712000011",
      chat: [
        {
          from: "CDO - Colombo",
          text: "Can you take morning instead?",
          time: "14 Nov · 15:40",
        },
      ],
    },
    {
      id: "FR-COL-2003",
      owner_key: "Colombo Palm Estate",
      owner_user_id: nushId,
      cdo_user_id: cdoColomboId,
      cdo_label: "CDO - Colombo",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 8,
      approved: 8,
      status: "Accepted",
      district: "Colombo",
      date: "2026-11-08",
      preferred: "08 Nov 2026 · Morning",
      delivery_at: "2026-11-19T10:30:00Z",
      beneficiary_name: "Nushrath Silva",
      phone: "0712000011",
      chat: [],
    },
    {
      id: "FR-COL-2004",
      owner_key: "Colombo Palm Estate",
      owner_user_id: nushId,
      cdo_user_id: cdoColomboId,
      cdo_label: "CDO - Colombo",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 12,
      approved: 12,
      distributed: 12,
      status: "Distributed",
      district: "Colombo",
      date: "2026-10-28",
      preferred: "28 Oct 2026 · Morning",
      beneficiary_name: "Nushrath Silva",
      phone: "0712000011",
      chat: [
        {
          from: "CDO - Colombo",
          text: "Marked delivered · please confirm.",
          time: "05 Nov · 11:20",
        },
      ],
    },
    {
      id: "FR-COL-2005",
      owner_key: "Colombo Palm Estate",
      owner_user_id: nushId,
      cdo_user_id: cdoColomboId,
      cdo_label: "CDO - Colombo",
      fertilizer: "Urea subsidy (50 kg)",
      requested: 5,
      approved: 5,
      distributed: 5,
      status: "Receipt Confirmed",
      district: "Colombo",
      date: "2026-10-05",
      preferred: "05 Oct 2026 · Morning",
      beneficiary_name: "Nushrath Silva",
      phone: "0712000011",
      chat: [],
    },
    {
      id: "FR-PUT-3001",
      owner_key: "Puttalam Coast Estate",
      owner_user_id: kamalId,
      cdo_user_id: cdoPuttalamId,
      cdo_label: "CDO - Puttalam",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 14,
      status: "Pending Ack",
      district: "Puttalam",
      date: "2026-11-16",
      preferred: "16 Nov 2026 · Morning",
      beneficiary_name: "Kamal Fernando",
      phone: "0712000022",
      acres: 10,
      chat: [
        {
          from: "Puttalam Coast Estate",
          text: "New Annex 01 for coast block.",
          time: "16 Nov · 10:00",
        },
      ],
    },
    {
      id: "FR-PUT-3002",
      owner_key: "Puttalam Coast Estate",
      owner_user_id: kamalId,
      cdo_user_id: cdoPuttalamId,
      cdo_label: "CDO - Puttalam",
      fertilizer: "Urea subsidy (50 kg)",
      requested: 9,
      approved: 9,
      status: "Accepted",
      district: "Puttalam",
      date: "2026-11-09",
      preferred: "09 Nov 2026 · Afternoon",
      delivery_at: "2026-11-20T14:00:00Z",
      beneficiary_name: "Kamal Fernando",
      phone: "0712000022",
      acres: 10,
      chat: [],
    },
    {
      id: "FR-PUT-3003",
      owner_key: "Puttalam Coast Estate",
      owner_user_id: kamalId,
      cdo_user_id: cdoPuttalamId,
      cdo_label: "CDO - Puttalam",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 11,
      approved: 11,
      distributed: 11,
      status: "Distributed",
      district: "Puttalam",
      date: "2026-10-22",
      preferred: "22 Oct 2026 · Morning",
      beneficiary_name: "Kamal Fernando",
      phone: "0712000022",
      acres: 10,
      chat: [],
    },
    {
      id: "FR-KUR-4001",
      owner_key: "Mawathagama Palm Estate",
      owner_user_id: demoOwnerId,
      cdo_user_id: cdoMawatId,
      cdo_label: "CDO - Mawathagama",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 12,
      status: "Pending Ack",
      district: "Kurunegala",
      date: "2026-11-08",
      preferred: "08 Nov 2026 · Morning",
      beneficiary_name: "Demo Estate Owner",
      phone: "0711000001",
      acres: 8,
      chat: [],
    },
    {
      id: "FR-KUR-4002",
      owner_key: "Mawathagama Palm Estate",
      owner_user_id: demoOwnerId,
      cdo_user_id: cdoMawatId,
      cdo_label: "CDO - Mawathagama",
      fertilizer: "Urea subsidy (50 kg)",
      requested: 8,
      approved: 8,
      status: "Accepted",
      district: "Kurunegala",
      date: "2026-11-05",
      preferred: "05 Nov 2026 · Morning",
      delivery_at: "2026-11-18T10:00:00Z",
      beneficiary_name: "Demo Estate Owner",
      phone: "0711000001",
      acres: 8,
      chat: [],
    },
    {
      id: "FR-KUR-4003",
      owner_key: "Mawathagama Palm Estate",
      owner_user_id: demoOwnerId,
      cdo_user_id: cdoMawatId,
      cdo_label: "CDO - Mawathagama",
      fertilizer: "ERP Coconut Fertilizer (50 kg)",
      requested: 20,
      approved: 20,
      distributed: 20,
      status: "Receipt Confirmed",
      district: "Kurunegala",
      date: "2026-10-12",
      preferred: "12 Oct 2026 · Morning",
      beneficiary_name: "Demo Estate Owner",
      phone: "0711000001",
      acres: 8,
      chat: [],
    },
  ];
  for (const g of govRows) await insertGov(g);

  await pool.query(
    `INSERT INTO fertilizer_complaints (
      id, owner_key, owner_user_id, category, product, status, description, district, complaint_date
    ) VALUES
      ('QC-COL-301','Colombo Palm Estate',$1,'Product quality','CIC Urea (50 kg)','Submitted','One bag from PO-614 had a torn seal.','Colombo','2026-11-12'),
      ('QC-PUT-301','Puttalam Coast Estate',$2,'Delivery delay','CIC Urea (50 kg)','Under Review','Late afternoon delivery.','Puttalam','2026-11-11'),
      ('QC-KUR-301','Mawathagama Palm Estate',$3,'Product quality','ERP Coconut Fertilizer','Submitted','Sample complaint for demo.','Kurunegala','2026-10-16')
    ON CONFLICT (id) DO NOTHING`,
    [nushId, kamalId, demoOwnerId]
  );

  console.log("seed complete — all regional trios linked");
  await pool.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

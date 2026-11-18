const pool = require("../config/db");
const { storageInfo } = require("./healthController");

const last9 = (phone) => {
  const digits = String(phone || "").replace(/\D/g, "");
  if (!digits) return "";
  return digits.length > 9 ? digits.slice(-9) : digits;
};

const chatFromJson = (value) => {
  if (!Array.isArray(value)) return [];
  return value.map((m) => ({
    from: String(m.from || m.from_label || ""),
    text: String(m.text || ""),
    time: String(m.time || m.time_label || ""),
  }));
};

const mapOrder = (row) => ({
  id: row.id,
  place_id: row.place_id,
  owner: row.owner_key,
  company: row.company,
  agent: row.agent,
  product: row.product,
  qty50: Number(row.qty50) || 0,
  price: Number(row.price) || 0,
  preferred_date: row.preferred_date,
  slot: row.slot || "",
  status: row.status,
  message: row.message || "",
  items: row.items || [],
  negotiation: chatFromJson(row.negotiation),
  owner_stars: row.owner_stars,
  supplier_stars: row.supplier_stars,
  owner_rate_note: row.owner_rate_note || "",
  supplier_rate_note: row.supplier_rate_note || "",
  updated_at: row.updated_at,
});

const mapGov = (row) => ({
  id: row.id,
  owner: row.owner_key,
  fertilizer: row.fertilizer,
  requested: Number(row.requested) || 0,
  approved: Number(row.approved) || 0,
  distributed: Number(row.distributed) || 0,
  status: row.status,
  cdo: row.cdo_label,
  date: row.request_date,
  district: row.district || "",
  delivery_at: row.delivery_at,
  preferred: row.preferred || "",
  outlet: row.outlet || "CCB",
  estate_name: row.estate_name || "",
  acres: row.acres == null ? null : Number(row.acres),
  nic_copy: row.nic_copy || "",
  land_title_copy: row.land_title_copy || "",
  beneficiary_name: row.beneficiary_name || "",
  address: row.address || "",
  phone: row.phone || "",
  nic_number: row.nic_number || "",
  land_address: row.land_address || "",
  deed_number: row.deed_number || "",
  coconut_trees: row.coconut_trees,
  coconut_saplings: row.coconut_saplings,
  annual_harvest_nuts: row.annual_harvest_nuts,
  chat: chatFromJson(row.chat),
  updated_at: row.updated_at,
});

const mapComplaint = (row) => ({
  id: row.id,
  owner: row.owner_key,
  category: row.category,
  product: row.product,
  status: row.status,
  description: row.description || "",
  district: row.district || "",
  date: row.complaint_date,
  updated_at: row.updated_at,
});

const mapAlert = (row) => ({
  id: row.id,
  audience: row.audience,
  title: row.title,
  body: row.body || "",
  kind: row.kind || "info",
  order_id: row.order_id,
  read: !!row.read,
  at: row.created_at,
});

const mapTalk = (row) => ({
  place_id: row.place_id,
  owner_key: row.owner_key || "",
  messages: chatFromJson(row.messages),
  unread_supplier: Number(row.unread_supplier) || 0,
  updated_at: row.updated_at,
});

async function findUser(req) {
  const result = await pool.query(
    "SELECT id, name, phone, role, location FROM public.users WHERE id = $1",
    [req.user.id]
  );
  return result.rows[0] || null;
}

async function ownerKeyFor(user) {
  // Match Flutter demoOwnerProfiles estate names by phone.
  const map = {
    "712000011": "Colombo Palm Estate",
    "712000022": "Puttalam Coast Estate",
    "711000001": "Mawathagama Palm Estate",
  };
  const key = map[last9(user.phone)];
  if (key) return key;
  return `${user.name}'s Estate`;
}

async function supplierPlaceIds(userId) {
  const profile = await pool.query(
    "SELECT shop_name FROM fertilizer_suppliers WHERE user_id = $1",
    [userId]
  );
  const shopName = profile.rows[0]?.shop_name || "";
  // Known demo place ids by shop name / phone binding on the client.
  const byName = {
    "Colombo Agro Mart": ["PL-CMB-1"],
    "Green Leaf Colombo": ["PL-CMB-2"],
    "CIC Point Colombo": ["PL-CMB-3"],
    "Baurs Depot Colombo": ["PL-CMB-4"],
    "Hayleys Colombo Hub": ["PL-CMB-5"],
    "Puttalam Fertilizer": ["PL-PUT-1"],
    "Chilaw Agro": ["PL-PUT-2"],
    "Coastline Supplies": ["PL-PUT-3"],
    "Palm Care Puttalam": ["PL-PUT-4"],
    "Wennappuwa Agro": ["PL-PUT-5"],
    "Nadeesha Stores": ["PL4"],
  };
  if (byName[shopName]) return byName[shopName];
  return [`PL-U-${userId}`];
}

async function cdoLabelFor(userId) {
  const profile = await pool.query(
    "SELECT assigned_district FROM cdo_officers WHERE user_id = $1",
    [userId]
  );
  const district = profile.rows[0]?.assigned_district || "";
  if (/colombo/i.test(district)) return "CDO - Colombo";
  if (/puttalam/i.test(district)) return "CDO - Puttalam";
  if (/kurunegala|mawathagama/i.test(district)) return "CDO - Mawathagama";
  const user = await pool.query("SELECT name FROM public.users WHERE id = $1", [
    userId,
  ]);
  return user.rows[0]?.name || "CDO";
}

/*
|--------------------------------------------------------------------------
| BOOTSTRAP — restore everything for the logged-in role
|--------------------------------------------------------------------------
*/
const bootstrap = async (req, res) => {
  try {
    const user = await findUser(req);
    if (!user) return res.status(401).json({ message: "Account not found" });

    let orders = [];
    let gov = [];
    let talks = [];
    let complaints = [];
    let alerts = [];

    if (user.role === "ESTATE_OWNER") {
      const ownerKey = await ownerKeyFor(user);
      const o = await pool.query(
        `SELECT * FROM fertilizer_orders
         WHERE owner_key = $1 OR owner_user_id = $2
         ORDER BY updated_at DESC`,
        [ownerKey, user.id]
      );
      orders = o.rows.map(mapOrder);
      const g = await pool.query(
        `SELECT * FROM fertilizer_gov_requests
         WHERE owner_key = $1 OR owner_user_id = $2 OR phone LIKE $3
         ORDER BY updated_at DESC`,
        [ownerKey, user.id, `%${last9(user.phone)}`]
      );
      gov = g.rows.map(mapGov);
      const t = await pool.query(
        `SELECT * FROM fertilizer_shop_talks WHERE owner_key = $1 OR owner_key = ''`,
        [ownerKey]
      );
      talks = t.rows.map(mapTalk);
      const c = await pool.query(
        `SELECT * FROM fertilizer_complaints
         WHERE owner_key = $1 OR owner_user_id = $2
         ORDER BY updated_at DESC`,
        [ownerKey, user.id]
      );
      complaints = c.rows.map(mapComplaint);
      const a = await pool.query(
        `SELECT * FROM fertilizer_alerts
         WHERE audience = 'owner' AND (user_id = $1 OR audience_key = $2)
         ORDER BY created_at DESC LIMIT 100`,
        [user.id, ownerKey]
      );
      alerts = a.rows.map(mapAlert);
      return res.json({
        storage: storageInfo(),
        role: user.role,
        owner_key: ownerKey,
        orders,
        gov_requests: gov,
        shop_talks: talks,
        complaints,
        alerts,
      });
    }

    if (user.role === "FERTILIZER_SUPPLIER") {
      const places = await supplierPlaceIds(user.id);
      const o = await pool.query(
        `SELECT * FROM fertilizer_orders
         WHERE place_id = ANY($1::text[]) OR supplier_user_id = $2
         ORDER BY updated_at DESC`,
        [places, user.id]
      );
      orders = o.rows.map(mapOrder);
      const t = await pool.query(
        `SELECT * FROM fertilizer_shop_talks WHERE place_id = ANY($1::text[])`,
        [places]
      );
      talks = t.rows.map(mapTalk);
      const a = await pool.query(
        `SELECT * FROM fertilizer_alerts
         WHERE audience = 'supplier' AND (user_id = $1 OR audience_key = ANY($2::text[]))
         ORDER BY created_at DESC LIMIT 100`,
        [user.id, places]
      );
      alerts = a.rows.map(mapAlert);
      return res.json({
        storage: storageInfo(),
        role: user.role,
        place_ids: places,
        orders,
        gov_requests: [],
        shop_talks: talks,
        complaints: [],
        alerts,
      });
    }

    if (user.role === "CDO") {
      const label = await cdoLabelFor(user.id);
      const g = await pool.query(
        `SELECT * FROM fertilizer_gov_requests
         WHERE cdo_label = $1 OR cdo_user_id = $2
         ORDER BY updated_at DESC`,
        [label, user.id]
      );
      gov = g.rows.map(mapGov);
      const a = await pool.query(
        `SELECT * FROM fertilizer_alerts
         WHERE audience = 'cdo' AND (user_id = $1 OR audience_key = $2)
         ORDER BY created_at DESC LIMIT 100`,
        [user.id, label]
      );
      alerts = a.rows.map(mapAlert);
      return res.json({
        storage: storageInfo(),
        role: user.role,
        cdo_label: label,
        orders: [],
        gov_requests: gov,
        shop_talks: [],
        complaints: [],
        alerts,
      });
    }

    return res.json({
      storage: storageInfo(),
      role: user.role,
      orders: [],
      gov_requests: [],
      shop_talks: [],
      complaints: [],
      alerts: [],
    });
  } catch (error) {
    console.error("fertilizer bootstrap:", error);
    return res.status(500).json({
      message: "Could not load fertilizer data",
      error: error.message,
    });
  }
};

/*
|--------------------------------------------------------------------------
| UPSERT helpers
|--------------------------------------------------------------------------
*/
const upsertOrder = async (req, res) => {
  try {
    const b = req.body || {};
    if (!b.id) return res.status(400).json({ message: "id is required" });
    const result = await pool.query(
      `INSERT INTO fertilizer_orders (
        id, place_id, owner_key, owner_user_id, supplier_user_id,
        company, agent, product, qty50, price, preferred_date, slot,
        status, message, items, negotiation, owner_stars, supplier_stars,
        owner_rate_note, supplier_rate_note, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15::jsonb,$16::jsonb,
        $17,$18,$19,$20, now()
      )
      ON CONFLICT (id) DO UPDATE SET
        place_id = EXCLUDED.place_id,
        owner_key = EXCLUDED.owner_key,
        owner_user_id = COALESCE(EXCLUDED.owner_user_id, fertilizer_orders.owner_user_id),
        supplier_user_id = COALESCE(EXCLUDED.supplier_user_id, fertilizer_orders.supplier_user_id),
        company = EXCLUDED.company,
        agent = EXCLUDED.agent,
        product = EXCLUDED.product,
        qty50 = EXCLUDED.qty50,
        price = EXCLUDED.price,
        preferred_date = EXCLUDED.preferred_date,
        slot = EXCLUDED.slot,
        status = EXCLUDED.status,
        message = EXCLUDED.message,
        items = EXCLUDED.items,
        negotiation = EXCLUDED.negotiation,
        owner_stars = EXCLUDED.owner_stars,
        supplier_stars = EXCLUDED.supplier_stars,
        owner_rate_note = EXCLUDED.owner_rate_note,
        supplier_rate_note = EXCLUDED.supplier_rate_note,
        updated_at = now()
      RETURNING *`,
      [
        String(b.id),
        String(b.place_id || b.placeId || ""),
        String(b.owner || b.owner_key || ""),
        b.owner_user_id || null,
        b.supplier_user_id || null,
        String(b.company || ""),
        String(b.agent || ""),
        String(b.product || ""),
        Number(b.qty50) || 0,
        Number(b.price) || 0,
        b.preferred_date || b.preferredDate || null,
        String(b.slot || ""),
        String(b.status || "Pending Ack"),
        String(b.message || ""),
        JSON.stringify(b.items || []),
        JSON.stringify(b.negotiation || []),
        b.owner_stars ?? b.ownerStars ?? null,
        b.supplier_stars ?? b.supplierStars ?? null,
        String(b.owner_rate_note || b.ownerRateNote || ""),
        String(b.supplier_rate_note || b.supplierRateNote || ""),
      ]
    );
    return res.json({ order: mapOrder(result.rows[0]) });
  } catch (error) {
    console.error("upsertOrder:", error);
    return res.status(500).json({ message: error.message });
  }
};

const upsertGov = async (req, res) => {
  try {
    const b = req.body || {};
    if (!b.id) return res.status(400).json({ message: "id is required" });
    const result = await pool.query(
      `INSERT INTO fertilizer_gov_requests (
        id, owner_key, owner_user_id, cdo_user_id, cdo_label, fertilizer,
        requested, approved, distributed, status, district, request_date,
        delivery_at, preferred, outlet, estate_name, acres, nic_copy,
        land_title_copy, beneficiary_name, address, phone, nic_number,
        land_address, deed_number, coconut_trees, coconut_saplings,
        annual_harvest_nuts, chat, updated_at
      ) VALUES (
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,
        $19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29::jsonb, now()
      )
      ON CONFLICT (id) DO UPDATE SET
        owner_key = EXCLUDED.owner_key,
        cdo_label = EXCLUDED.cdo_label,
        fertilizer = EXCLUDED.fertilizer,
        requested = EXCLUDED.requested,
        approved = EXCLUDED.approved,
        distributed = EXCLUDED.distributed,
        status = EXCLUDED.status,
        district = EXCLUDED.district,
        request_date = EXCLUDED.request_date,
        delivery_at = EXCLUDED.delivery_at,
        preferred = EXCLUDED.preferred,
        outlet = EXCLUDED.outlet,
        estate_name = EXCLUDED.estate_name,
        acres = EXCLUDED.acres,
        nic_copy = EXCLUDED.nic_copy,
        land_title_copy = EXCLUDED.land_title_copy,
        beneficiary_name = EXCLUDED.beneficiary_name,
        address = EXCLUDED.address,
        phone = EXCLUDED.phone,
        nic_number = EXCLUDED.nic_number,
        land_address = EXCLUDED.land_address,
        deed_number = EXCLUDED.deed_number,
        coconut_trees = EXCLUDED.coconut_trees,
        coconut_saplings = EXCLUDED.coconut_saplings,
        annual_harvest_nuts = EXCLUDED.annual_harvest_nuts,
        chat = EXCLUDED.chat,
        updated_at = now()
      RETURNING *`,
      [
        String(b.id),
        String(b.owner || b.owner_key || ""),
        b.owner_user_id || null,
        b.cdo_user_id || null,
        String(b.cdo || b.cdo_label || ""),
        String(b.fertilizer || ""),
        Number(b.requested) || 0,
        Number(b.approved) || 0,
        Number(b.distributed) || 0,
        String(b.status || "Pending Ack"),
        String(b.district || ""),
        b.date || b.request_date || null,
        b.delivery_at || b.deliveryAt || null,
        String(b.preferred || ""),
        String(b.outlet || "CCB"),
        String(b.estate_name || b.estateName || ""),
        b.acres ?? null,
        String(b.nic_copy || b.nicCopy || ""),
        String(b.land_title_copy || b.landTitleCopy || ""),
        String(b.beneficiary_name || b.beneficiaryName || ""),
        String(b.address || ""),
        String(b.phone || ""),
        String(b.nic_number || b.nicNumber || ""),
        String(b.land_address || b.landAddress || ""),
        String(b.deed_number || b.deedNumber || ""),
        b.coconut_trees ?? b.coconutTrees ?? null,
        b.coconut_saplings ?? b.coconutSaplings ?? null,
        b.annual_harvest_nuts ?? b.annualHarvestNuts ?? null,
        JSON.stringify(b.chat || []),
      ]
    );
    return res.json({ gov_request: mapGov(result.rows[0]) });
  } catch (error) {
    console.error("upsertGov:", error);
    return res.status(500).json({ message: error.message });
  }
};

const upsertShopTalk = async (req, res) => {
  try {
    const placeId = req.params.placeId || req.body.place_id;
    const ownerKey = String(req.body.owner_key || req.body.owner || "");
    if (!placeId) return res.status(400).json({ message: "placeId required" });
    const messages = req.body.messages || [];
    const unread = Number(req.body.unread_supplier ?? req.body.unread ?? 0);
    const result = await pool.query(
      `INSERT INTO fertilizer_shop_talks (place_id, owner_key, messages, unread_supplier, updated_at)
       VALUES ($1,$2,$3::jsonb,$4, now())
       ON CONFLICT (place_id, owner_key) DO UPDATE SET
         messages = EXCLUDED.messages,
         unread_supplier = EXCLUDED.unread_supplier,
         updated_at = now()
       RETURNING *`,
      [String(placeId), ownerKey, JSON.stringify(messages), unread]
    );
    return res.json({ shop_talk: mapTalk(result.rows[0]) });
  } catch (error) {
    console.error("upsertShopTalk:", error);
    return res.status(500).json({ message: error.message });
  }
};

const upsertComplaint = async (req, res) => {
  try {
    const b = req.body || {};
    if (!b.id) return res.status(400).json({ message: "id is required" });
    const result = await pool.query(
      `INSERT INTO fertilizer_complaints (
        id, owner_key, owner_user_id, category, product, status,
        description, district, complaint_date, updated_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, now())
      ON CONFLICT (id) DO UPDATE SET
        category = EXCLUDED.category,
        product = EXCLUDED.product,
        status = EXCLUDED.status,
        description = EXCLUDED.description,
        district = EXCLUDED.district,
        complaint_date = EXCLUDED.complaint_date,
        updated_at = now()
      RETURNING *`,
      [
        String(b.id),
        String(b.owner || b.owner_key || ""),
        b.owner_user_id || null,
        String(b.category || ""),
        String(b.product || ""),
        String(b.status || "Submitted"),
        String(b.description || ""),
        String(b.district || ""),
        b.date || b.complaint_date || null,
      ]
    );
    return res.json({ complaint: mapComplaint(result.rows[0]) });
  } catch (error) {
    console.error("upsertComplaint:", error);
    return res.status(500).json({ message: error.message });
  }
};

const upsertAlert = async (req, res) => {
  try {
    const b = req.body || {};
    if (!b.id) return res.status(400).json({ message: "id is required" });
    const result = await pool.query(
      `INSERT INTO fertilizer_alerts (
        id, audience, user_id, audience_key, title, body, kind, order_id, read, created_at
      ) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, COALESCE($10::timestamptz, now()))
      ON CONFLICT (id) DO UPDATE SET
        title = EXCLUDED.title,
        body = EXCLUDED.body,
        kind = EXCLUDED.kind,
        read = EXCLUDED.read
      RETURNING *`,
      [
        String(b.id),
        String(b.audience || "owner"),
        b.user_id || null,
        String(b.audience_key || ""),
        String(b.title || ""),
        String(b.body || ""),
        String(b.kind || "info"),
        b.order_id || b.orderId || null,
        b.read === true,
        b.at || b.created_at || null,
      ]
    );
    return res.json({ alert: mapAlert(result.rows[0]) });
  } catch (error) {
    console.error("upsertAlert:", error);
    return res.status(500).json({ message: error.message });
  }
};

const markAlertRead = async (req, res) => {
  try {
    const id = req.params.id;
    await pool.query(`UPDATE fertilizer_alerts SET read = true WHERE id = $1`, [
      id,
    ]);
    return res.json({ ok: true });
  } catch (error) {
    return res.status(500).json({ message: error.message });
  }
};

module.exports = {
  bootstrap,
  upsertOrder,
  upsertGov,
  upsertShopTalk,
  upsertComplaint,
  upsertAlert,
  markAlertRead,
};

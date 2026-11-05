const pool = require("../config/db");

/*
|--------------------------------------------------------------------------
| ADMIN DASHBOARD
|--------------------------------------------------------------------------
| Powers the React admin-web app. Uses the shared Supabase tables that
| buyers and estate owners already write to.
*/

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  return res.status(500).json({ message: "Server error", error: error.message });
};

const DEFAULT_BANDS = {
  Kurunegala: "Rs. 110 – 135",
  Colombo: "Rs. 120 – 145",
  Gampaha: "Rs. 115 – 140",
  Puttalam: "Rs. 105 – 130",
  Kandy: "Rs. 115 – 138",
  Galle: "Rs. 118 – 142",
  Jaffna: "Rs. 100 – 125",
  Anuradhapura: "Rs. 108 – 130",
  Trincomalee: "Rs. 110 – 132",
  Batticaloa: "Rs. 108 – 130",
  Badulla: "Rs. 112 – 135",
  Ratnapura: "Rs. 112 – 136",
  Matara: "Rs. 115 – 140",
  Kilinochchi: "Rs. 100 – 125",
};

const districtFromLocation = (location) => {
  const text = String(location || "").trim();
  if (!text) return null;
  const known = Object.keys(DEFAULT_BANDS);
  const hit = known.find((d) => text.toLowerCase().includes(d.toLowerCase()));
  return hit || text.split(",")[0].trim() || null;
};

/* ── Dashboard ─────────────────────────────────────────────────────────── */

const getDashboard = async (_req, res) => {
  try {
    const [users, requests, listings, deals, completed, disputes, recent] =
      await Promise.all([
        pool.query("SELECT COUNT(*)::int AS n FROM users WHERE role <> 'ADMIN'"),
        pool.query(
          `SELECT COUNT(*)::int AS n FROM buyer_requests
           WHERE UPPER(COALESCE(status, 'PENDING')) IN ('PENDING', 'OPEN')`
        ),
        pool.query(
          `SELECT COUNT(*)::int AS n FROM product_listings
           WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'`
        ),
        pool.query(
          `SELECT COUNT(*)::int AS n FROM negotiations WHERE status = 'OPEN'`
        ),
        pool.query(
          `SELECT COALESCE(SUM(total_value), 0)::float AS gmv
           FROM orders WHERE UPPER(COALESCE(status, '')) = 'COMPLETED'`
        ),
        pool.query(
          `SELECT COUNT(*)::int AS n FROM orders
           WHERE dispute_status = 'PENDING'`
        ),
        pool.query(
          `SELECT id, status, final_price_per_unit, total_value, created_at,
                  delivered_quantity, dispute_status
           FROM orders
           ORDER BY COALESCE(completed_at, created_at) DESC
           LIMIT 8`
        ),
      ]);

    const pendingVerify = await pool.query(
      `SELECT COUNT(*)::int AS n FROM users
       WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'PENDING'`
    );

    return res.status(200).json({
      users: users.rows[0].n,
      pendingVerify: pendingVerify.rows[0].n,
      openBuyRequests: requests.rows[0].n,
      activeListings: listings.rows[0].n,
      dealsInProgress: deals.rows[0].n,
      completedGmv: completed.rows[0].gmv,
      openDisputes: disputes.rows[0].n,
      recentOrders: recent.rows.map((o) => ({
        id: o.id,
        code: `CR-${o.id}`,
        status: o.dispute_status === "PENDING" ? "DISPUTED" : o.status,
        unitPrice: o.final_price_per_unit,
        quantity: o.delivered_quantity,
        createdAt: o.created_at,
      })),
    });
  } catch (error) {
    return serverError(res, "Admin dashboard", error);
  }
};

/* ── Users ─────────────────────────────────────────────────────────────── */

const getUsers = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.name, u.phone, u.role, u.location, u.created_at,
              COALESCE(u.status, 'ACTIVE') AS status,
              eo.estate_name
       FROM users u
       LEFT JOIN estate_owners eo ON eo.user_id = u.id
       WHERE u.role <> 'ADMIN'
       ORDER BY u.created_at DESC`
    );
    return res.status(200).json(
      result.rows.map((u) => ({
        id: u.id,
        name: u.name,
        phone: u.phone,
        role: u.role === "ESTATE_OWNER" ? "ESTATE" : u.role,
        district: districtFromLocation(u.location),
        location: u.location,
        estateName: u.estate_name,
        status: String(u.status || "ACTIVE").toUpperCase(),
        createdAt: u.created_at,
      }))
    );
  } catch (error) {
    return serverError(res, "Admin users", error);
  }
};

const setUserStatus = async (req, res) => {
  try {
    const status = String(req.body.status || "")
      .trim()
      .toUpperCase();
    if (!["ACTIVE", "PENDING", "SUSPENDED", "VERIFIED", "REJECTED"].includes(status)) {
      return res.status(400).json({ message: "Invalid status" });
    }
    // VERIFIED maps to ACTIVE for this schema
    const stored = status === "VERIFIED" ? "ACTIVE" : status === "REJECTED" ? "SUSPENDED" : status;
    const result = await pool.query(
      `UPDATE users SET status = $2 WHERE id = $1 AND role <> 'ADMIN'
       RETURNING id, name, phone, role, location, status`,
      [req.params.id, stored]
    );
    if (!result.rows[0]) return res.status(404).json({ message: "User not found" });
    const u = result.rows[0];
    return res.status(200).json({
      id: u.id,
      name: u.name,
      phone: u.phone,
      role: u.role,
      status: u.status,
    });
  } catch (error) {
    return serverError(res, "Set user status", error);
  }
};

/* ── Marketplace posts ─────────────────────────────────────────────────── */

const getBuyRequests = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT br.*, u.name AS buyer_display
       FROM buyer_requests br
       LEFT JOIN users u ON u.id = br.buyer_id
       ORDER BY br.created_at DESC
       LIMIT 100`
    );
    return res.status(200).json(
      result.rows.map((r) => ({
        id: r.id,
        category: r.product_type,
        quantity: r.requested_quantity,
        bidPrice: r.bidding_price_per_unit,
        district: districtFromLocation(r.location),
        location: r.location,
        status: r.status,
        buyerName: r.buyer_display || r.buyer_name,
        needDate: r.required_date,
        createdAt: r.created_at,
      }))
    );
  } catch (error) {
    return serverError(res, "Admin buy requests", error);
  }
};

const hideBuyRequest = async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE buyer_requests SET status = 'HIDDEN' WHERE id = $1 RETURNING *`,
      [req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ message: "Request not found" });
    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Hide buy request", error);
  }
};

const getListings = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT pl.*, eo.estate_name, eo.location AS estate_location
       FROM product_listings pl
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       ORDER BY pl.created_at DESC
       LIMIT 100`
    );
    return res.status(200).json(
      result.rows.map((l) => ({
        id: l.id,
        category: l.product_type,
        quantity: l.quantity,
        offerPrice: l.offer_price_per_unit,
        district: districtFromLocation(l.estate_location),
        location: l.estate_location,
        estateName: l.estate_name,
        status: l.status,
        verified: String(l.status || "").toUpperCase() === "ACTIVE",
        availableAt: l.available_date,
        createdAt: l.created_at,
      }))
    );
  } catch (error) {
    return serverError(res, "Admin listings", error);
  }
};

const hideListing = async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE product_listings SET status = 'HIDDEN' WHERE id = $1 RETURNING *`,
      [req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ message: "Listing not found" });
    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Hide listing", error);
  }
};

const verifyListing = async (req, res) => {
  try {
    const verified = Boolean(req.body.verified);
    const result = await pool.query(
      `UPDATE product_listings
       SET status = $2
       WHERE id = $1
       RETURNING *`,
      [req.params.id, verified ? "ACTIVE" : "UNVERIFIED"]
    );
    if (!result.rows[0]) return res.status(404).json({ message: "Listing not found" });
    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Verify listing", error);
  }
};

/* ── Deals (negotiations) + completed orders ───────────────────────────── */

const getDeals = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT n.id, n.status, n.created_at, n.order_id, n.listing_id,
              pl.product_type, pl.quantity, pl.offer_price_per_unit,
              u.name AS buyer_name, eo.estate_name,
              o.final_price_per_unit, o.status AS order_status, o.dispute_status
       FROM negotiations n
       JOIN product_listings pl ON pl.id = n.listing_id
       JOIN users u ON u.id = n.buyer_id
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       LEFT JOIN orders o ON o.id = n.order_id
       WHERE n.status IN ('OPEN', 'ACCEPTED')
          OR o.dispute_status = 'PENDING'
       ORDER BY n.created_at DESC
       LIMIT 100`
    );
    return res.status(200).json(
      result.rows.map((d) => {
        let status = d.status;
        if (d.dispute_status === "PENDING") status = "DISPUTED";
        else if (d.order_status === "COMPLETED") status = "COMPLETED";
        else if (d.status === "OPEN") status = "NEGOTIATING";
        else if (d.status === "ACCEPTED") status = "ACCEPTED";
        return {
          id: d.id,
          code: `CR-${d.id}`,
          category: d.product_type,
          quantity: d.quantity,
          unitPrice: d.final_price_per_unit || d.offer_price_per_unit,
          status,
          buyerName: d.buyer_name,
          estateName: d.estate_name,
          orderId: d.order_id,
          createdAt: d.created_at,
        };
      })
    );
  } catch (error) {
    return serverError(res, "Admin deals", error);
  }
};

const getDealDetail = async (req, res) => {
  try {
    const neg = await pool.query(
      `SELECT n.*, pl.product_type, pl.quantity, pl.offer_price_per_unit,
              u.name AS buyer_name, eo.estate_name,
              o.final_price_per_unit, o.status AS order_status, o.dispute_status
       FROM negotiations n
       JOIN product_listings pl ON pl.id = n.listing_id
       JOIN users u ON u.id = n.buyer_id
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       LEFT JOIN orders o ON o.id = n.order_id
       WHERE n.id = $1`,
      [req.params.id]
    );
    const deal = neg.rows[0];
    if (!deal) return res.status(404).json({ message: "Deal not found" });

    const messages = await pool.query(
      `SELECT m.id, m.sender_id, m.message, m.offer_price_per_unit, m.offer_status, m.created_at,
              u.name AS sender_name, u.role AS sender_role
       FROM negotiation_messages m
       JOIN users u ON u.id = m.sender_id
       WHERE m.negotiation_id = $1
       ORDER BY m.created_at ASC`,
      [deal.id]
    );

    let status = deal.status;
    if (deal.dispute_status === "PENDING") status = "DISPUTED";
    else if (deal.status === "OPEN") status = "NEGOTIATING";

    return res.status(200).json({
      order: {
        id: deal.id,
        code: `CR-${deal.id}`,
        category: deal.product_type,
        quantity: deal.quantity,
        unitPrice: deal.final_price_per_unit || deal.offer_price_per_unit,
        status,
        buyerName: deal.buyer_name,
        estateName: deal.estate_name,
      },
      messages: messages.rows.map((m) => ({
        id: m.id,
        senderId: m.sender_id,
        senderName: m.sender_name,
        senderRole: m.sender_role,
        type: m.offer_price_per_unit != null ? "OFFER" : "TEXT",
        text: m.message,
        offerPrice: m.offer_price_per_unit,
        offerStatus: m.offer_status,
        createdAt: m.created_at,
      })),
    });
  } catch (error) {
    return serverError(res, "Admin deal detail", error);
  }
};

const getTransactions = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT o.*,
              COALESCE(pl.product_type, sr.product_type) AS product_type,
              COALESCE(pl.quantity, sr.quantity) AS qty,
              u.name AS buyer_name
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
       LEFT JOIN users u ON u.id = o.buyer_id
       WHERE UPPER(COALESCE(o.status, '')) = 'COMPLETED'
       ORDER BY COALESCE(o.completed_at, o.created_at) DESC
       LIMIT 100`
    );
    return res.status(200).json(
      result.rows.map((o) => ({
        id: o.id,
        code: `CR-${o.id}`,
        category: o.product_type,
        quantity: o.delivered_quantity || o.qty,
        unitPrice: o.delivered_price_per_unit || o.final_price_per_unit,
        total: o.total_value,
        status: o.status,
        buyerName: o.buyer_name,
        updatedAt: o.completed_at || o.created_at,
        createdAt: o.created_at,
      }))
    );
  } catch (error) {
    return serverError(res, "Admin transactions", error);
  }
};

/* ── Disputes ──────────────────────────────────────────────────────────── */

const getDisputes = async (_req, res) => {
  try {
    const result = await pool.query(
      `SELECT
         o.id, o.final_price_per_unit, o.total_value, o.delivered_quantity,
         o.delivered_price_per_unit, o.dispute_price_per_unit, o.dispute_status,
         o.dispute_note, o.dispute_severity, o.completed_at, o.dispute_resolved_at,
         COALESCE(pl.product_type, sr.product_type) AS product_type,
         eo1.estate_name AS listing_estate,
         eo2.estate_name AS offer_estate,
         u.name AS buyer_name
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
       LEFT JOIN estate_owners eo1 ON eo1.id = pl.estate_owner_id
       LEFT JOIN estate_owners eo2 ON eo2.id = sr.estate_owner_id
       LEFT JOIN users u ON u.id = o.buyer_id
       WHERE o.dispute_status IS NOT NULL
       ORDER BY o.completed_at DESC NULLS LAST, o.id DESC`
    );

    const rows = result.rows.map(({ listing_estate, offer_estate, ...row }) => ({
      id: row.id,
      orderId: String(row.id),
      title:
        row.dispute_note?.slice(0, 60) ||
        `Price dispute on CR-${row.id}`,
      body:
        row.dispute_note ||
        `Agreed Rs. ${row.final_price_per_unit}; requested Rs. ${row.dispute_price_per_unit}`,
      severity: String(row.dispute_severity || "medium").toLowerCase(),
      status: row.dispute_status === "PENDING" ? "OPEN" : row.dispute_status,
      productType: row.product_type,
      estateName: listing_estate || offer_estate || "Estate",
      buyerName: row.buyer_name,
      finalPrice: row.final_price_per_unit,
      disputePrice: row.dispute_price_per_unit,
      deliveredQty: row.delivered_quantity,
      completedAt: row.completed_at,
      resolvedAt: row.dispute_resolved_at,
    }));

    rows.sort(
      (a, b) => Number(b.status === "OPEN") - Number(a.status === "OPEN")
    );
    return res.status(200).json(rows);
  } catch (error) {
    return serverError(res, "Get disputes", error);
  }
};

const setDisputeSeverity = async (req, res) => {
  try {
    const severity = String(req.body.severity || "").toLowerCase();
    if (!["low", "medium", "high"].includes(severity)) {
      return res.status(400).json({ message: "Level must be low, medium or high" });
    }
    const result = await pool.query(
      `UPDATE orders SET dispute_severity = $2
       WHERE id = $1 AND dispute_status IS NOT NULL
       RETURNING id, dispute_severity, dispute_status`,
      [req.params.id, severity]
    );
    if (!result.rows[0]) return res.status(404).json({ message: "Dispute not found" });
    return res.status(200).json({
      id: result.rows[0].id,
      severity: result.rows[0].dispute_severity,
      status: result.rows[0].dispute_status,
    });
  } catch (error) {
    return serverError(res, "Set dispute severity", error);
  }
};

const resolve = (approve) => async (req, res) => {
  try {
    const found = await pool.query(
      "SELECT id, dispute_status, dispute_price_per_unit FROM orders WHERE id = $1",
      [req.params.id]
    );
    const order = found.rows[0];
    if (!order || !order.dispute_status) {
      return res.status(404).json({ message: "Dispute not found" });
    }
    if (order.dispute_status !== "PENDING") {
      return res.status(409).json({ message: "This dispute was already resolved" });
    }

    const result = approve
      ? await pool.query(
          `UPDATE orders
           SET dispute_status = 'APPROVED',
               delivered_price_per_unit = dispute_price_per_unit,
               dispute_resolved_at = $2
           WHERE id = $1
           RETURNING *`,
          [order.id, new Date()]
        )
      : await pool.query(
          `UPDATE orders
           SET dispute_status = 'REJECTED', dispute_resolved_at = $2
           WHERE id = $1
           RETURNING *`,
          [order.id, new Date()]
        );

    return res.status(200).json({
      message: approve ? "New price approved" : "Dispute rejected - agreed price stays",
      order: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Resolve dispute", error);
  }
};

const resolveDisputeAction = async (req, res) => {
  try {
    const action = String(req.body.action || "close").toLowerCase();
    if (action === "refund" || action === "approve") {
      return resolve(true)(req, res);
    }
    if (action === "warn" || action === "reject") {
      return resolve(false)(req, res);
    }
    // close without changing price
    const found = await pool.query(
      "SELECT id, dispute_status FROM orders WHERE id = $1",
      [req.params.id]
    );
    if (!found.rows[0]?.dispute_status) {
      return res.status(404).json({ message: "Dispute not found" });
    }
    const result = await pool.query(
      `UPDATE orders
       SET dispute_status = 'REJECTED', dispute_resolved_at = $2
       WHERE id = $1 RETURNING *`,
      [req.params.id, new Date()]
    );
    return res.status(200).json({ message: "Dispute closed", order: result.rows[0] });
  } catch (error) {
    return serverError(res, "Resolve dispute action", error);
  }
};

const createDisputeOnDeal = async (req, res) => {
  try {
    const title = String(req.body.title || "").trim();
    const body = String(req.body.body || "").trim();
    const severity = String(req.body.severity || "medium").toLowerCase();
    if (!title || !body) {
      return res.status(400).json({ message: "Title and details are required" });
    }
    if (!["low", "medium", "high"].includes(severity)) {
      return res.status(400).json({ message: "Level must be low, medium or high" });
    }

    // Deal id is a negotiation id; prefer linked order, else attach note to newest order for buyer
    const neg = await pool.query(
      `SELECT n.id, n.order_id, o.final_price_per_unit
       FROM negotiations n
       LEFT JOIN orders o ON o.id = n.order_id
       WHERE n.id = $1`,
      [req.params.id]
    );
    const deal = neg.rows[0];
    if (!deal) return res.status(404).json({ message: "Deal not found" });
    if (!deal.order_id) {
      return res.status(400).json({
        message: "This deal has no order yet — wait until a price is accepted",
      });
    }

    const result = await pool.query(
      `UPDATE orders
       SET dispute_status = 'PENDING',
           dispute_note = $2,
           dispute_severity = $3,
           dispute_price_per_unit = COALESCE(dispute_price_per_unit, final_price_per_unit),
           dispute_resolved_at = NULL
       WHERE id = $1
       RETURNING *`,
      [deal.order_id, `${title}\n${body}`, severity]
    );
    return res.status(201).json({
      id: result.rows[0].id,
      title,
      body,
      severity,
      status: "OPEN",
      orderId: String(result.rows[0].id),
    });
  } catch (error) {
    return serverError(res, "Create dispute", error);
  }
};

/* ── Regions & prices ──────────────────────────────────────────────────── */

const getRegions = async (_req, res) => {
  try {
    const [users, bands, settings] = await Promise.all([
      pool.query(
        `SELECT role, location FROM users WHERE role <> 'ADMIN' AND location IS NOT NULL`
      ),
      pool.query(`SELECT name, band FROM region_price_bands`),
      pool.query(`SELECT radius FROM platform_settings WHERE id = 1`),
    ]);

    const custom = Object.fromEntries(bands.rows.map((b) => [b.name, b.band]));
    const radius = settings.rows[0]?.radius ?? 3;

    const districtStats = {};
    for (const u of users.rows) {
      const name = districtFromLocation(u.location);
      if (!name) continue;
      if (!districtStats[name]) districtStats[name] = { buyers: 0, estates: 0 };
      if (u.role === "BUYER") districtStats[name].buyers += 1;
      if (u.role === "ESTATE_OWNER") districtStats[name].estates += 1;
    }

    const names = new Set([
      ...Object.keys(DEFAULT_BANDS),
      ...Object.keys(custom),
      ...Object.keys(districtStats),
    ]);

    const regions = [...names].map((name) => ({
      name,
      band: custom[name] || DEFAULT_BANDS[name] || "Rs. 110 – 140",
      buyers: districtStats[name]?.buyers || 0,
      estates: districtStats[name]?.estates || 0,
      radius,
    }));

    regions.sort((a, b) => a.name.localeCompare(b.name));
    return res.status(200).json(regions);
  } catch (error) {
    return serverError(res, "Admin regions", error);
  }
};

const putRegionBand = async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const band = String(req.body.band || "").trim();
    if (!name || !band) {
      return res.status(400).json({ message: "Region name and price band are required" });
    }
    await pool.query(
      `INSERT INTO region_price_bands (name, band, updated_at)
       VALUES ($1, $2, NOW())
       ON CONFLICT (name) DO UPDATE SET band = EXCLUDED.band, updated_at = NOW()`,
      [name, band]
    );
    return res.status(200).json({ name, band });
  } catch (error) {
    return serverError(res, "Publish region band", error);
  }
};

/* ── Reports & settings ────────────────────────────────────────────────── */

const getReports = async (_req, res) => {
  try {
    const [orders, disputes, estates] = await Promise.all([
      pool.query(`SELECT status, final_price_per_unit, total_value FROM orders`),
      pool.query(
        `SELECT COUNT(*)::int AS n FROM orders WHERE dispute_status = 'PENDING'`
      ),
      pool.query(
        `SELECT COUNT(*)::int AS total,
                COUNT(*) FILTER (WHERE COALESCE(u.status, 'ACTIVE') IN ('ACTIVE', 'VERIFIED'))::int AS verified
         FROM estate_owners eo
         LEFT JOIN users u ON u.id = eo.user_id`
      ),
    ]);
    const completed = orders.rows.filter(
      (o) => String(o.status || "").toUpperCase() === "COMPLETED"
    );
    const avgDealPrice = completed.length
      ? Math.round(
          completed.reduce((s, o) => s + Number(o.final_price_per_unit || 0), 0) /
            completed.length
        )
      : 0;
    return res.status(200).json({
      avgDealPrice,
      totalOrders: orders.rows.length,
      completedOrders: completed.length,
      openDisputes: disputes.rows[0].n,
      verifiedEstates: estates.rows[0].verified,
      totalEstates: estates.rows[0].total,
      completedGmv: completed.reduce((s, o) => s + Number(o.total_value || 0), 0),
    });
  } catch (error) {
    return serverError(res, "Admin reports", error);
  }
};

const getSettings = async (_req, res) => {
  try {
    const result = await pool.query(`SELECT * FROM platform_settings WHERE id = 1`);
    const s = result.rows[0] || {};
    return res.status(200).json({
      fee: Number(s.fee ?? 2.5),
      radius: Number(s.radius ?? 3),
      language: s.language || "en",
      paymentHold: Number(s.payment_hold ?? 4),
      support: s.support || "support@cococonnect.lk",
    });
  } catch (error) {
    return serverError(res, "Get settings", error);
  }
};

const putSettings = async (req, res) => {
  try {
    const fee = Number(req.body.fee);
    const radius = Number(req.body.radius);
    const language = String(req.body.language || "en");
    const paymentHold = Number(req.body.paymentHold);
    const support = String(req.body.support || "").trim();
    if (Number.isNaN(fee) || Number.isNaN(radius) || Number.isNaN(paymentHold) || !support) {
      return res.status(400).json({ message: "Invalid settings" });
    }
    await pool.query(
      `INSERT INTO platform_settings (id, fee, radius, language, payment_hold, support, updated_at)
       VALUES (1, $1, $2, $3, $4, $5, NOW())
       ON CONFLICT (id) DO UPDATE SET
         fee = EXCLUDED.fee,
         radius = EXCLUDED.radius,
         language = EXCLUDED.language,
         payment_hold = EXCLUDED.payment_hold,
         support = EXCLUDED.support,
         updated_at = NOW()`,
      [fee, radius, language, paymentHold, support]
    );
    return res.status(200).json({ fee, radius, language, paymentHold, support });
  } catch (error) {
    return serverError(res, "Save settings", error);
  }
};

module.exports = {
  getDashboard,
  getUsers,
  setUserStatus,
  getBuyRequests,
  hideBuyRequest,
  getListings,
  hideListing,
  verifyListing,
  getDeals,
  getDealDetail,
  getTransactions,
  getDisputes,
  setDisputeSeverity,
  approveDispute: resolve(true),
  rejectDispute: resolve(false),
  resolveDisputeAction,
  createDisputeOnDeal,
  getRegions,
  putRegionBand,
  getReports,
  getSettings,
  putSettings,
};

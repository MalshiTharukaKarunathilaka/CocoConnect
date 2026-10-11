const pool = require("../config/db");

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);

  return res.status(500).json({
    message: "Server error",
    error: error.message,
  });
};

/*
|--------------------------------------------------------------------------
| MY ESTATE
|--------------------------------------------------------------------------
| Every estate owner login is linked to one estate_owners row. It is created
| on first use, named after the owner until they rename it.
*/
const getOwnEstate = async (db, userId) => {
  const existing = await db.query(
    "SELECT * FROM estate_owners WHERE user_id = $1",
    [userId]
  );
  if (existing.rows.length > 0) return existing.rows[0];

  const user = await db.query(
    "SELECT name, location FROM users WHERE id = $1",
    [userId]
  );
  const { name, location } = user.rows[0];

  const created = await db.query(
    `INSERT INTO estate_owners (user_id, name, estate_name, location, trust_score)
     VALUES ($1, $2, $3, $4, NULL)
     RETURNING *`,
    [userId, name, `${name} Estate`, location]
  );
  return created.rows[0];
};

const getEstate = async (req, res) => {
  try {
    return res.status(200).json(await getOwnEstate(pool, req.user.id));
  } catch (error) {
    return serverError(res, "Get estate", error);
  }
};

const updateEstate = async (req, res) => {
  try {
    const text = (value) => String(value ?? "").trim() || null;
    const estateName = text(req.body.estateName);
    const yearText = text(req.body.yearEstablished);
    const year = yearText === null ? null : Number(yearText);

    if (!estateName) {
      return res.status(400).json({ message: "Estate name is required" });
    }
    if (year !== null && !(Number.isInteger(year) && year >= 1800 && year <= 2100)) {
      return res.status(400).json({ message: "Enter a valid year, e.g. 2015" });
    }

    const estate = await getOwnEstate(pool, req.user.id);
    const result = await pool.query(
      `UPDATE estate_owners
       SET estate_name = $2, location = $3, total_land_area = $4,
           primary_crop = $5, year_established = $6
       WHERE id = $1
       RETURNING *`,
      [
        estate.id,
        estateName,
        text(req.body.location),
        text(req.body.totalLandArea),
        text(req.body.primaryCrop),
        year,
      ]
    );

    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Update estate", error);
  }
};

/*
|--------------------------------------------------------------------------
| PROFILE SUMMARY
|--------------------------------------------------------------------------
| Estate details plus the counts shown on the profile page.
*/
const getSummary = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);
    const count = async (sql) =>
      Number((await pool.query(sql, [estate.id])).rows[0].count);

    const myOrders = `FROM orders o
      LEFT JOIN product_listings pl ON pl.id = o.listing_id
      LEFT JOIN sell_requests sr
        ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
      WHERE (pl.estate_owner_id = $1 OR sr.estate_owner_id = $1)`;

    const activeListings = await count(
      `SELECT COUNT(*) AS count FROM product_listings
       WHERE estate_owner_id = $1
         AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'`
    );
    const openChats = await count(
      `SELECT COUNT(*) AS count FROM negotiations n
       JOIN product_listings pl ON pl.id = n.listing_id
       WHERE pl.estate_owner_id = $1 AND n.status = 'OPEN'`
    );
    const offersWaiting = await count(
      `SELECT COUNT(*) AS count FROM sell_requests
       WHERE estate_owner_id = $1 AND status = 'pending'`
    );
    const ordersActive = await count(
      `SELECT COUNT(*) AS count ${myOrders} AND o.status = 'ACCEPTED'`
    );
    const ordersCompleted = await count(
      `SELECT COUNT(*) AS count ${myOrders} AND o.status = 'COMPLETED'`
    );

    return res.status(200).json({
      estate,
      active_listings: activeListings,
      open_chats: openChats,
      offers_waiting: offersWaiting,
      orders_active: ordersActive,
      orders_completed: ordersCompleted,
    });
  } catch (error) {
    return serverError(res, "Get owner summary", error);
  }
};

/*
|--------------------------------------------------------------------------
| LISTINGS
|--------------------------------------------------------------------------
*/
const getMyListings = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);
    const result = await pool.query(
      `SELECT * FROM product_listings
       WHERE estate_owner_id = $1
       ORDER BY created_at DESC, id DESC`,
      [estate.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get my listings", error);
  }
};

const createListing = async (req, res) => {
  try {
    const { productType, quantity, availableDate, offerPricePerUnit } = req.body;

    if (!productType || !quantity || !availableDate || !offerPricePerUnit) {
      return res.status(400).json({ message: "All fields are required" });
    }

    const estate = await getOwnEstate(pool, req.user.id);
    const result = await pool.query(
      `INSERT INTO product_listings
        (estate_owner_id, product_type, quantity, available_date, offer_price_per_unit)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        estate.id,
        String(productType).toUpperCase(),
        quantity,
        availableDate,
        offerPricePerUnit,
      ]
    );

    return res.status(201).json({
      message: "Listing created successfully",
      listing: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Create listing", error);
  }
};

/*
|--------------------------------------------------------------------------
| BUYER REQUESTS + MY OFFERS ON THEM
|--------------------------------------------------------------------------
*/
const getBuyerRequests = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);

    const params = [estate.id];
    let typeFilter = "";
    if (req.query.type) {
      params.push(String(req.query.type).toUpperCase());
      typeFilter = `AND UPPER(br.product_type) = $${params.length}`;
    }

    const result = await pool.query(
      `SELECT
        br.*,
        sr.id AS my_offer_id,
        sr.seller_price_per_unit AS my_offer_price,
        sr.status AS my_offer_status
       FROM buyer_requests br
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = br.id AND sr.estate_owner_id = $1
       WHERE UPPER(COALESCE(br.status, 'PENDING')) = 'PENDING'
       ${typeFilter}
       ORDER BY br.bidding_price_per_unit DESC, br.id DESC`,
      params
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get buyer requests", error);
  }
};

const createSellRequest = async (req, res) => {
  try {
    const { buyerRequestId, quantity, sellerPricePerUnit, availableDate } = req.body;

    if (!buyerRequestId || !quantity || !sellerPricePerUnit) {
      return res.status(400).json({
        message: "Buyer request, quantity and price are required",
      });
    }

    const request = await pool.query(
      "SELECT * FROM buyer_requests WHERE id = $1",
      [buyerRequestId]
    );
    const buyerRequest = request.rows[0];
    if (!buyerRequest) {
      return res.status(404).json({ message: "Buyer request not found" });
    }
    if (String(buyerRequest.status || "PENDING").toUpperCase() !== "PENDING") {
      return res.status(409).json({
        message: "This buyer request is no longer open",
      });
    }

    const estate = await getOwnEstate(pool, req.user.id);
    const duplicate = await pool.query(
      `SELECT id FROM sell_requests
       WHERE buyer_request_id = $1 AND estate_owner_id = $2`,
      [buyerRequestId, estate.id]
    );
    if (duplicate.rows.length > 0) {
      return res.status(409).json({
        message: "You have already sent an offer for this request",
      });
    }

    const result = await pool.query(
      `INSERT INTO sell_requests
        (estate_owner_id, buyer_request_id, product_type, quantity,
         seller_price_per_unit, available_date, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'pending')
       RETURNING *`,
      [
        estate.id,
        buyerRequestId,
        buyerRequest.product_type,
        quantity,
        sellerPricePerUnit,
        availableDate || null,
      ]
    );

    return res.status(201).json({
      message: "Offer sent to the buyer",
      sellRequest: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Create sell request", error);
  }
};

const getMySellRequests = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);
    const result = await pool.query(
      `SELECT
        sr.*,
        br.buyer_name,
        br.location AS buyer_location,
        br.requested_quantity,
        br.required_date,
        br.bidding_price_per_unit,
        o.id AS order_id,
        o.status AS order_status
       FROM sell_requests sr
       JOIN buyer_requests br ON br.id = sr.buyer_request_id
       LEFT JOIN orders o
         ON o.buyer_request_id = sr.buyer_request_id AND sr.status = 'accepted'
       WHERE sr.estate_owner_id = $1
       ORDER BY sr.created_at DESC, sr.id DESC`,
      [estate.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get my sell requests", error);
  }
};

/*
|--------------------------------------------------------------------------
| NEGOTIATIONS ON MY LISTINGS
|--------------------------------------------------------------------------
*/
const getMyNegotiations = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);
    const result = await pool.query(
      `SELECT
        n.id,
        n.status,
        n.order_id,
        n.created_at,
        o.status AS order_status,
        pl.product_type,
        pl.quantity,
        pl.offer_price_per_unit,
        u.name AS buyer_name,
        COALESCE(mc.message_count, 0) AS message_count
       FROM negotiations n
       JOIN product_listings pl ON pl.id = n.listing_id
       JOIN users u ON u.id = n.buyer_id
       LEFT JOIN orders o ON o.id = n.order_id
       LEFT JOIN (
         SELECT negotiation_id, COUNT(*) AS message_count
         FROM negotiation_messages
         GROUP BY negotiation_id
       ) mc ON mc.negotiation_id = n.id
       WHERE pl.estate_owner_id = $1
       ORDER BY n.created_at DESC, n.id DESC`,
      [estate.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get owner negotiations", error);
  }
};

// Loads a negotiation only if it is on one of my estate's listings.
const findOwnedNegotiation = async (negotiationId, estateId) => {
  const result = await pool.query(
    `SELECT n.*
     FROM negotiations n
     JOIN product_listings pl ON pl.id = n.listing_id
     WHERE n.id = $1 AND pl.estate_owner_id = $2`,
    [negotiationId, estateId]
  );
  return result.rows[0];
};

const getNegotiation = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);
    const negotiation = await findOwnedNegotiation(req.params.id, estate.id);
    if (!negotiation) {
      return res.status(404).json({ message: "Negotiation not found" });
    }

    const listing = await pool.query(
      `SELECT
        pl.*,
        eo.id AS estate_owner_id,
        eo.name AS owner_name,
        eo.estate_name,
        eo.location,
        eo.trust_score
       FROM product_listings pl
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       WHERE pl.id = $1`,
      [negotiation.listing_id]
    );

    const buyer = await pool.query(
      "SELECT id, name, location FROM users WHERE id = $1",
      [negotiation.buyer_id]
    );

    const messages = await pool.query(
      `SELECT
        m.id,
        m.message,
        m.offer_price_per_unit,
        m.created_at,
        m.sender_id,
        (m.sender_id = $2) AS is_mine
       FROM negotiation_messages m
       WHERE m.negotiation_id = $1
       ORDER BY m.created_at, m.id`,
      [negotiation.id, req.user.id]
    );

    const order = negotiation.order_id
      ? await pool.query("SELECT status FROM orders WHERE id = $1", [
          negotiation.order_id,
        ])
      : null;

    return res.status(200).json({
      id: negotiation.id,
      status: negotiation.status,
      order_id: negotiation.order_id,
      order_status: order?.rows[0]?.status ?? null,
      listing: listing.rows[0],
      buyer: buyer.rows[0],
      messages: messages.rows,
    });
  } catch (error) {
    return serverError(res, "Get owner negotiation", error);
  }
};

const sendMessage = async (req, res) => {
  try {
    const { message, offerPricePerUnit } = req.body;
    const text = message ? String(message).trim() : "";

    if (!text && !offerPricePerUnit) {
      return res.status(400).json({
        message: "Send a message or an offer price",
      });
    }
    if (offerPricePerUnit && !(Number(offerPricePerUnit) > 0)) {
      return res.status(400).json({ message: "Offer price must be above 0" });
    }

    const estate = await getOwnEstate(pool, req.user.id);
    const negotiation = await findOwnedNegotiation(req.params.id, estate.id);
    if (!negotiation) {
      return res.status(404).json({ message: "Negotiation not found" });
    }
    if (negotiation.status !== "OPEN") {
      return res.status(409).json({ message: "This negotiation is closed" });
    }

    const result = await pool.query(
      `INSERT INTO negotiation_messages
        (negotiation_id, sender_id, message, offer_price_per_unit)
       VALUES ($1, $2, $3, $4)
       RETURNING *, true AS is_mine`,
      [negotiation.id, req.user.id, text || null, offerPricePerUnit || null]
    );

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Owner send message", error);
  }
};

const declineNegotiation = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);
    const negotiation = await findOwnedNegotiation(req.params.id, estate.id);
    if (!negotiation || negotiation.status !== "OPEN") {
      return res.status(404).json({
        message: "No open negotiation found to decline",
      });
    }

    const result = await pool.query(
      `UPDATE negotiations SET status = 'REJECTED'
       WHERE id = $1
       RETURNING *`,
      [negotiation.id]
    );

    return res.status(200).json({
      message: "Negotiation declined",
      negotiation: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Decline negotiation", error);
  }
};

/*
|--------------------------------------------------------------------------
| ORDERS
|--------------------------------------------------------------------------
| From a negotiation on my listing, or from a buyer accepting my offer.
*/
const getMyOrders = async (req, res) => {
  try {
    const estate = await getOwnEstate(pool, req.user.id);
    const result = await pool.query(
      `SELECT
        o.*,
        COALESCE(pl.product_type, sr.product_type) AS product_type,
        COALESCE(pl.quantity, sr.quantity) AS quantity,
        COALESCE(pl.available_date, sr.available_date, br.required_date) AS due_date,
        COALESCE(u.name, br.buyer_name) AS buyer_name,
        COALESCE(u.location, br.location) AS buyer_location,
        n.id AS negotiation_id
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
       LEFT JOIN buyer_requests br ON br.id = o.buyer_request_id
       LEFT JOIN users u ON u.id = o.buyer_id
       LEFT JOIN negotiations n ON n.order_id = o.id
       WHERE pl.estate_owner_id = $1 OR sr.estate_owner_id = $1
       ORDER BY o.created_at DESC, o.id DESC`,
      [estate.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get owner orders", error);
  }
};

/*
|--------------------------------------------------------------------------
| ACCEPT THE BUYER'S OFFER -> creates an order
|--------------------------------------------------------------------------
| The estate owner agrees to the buyer's latest counter-offer, or the listed
| price if the buyer hasn't made one.
*/
const acceptNegotiation = async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const estate = await getOwnEstate(client, req.user.id);
    const found = await client.query(
      `SELECT n.*, pl.quantity, pl.offer_price_per_unit
       FROM negotiations n
       JOIN product_listings pl ON pl.id = n.listing_id
       WHERE n.id = $1 AND pl.estate_owner_id = $2`,
      [req.params.id, estate.id]
    );
    const negotiation = found.rows[0];
    if (!negotiation) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Negotiation not found" });
    }
    if (negotiation.status !== "OPEN") {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "This negotiation is closed" });
    }

    const buyerOffer = await client.query(
      `SELECT offer_price_per_unit
       FROM negotiation_messages
       WHERE negotiation_id = $1
         AND sender_id = $2
         AND offer_price_per_unit IS NOT NULL
       ORDER BY created_at DESC, id DESC
       LIMIT 1`,
      [negotiation.id, negotiation.buyer_id]
    );

    const finalPrice = Number(
      buyerOffer.rows[0]?.offer_price_per_unit ?? negotiation.offer_price_per_unit
    );
    const totalValue = finalPrice * Number(negotiation.quantity);

    const order = await client.query(
      `INSERT INTO orders
        (listing_id, buyer_id, final_price_per_unit, total_value, status)
       VALUES ($1, $2, $3, $4, 'ACCEPTED')
       RETURNING *`,
      [negotiation.listing_id, negotiation.buyer_id, finalPrice, totalValue]
    );

    await client.query(
      `UPDATE negotiations
       SET status = 'ACCEPTED', order_id = $2
       WHERE id = $1`,
      [negotiation.id, order.rows[0].id]
    );

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Deal accepted",
      order: order.rows[0],
    });
  } catch (error) {
    await client.query("ROLLBACK");
    return serverError(res, "Owner accept negotiation", error);
  } finally {
    client.release();
  }
};

/*
|--------------------------------------------------------------------------
| COMPLETE A DEAL with what was actually delivered
|--------------------------------------------------------------------------
*/
const completeOrder = async (req, res) => {
  try {
    const deliveredQuantity = Number(req.body.deliveredQuantity);
    const finalPrice = Number(req.body.finalPricePerUnit);

    if (!Number.isInteger(deliveredQuantity) || deliveredQuantity <= 0) {
      return res.status(400).json({
        message: "Enter the number of nuts actually delivered",
      });
    }
    if (!(finalPrice > 0)) {
      return res.status(400).json({ message: "Enter the final price per nut" });
    }

    const estate = await getOwnEstate(pool, req.user.id);
    const mine = await pool.query(
      `SELECT o.id, o.status
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
       WHERE o.id = $1 AND (pl.estate_owner_id = $2 OR sr.estate_owner_id = $2)`,
      [req.params.id, estate.id]
    );
    const order = mine.rows[0];
    if (!order) {
      return res.status(404).json({ message: "Order not found" });
    }
    if (order.status !== "ACCEPTED") {
      return res.status(409).json({ message: "This deal is already completed" });
    }

    const result = await pool.query(
      `UPDATE orders
       SET status = 'COMPLETED',
           delivered_quantity = $2,
           delivered_price_per_unit = $3,
           completed_at = $4
       WHERE id = $1
       RETURNING *`,
      [order.id, deliveredQuantity, finalPrice, new Date()]
    );

    return res.status(200).json({
      message: "Deal completed",
      order: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Complete order", error);
  }
};

/*
|--------------------------------------------------------------------------
| MARKET PULSE: last deal closed and average prices for a product type
|--------------------------------------------------------------------------
*/
const getMarketStats = async (req, res) => {
  try {
    const type = String(req.query.type || "RAW_COCONUT").toUpperCase();

    const result = await pool.query(
      `SELECT
        o.created_at,
        o.status,
        COALESCE(o.delivered_quantity, pl.quantity, sr.quantity) AS quantity,
        COALESCE(o.delivered_price_per_unit, o.final_price_per_unit) AS price
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
       WHERE UPPER(COALESCE(pl.product_type, sr.product_type)) = $1
       ORDER BY o.created_at DESC, o.id DESC
       LIMIT 200`,
      [type]
    );

    const rows = result.rows.map((row) => ({
      at: new Date(row.created_at),
      quantity: Number(row.quantity),
      price: Number(row.price),
    }));

    // Average per nut, weighted by quantity, over deals since `since`.
    const averageSince = (since) => {
      const recent = rows.filter((row) => row.at >= since && row.quantity > 0);
      const nuts = recent.reduce((sum, row) => sum + row.quantity, 0);
      if (nuts === 0) return null;
      const value = recent.reduce((sum, row) => sum + row.quantity * row.price, 0);
      return Math.round((value / nuts) * 100) / 100;
    };

    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    const last = rows[0];
    return res.status(200).json({
      product_type: type,
      last_deal: last
        ? { quantity: last.quantity, price: last.price, at: last.at }
        : null,
      today_avg_price: averageSince(startOfToday),
      week_avg_price: averageSince(weekAgo),
    });
  } catch (error) {
    return serverError(res, "Get market stats", error);
  }
};

module.exports = {
  acceptNegotiation,
  completeOrder,
  getMarketStats,
  getEstate,
  updateEstate,
  getSummary,
  getMyListings,
  createListing,
  getBuyerRequests,
  createSellRequest,
  getMySellRequests,
  getMyNegotiations,
  getNegotiation,
  sendMessage,
  declineNegotiation,
  getMyOrders,
};

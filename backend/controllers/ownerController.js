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
    `INSERT INTO estate_owners (user_id, name, estate_name, location)
     VALUES ($1, $2, $3, $4)
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
    const estateName = String(req.body.estateName || "").trim();
    const location = String(req.body.location || "").trim();

    if (!estateName) {
      return res.status(400).json({ message: "Estate name is required" });
    }

    const estate = await getOwnEstate(pool, req.user.id);
    const result = await pool.query(
      `UPDATE estate_owners SET estate_name = $2, location = $3
       WHERE id = $1
       RETURNING *`,
      [estate.id, estateName, location || null]
    );

    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Update estate", error);
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
        br.bidding_price_per_unit
       FROM sell_requests sr
       JOIN buyer_requests br ON br.id = sr.buyer_request_id
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
        u.name AS buyer_name,
        n.id AS negotiation_id
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
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

module.exports = {
  getEstate,
  updateEstate,
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

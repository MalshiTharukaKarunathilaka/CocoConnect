const pool = require("../config/db");
const {
  parseCoords,
  parseRadius,
  withDistance,
  byDistance,
  dayOf,
  addDays,
} = require("../utils/geo");

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);

  return res.status(500).json({
    message: "Server error",
    error: error.message,
  });
};

const LISTING_COLUMNS = `
  pl.id,
  pl.product_type,
  pl.quantity,
  pl.available_date,
  pl.offer_price_per_unit,
  pl.status,
  pl.created_at,
  eo.id AS estate_owner_id,
  eo.name AS owner_name,
  eo.estate_name,
  eo.location,
  eo.trust_score
`;

const SORTS = {
  price_asc: "pl.offer_price_per_unit ASC",
  price_desc: "pl.offer_price_per_unit DESC",
  trust: "eo.trust_score DESC NULLS LAST",
  newest: "pl.created_at DESC",
};

// Coordinates stay on the server; clients only see the distance.
const hideCoords = ({ latitude, longitude, ...row }) => row;

/*
|--------------------------------------------------------------------------
| GET ACTIVE LISTINGS
|--------------------------------------------------------------------------
| Optional filters:
|   type                        product type
|   lat, lng, radiusKm          only estates within radiusKm of that point
|   minQuantity, requiredDate   match a buyer's request: at least that many
|                               nuts, available on requiredDate or up to
|                               7 days after it
|   sort                        newest | price_asc | price_desc | trust | nearest
*/
const getListings = async (req, res) => {
  try {
    const { type, sort } = req.query;
    const orderBy = SORTS[sort] || SORTS.newest;

    const params = [];
    let where = "WHERE UPPER(COALESCE(pl.status, 'ACTIVE')) = 'ACTIVE'";
    if (type) {
      params.push(String(type).toUpperCase());
      where += ` AND UPPER(pl.product_type) = $${params.length}`;
    }

    const result = await pool.query(
      `SELECT ${LISTING_COLUMNS}, u.latitude, u.longitude
       FROM product_listings pl
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       LEFT JOIN users u ON u.id = eo.user_id
       ${where}
       ORDER BY ${orderBy}, pl.id DESC`,
      params
    );

    let rows = withDistance(
      result.rows,
      parseCoords(req.query.lat, req.query.lng),
      parseRadius(req.query.radiusKm)
    );

    const minQuantity = Number(req.query.minQuantity);
    if (minQuantity > 0) {
      rows = rows.filter((row) => Number(row.quantity) >= minQuantity);
    }

    const from = dayOf(req.query.requiredDate);
    if (req.query.requiredDate && !/^\d{4}-\d{2}-\d{2}$/.test(from)) {
      return res.status(400).json({ message: "requiredDate must be YYYY-MM-DD" });
    }
    if (from) {
      const to = addDays(from, 7);
      rows = rows.filter((row) => {
        const day = dayOf(row.available_date);
        return day !== null && day >= from && day <= to;
      });
    }

    if (sort === "nearest") rows.sort(byDistance);

    return res.status(200).json(rows.map(hideCoords));
  } catch (error) {
    return serverError(res, "Get listings", error);
  }
};

/*
|--------------------------------------------------------------------------
| GET ONE LISTING
|--------------------------------------------------------------------------
*/
const getListing = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ${LISTING_COLUMNS}
       FROM product_listings pl
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       WHERE pl.id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Listing not found" });
    }

    return res.status(200).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Get listing", error);
  }
};

/*
|--------------------------------------------------------------------------
| CREATE BUYER REQUEST (as the logged-in buyer)
|--------------------------------------------------------------------------
*/
const createRequest = async (req, res) => {
  try {
    const { productType, requestedQuantity, requiredDate, biddingPricePerUnit } =
      req.body;

    if (!productType || !requestedQuantity || !requiredDate || !biddingPricePerUnit) {
      return res.status(400).json({
        message: "All required fields must be filled",
      });
    }

    const buyer = await pool.query(
      "SELECT name, location FROM users WHERE id = $1",
      [req.user.id]
    );
    if (buyer.rows.length === 0) {
      return res.status(404).json({ message: "Account not found" });
    }

    const result = await pool.query(
      `INSERT INTO buyer_requests
      (
        buyer_id,
        buyer_name,
        location,
        product_type,
        requested_quantity,
        required_date,
        bidding_price_per_unit
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *`,
      [
        req.user.id,
        buyer.rows[0].name,
        req.body.location || buyer.rows[0].location,
        String(productType).toUpperCase(),
        requestedQuantity,
        requiredDate,
        biddingPricePerUnit,
      ]
    );

    return res.status(201).json({
      message: "Buyer request created successfully",
      buyerRequest: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Create buyer request", error);
  }
};

/*
|--------------------------------------------------------------------------
| GET MY REQUESTS
|--------------------------------------------------------------------------
*/
const getMyRequests = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT br.*, COALESCE(rc.response_count, 0) AS response_count
       FROM buyer_requests br
       LEFT JOIN (
         SELECT buyer_request_id, COUNT(*) AS response_count
         FROM sell_requests
         GROUP BY buyer_request_id
       ) rc ON rc.buyer_request_id = br.id
       WHERE br.buyer_id = $1
       ORDER BY br.created_at DESC, br.id DESC`,
      [req.user.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get my requests", error);
  }
};

/*
|--------------------------------------------------------------------------
| ESTATE OWNERS' OFFERS ON MY REQUEST
|--------------------------------------------------------------------------
*/
const getRequestResponses = async (req, res) => {
  try {
    const own = await pool.query(
      "SELECT id FROM buyer_requests WHERE id = $1 AND buyer_id = $2",
      [req.params.id, req.user.id]
    );
    if (own.rows.length === 0) {
      return res.status(404).json({ message: "Request not found" });
    }

    const result = await pool.query(
      `SELECT
        sr.*,
        eo.estate_name,
        eo.name AS owner_name,
        eo.location,
        eo.trust_score
       FROM sell_requests sr
       LEFT JOIN estate_owners eo ON eo.id = sr.estate_owner_id
       WHERE sr.buyer_request_id = $1
       ORDER BY sr.seller_price_per_unit ASC, sr.id ASC`,
      [req.params.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get request responses", error);
  }
};

/*
|--------------------------------------------------------------------------
| ACCEPT AN ESTATE OWNER'S OFFER -> creates an order
|--------------------------------------------------------------------------
| Closes the request: the chosen offer is accepted, the others declined.
*/
const acceptResponse = async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const offer = await client.query(
      `SELECT sr.*, br.status AS request_status
       FROM sell_requests sr
       JOIN buyer_requests br ON br.id = sr.buyer_request_id
       WHERE sr.id = $1 AND br.buyer_id = $2`,
      [req.params.id, req.user.id]
    );
    const sellRequest = offer.rows[0];
    if (!sellRequest) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Offer not found" });
    }
    if (String(sellRequest.request_status || "PENDING").toUpperCase() !== "PENDING") {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "This request is already closed" });
    }

    const price = Number(sellRequest.seller_price_per_unit);
    const total = price * Number(sellRequest.quantity);

    const order = await client.query(
      `INSERT INTO orders
        (buyer_request_id, buyer_id, final_price_per_unit, total_value, status)
       VALUES ($1, $2, $3, $4, 'ACCEPTED')
       RETURNING *`,
      [sellRequest.buyer_request_id, req.user.id, price, total]
    );

    await client.query(
      `UPDATE sell_requests
       SET status = CASE WHEN id = $1 THEN 'accepted' ELSE 'declined' END
       WHERE buyer_request_id = $2`,
      [sellRequest.id, sellRequest.buyer_request_id]
    );
    await client.query(
      "UPDATE buyer_requests SET status = 'ACCEPTED' WHERE id = $1",
      [sellRequest.buyer_request_id]
    );

    await client.query("COMMIT");

    return res.status(201).json({
      message: "Offer accepted",
      order: order.rows[0],
    });
  } catch (error) {
    await client.query("ROLLBACK");
    return serverError(res, "Accept offer", error);
  } finally {
    client.release();
  }
};

/*
|--------------------------------------------------------------------------
| PROFILE SUMMARY
|--------------------------------------------------------------------------
*/
const getSummary = async (req, res) => {
  try {
    const count = async (sql) =>
      Number((await pool.query(sql, [req.user.id])).rows[0].count);

    const openRequests = await count(
      `SELECT COUNT(*) AS count FROM buyer_requests
       WHERE buyer_id = $1 AND UPPER(COALESCE(status, 'PENDING')) = 'PENDING'`
    );
    const openChats = await count(
      `SELECT COUNT(*) AS count FROM negotiations
       WHERE buyer_id = $1 AND status = 'OPEN'`
    );
    const ordersActive = await count(
      `SELECT COUNT(*) AS count FROM orders
       WHERE buyer_id = $1 AND status = 'ACCEPTED'`
    );
    const ordersCompleted = await count(
      `SELECT COUNT(*) AS count FROM orders
       WHERE buyer_id = $1 AND status = 'COMPLETED'`
    );

    return res.status(200).json({
      open_requests: openRequests,
      open_chats: openChats,
      orders_active: ordersActive,
      orders_completed: ordersCompleted,
    });
  } catch (error) {
    return serverError(res, "Get buyer summary", error);
  }
};

/*
|--------------------------------------------------------------------------
| UPDATE MY REQUEST (only while still PENDING)
|--------------------------------------------------------------------------
*/
const updateRequest = async (req, res) => {
  try {
    const { requestedQuantity, requiredDate, biddingPricePerUnit } = req.body;

    if (!requestedQuantity || !requiredDate || !biddingPricePerUnit) {
      return res.status(400).json({
        message: "Quantity, required date and price are required",
      });
    }

    const result = await pool.query(
      `UPDATE buyer_requests
       SET requested_quantity = $3,
           required_date = $4,
           bidding_price_per_unit = $5
       WHERE id = $1 AND buyer_id = $2 AND status = 'PENDING'
       RETURNING *`,
      [req.params.id, req.user.id, requestedQuantity, requiredDate, biddingPricePerUnit]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "No pending request of yours with that id",
      });
    }

    return res.status(200).json({
      message: "Request updated",
      buyerRequest: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Update buyer request", error);
  }
};

/*
|--------------------------------------------------------------------------
| DELETE MY REQUEST
|--------------------------------------------------------------------------
| Refused once an estate owner has responded with a sell request or an order
| refers to it, so their records are never left pointing at nothing.
*/
const deleteRequest = async (req, res) => {
  try {
    const own = await pool.query(
      "SELECT id FROM buyer_requests WHERE id = $1 AND buyer_id = $2",
      [req.params.id, req.user.id]
    );
    if (own.rows.length === 0) {
      return res.status(404).json({ message: "Request not found" });
    }

    const responses = await pool.query(
      `SELECT
        (SELECT COUNT(*) FROM sell_requests WHERE buyer_request_id = $1) AS sells,
        (SELECT COUNT(*) FROM orders WHERE buyer_request_id = $1) AS orders`,
      [req.params.id]
    );
    const { sells, orders } = responses.rows[0];
    if (Number(sells) > 0 || Number(orders) > 0) {
      return res.status(409).json({
        message: "Estate owners have already responded to this request, so it can't be deleted",
      });
    }

    await pool.query("DELETE FROM buyer_requests WHERE id = $1", [req.params.id]);

    return res.status(200).json({ message: "Request deleted" });
  } catch (error) {
    return serverError(res, "Delete buyer request", error);
  }
};

/*
|--------------------------------------------------------------------------
| NEGOTIATIONS
|--------------------------------------------------------------------------
*/
const getMyNegotiations = async (req, res) => {
  try {
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
        eo.estate_name,
        eo.name AS owner_name,
        COALESCE(mc.message_count, 0) AS message_count
       FROM negotiations n
       JOIN product_listings pl ON pl.id = n.listing_id
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       LEFT JOIN orders o ON o.id = n.order_id
       LEFT JOIN (
         SELECT negotiation_id, COUNT(*) AS message_count
         FROM negotiation_messages
         GROUP BY negotiation_id
       ) mc ON mc.negotiation_id = n.id
       WHERE n.buyer_id = $1
       ORDER BY n.created_at DESC, n.id DESC`,
      [req.user.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get my negotiations", error);
  }
};


// Loads a negotiation only if it belongs to the logged-in buyer.
const findOwnNegotiation = async (db, negotiationId, buyerId) => {
  const result = await db.query(
    `SELECT n.*, pl.quantity, pl.offer_price_per_unit
     FROM negotiations n
     JOIN product_listings pl ON pl.id = n.listing_id
     WHERE n.id = $1 AND n.buyer_id = $2`,
    [negotiationId, buyerId]
  );
  return result.rows[0];
};

const startNegotiation = async (req, res) => {
  try {
    const { listingId } = req.body;

    if (!listingId) {
      return res.status(400).json({ message: "listingId is required" });
    }

    const listing = await pool.query(
      "SELECT id FROM product_listings WHERE id = $1",
      [listingId]
    );
    if (listing.rows.length === 0) {
      return res.status(404).json({ message: "Listing not found" });
    }

    // Reopen the buyer's existing conversation instead of starting a second.
    const existing = await pool.query(
      `SELECT * FROM negotiations
       WHERE listing_id = $1 AND buyer_id = $2 AND status = 'OPEN'
       ORDER BY id DESC
       LIMIT 1`,
      [listingId, req.user.id]
    );
    if (existing.rows.length > 0) {
      return res.status(200).json(existing.rows[0]);
    }

    const result = await pool.query(
      `INSERT INTO negotiations (listing_id, buyer_id)
       VALUES ($1, $2)
       RETURNING *`,
      [listingId, req.user.id]
    );

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    return serverError(res, "Start negotiation", error);
  }
};

const getNegotiation = async (req, res) => {
  try {
    const negotiation = await findOwnNegotiation(pool, req.params.id, req.user.id);
    if (!negotiation) {
      return res.status(404).json({ message: "Negotiation not found" });
    }

    const listing = await pool.query(
      `SELECT ${LISTING_COLUMNS}
       FROM product_listings pl
       LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
       WHERE pl.id = $1`,
      [negotiation.listing_id]
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
      messages: messages.rows,
    });
  } catch (error) {
    return serverError(res, "Get negotiation", error);
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

    const negotiation = await findOwnNegotiation(pool, req.params.id, req.user.id);
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
    return serverError(res, "Send message", error);
  }
};

/*
|--------------------------------------------------------------------------
| ACCEPT DEAL -> creates an order
|--------------------------------------------------------------------------
| The buyer accepts the estate owner's latest counter-offer, or the listed
| price if the owner has not countered.
*/
const acceptNegotiation = async (req, res) => {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const negotiation = await findOwnNegotiation(client, req.params.id, req.user.id);
    if (!negotiation) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Negotiation not found" });
    }
    if (negotiation.status !== "OPEN") {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "This negotiation is closed" });
    }

    const ownerOffer = await client.query(
      `SELECT offer_price_per_unit
       FROM negotiation_messages
       WHERE negotiation_id = $1
         AND sender_id <> $2
         AND offer_price_per_unit IS NOT NULL
       ORDER BY created_at DESC, id DESC
       LIMIT 1`,
      [negotiation.id, req.user.id]
    );

    const finalPrice = Number(
      ownerOffer.rows[0]?.offer_price_per_unit ?? negotiation.offer_price_per_unit
    );
    const totalValue = finalPrice * Number(negotiation.quantity);

    const order = await client.query(
      `INSERT INTO orders
        (listing_id, buyer_id, final_price_per_unit, total_value, status)
       VALUES ($1, $2, $3, $4, 'ACCEPTED')
       RETURNING *`,
      [negotiation.listing_id, req.user.id, finalPrice, totalValue]
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
    return serverError(res, "Accept negotiation", error);
  } finally {
    client.release();
  }
};

const rejectNegotiation = async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE negotiations
       SET status = 'REJECTED'
       WHERE id = $1 AND buyer_id = $2 AND status = 'OPEN'
       RETURNING *`,
      [req.params.id, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "No open negotiation found to reject",
      });
    }

    return res.status(200).json({
      message: "Offer rejected",
      negotiation: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Reject negotiation", error);
  }
};

/*
|--------------------------------------------------------------------------
| ORDERS
|--------------------------------------------------------------------------
*/
const getMyOrders = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        o.*,
        COALESCE(pl.product_type, sr.product_type) AS product_type,
        COALESCE(pl.quantity, sr.quantity) AS quantity,
        eo.estate_name,
        eo.name AS owner_name,
        n.id AS negotiation_id
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
       LEFT JOIN estate_owners eo
         ON eo.id = COALESCE(pl.estate_owner_id, sr.estate_owner_id)
       LEFT JOIN negotiations n ON n.order_id = o.id
       WHERE o.buyer_id = $1
       ORDER BY o.created_at DESC, o.id DESC`,
      [req.user.id]
    );

    return res.status(200).json(result.rows);
  } catch (error) {
    return serverError(res, "Get my orders", error);
  }
};

const completeOrder = async (req, res) => {
  try {
    const result = await pool.query(
      `UPDATE orders
       SET status = 'COMPLETED'
       WHERE id = $1 AND buyer_id = $2 AND status = 'ACCEPTED'
       RETURNING *`,
      [req.params.id, req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        message: "No accepted order found to complete",
      });
    }

    return res.status(200).json({
      message: "Transaction completed",
      order: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Complete order", error);
  }
};

module.exports = {
  getListings,
  getListing,
  createRequest,
  getMyRequests,
  getSummary,
  getRequestResponses,
  acceptResponse,
  updateRequest,
  deleteRequest,
  getMyNegotiations,
  startNegotiation,
  getNegotiation,
  sendMessage,
  acceptNegotiation,
  rejectNegotiation,
  getMyOrders,
  completeOrder,
};

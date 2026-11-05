const pool = require("../config/db");
const { listChats } = require("./chatController");
const { withDueDate, DUE_DATE_COLUMNS } = require("../utils/geo");

/*
|--------------------------------------------------------------------------
| ORDERS TAB - one overview for buyers and estate owners
|--------------------------------------------------------------------------
|   pending       offers I put out that wait for the other side:
|                 my price offers in chats, and (estate owners) my offers
|                 on buyer requests. Buyers' own requests come from
|                 /api/buyer/requests.
|   negotiations  chats still open
|   deals         accepted orders not yet completed
|   transactions  completed orders, with any price dispute
*/

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  return res.status(500).json({ message: "Server error", error: error.message });
};

/** Every order I'm the buyer or the estate owner of. */
const myOrders = async (userId) => {
  const result = await pool.query(
    `SELECT
      o.*,
      COALESCE(pl.product_type, sr.product_type) AS product_type,
      COALESCE(pl.quantity, sr.quantity) AS quantity,
      ${DUE_DATE_COLUMNS},
      eo1.estate_name AS listing_estate,
      eo2.estate_name AS offer_estate,
      eo1.user_id AS listing_owner,
      eo2.user_id AS offer_owner,
      u.name AS buyer_user_name,
      br.buyer_name AS request_buyer_name,
      n.id AS negotiation_id
     FROM orders o
     LEFT JOIN product_listings pl ON pl.id = o.listing_id
     LEFT JOIN sell_requests sr
       ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
     LEFT JOIN buyer_requests br ON br.id = o.buyer_request_id
     LEFT JOIN estate_owners eo1 ON eo1.id = pl.estate_owner_id
     LEFT JOIN estate_owners eo2 ON eo2.id = sr.estate_owner_id
     LEFT JOIN users u ON u.id = o.buyer_id
     LEFT JOIN negotiations n ON n.order_id = o.id
     WHERE o.buyer_id = $1 OR eo1.user_id = $1 OR eo2.user_id = $1
     ORDER BY o.created_at DESC, o.id DESC`,
    [userId]
  );

  return result.rows.map(withDueDate).map((row) => {
    const iAmBuyer = row.buyer_id === userId;
    const {
      listing_estate,
      offer_estate,
      listing_owner,
      offer_owner,
      buyer_user_name,
      request_buyer_name,
      ...order
    } = row;
    return {
      ...order,
      my_role: iAmBuyer ? "BUYER" : "ESTATE_OWNER",
      counterpart_name: iAmBuyer
        ? listing_estate || offer_estate || "Estate"
        : buyer_user_name || request_buyer_name || "Buyer",
    };
  });
};

const myPendingSellOffers = async (userId) => {
  const result = await pool.query(
    `SELECT sr.id, sr.buyer_request_id, sr.product_type, sr.quantity,
            sr.seller_price_per_unit, sr.available_date, sr.created_at,
            br.buyer_name, br.required_date, br.requested_quantity,
            br.bidding_price_per_unit, n.id AS negotiation_id
     FROM sell_requests sr
     JOIN estate_owners eo ON eo.id = sr.estate_owner_id
     JOIN buyer_requests br ON br.id = sr.buyer_request_id
     LEFT JOIN negotiations n ON n.sell_request_id = sr.id
     WHERE eo.user_id = $1
       AND LOWER(COALESCE(sr.status, 'pending')) = 'pending'
       AND UPPER(COALESCE(br.status, 'PENDING')) = 'PENDING'
     ORDER BY sr.created_at DESC, sr.id DESC`,
    [userId]
  );
  return result.rows.map((row) => ({
    kind: "SELL_OFFER",
    id: row.id,
    request_id: row.buyer_request_id,
    negotiation_id: row.negotiation_id ?? null,
    counterpart_name: row.buyer_name || "Buyer",
    product_type: row.product_type,
    quantity: row.quantity,
    price: row.seller_price_per_unit,
    their_price: row.bidding_price_per_unit,
    date: row.required_date,
    created_at: row.created_at,
  }));
};

const getActivity = async (req, res) => {
  try {
    const userId = req.user.id;
    const chats = await listChats(pool, userId);
    const orders = await myOrders(userId);

    // Offers on buyer requests are listed once, as the offer (below).
    const chatOffers = chats
      .filter((chat) => chat.my_pending_offer && !chat.sell_request_id)
      .map((chat) => ({
        kind: "CHAT_OFFER",
        id: chat.my_pending_offer.id,
        negotiation_id: chat.id,
        counterpart_name: chat.counterpart_name,
        product_type: chat.product_type,
        quantity: chat.quantity,
        price: chat.my_pending_offer.offer_price_per_unit,
        their_price: chat.listed_price,
        created_at: chat.my_pending_offer.created_at,
      }));

    const sellOffers =
      req.user.role === "ESTATE_OWNER" ? await myPendingSellOffers(userId) : [];

    return res.status(200).json({
      pending: [...chatOffers, ...sellOffers].sort(
        (a, b) => new Date(b.created_at) - new Date(a.created_at)
      ),
      negotiations: chats.filter((chat) => chat.status === "OPEN"),
      deals: orders
        .filter((order) => order.status === "ACCEPTED")
        .sort((a, b) =>
          String(a.due_date ?? "9999").localeCompare(String(b.due_date ?? "9999"))
        ),
      transactions: orders
        .filter((order) => order.status === "COMPLETED")
        .sort(
          (a, b) =>
            new Date(b.completed_at || b.created_at) -
            new Date(a.completed_at || a.created_at)
        ),
    });
  } catch (error) {
    return serverError(res, "Get activity", error);
  }
};

module.exports = { getActivity, myOrders };

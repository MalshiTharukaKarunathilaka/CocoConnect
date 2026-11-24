const pool = require("../config/db");
const { listChats } = require("./chatController");
const { withDueDate, DUE_DATE_COLUMNS } = require("../utils/geo");
const { coconutTrustScores, coconutCounterpartProfile } = require("./coconutReviewController");

/*
|--------------------------------------------------------------------------
| ORDERS TAB - one overview for buyers and land owners
|--------------------------------------------------------------------------
|   pending       offers I put out that wait for the other side:
|                 my price offers in chats, and (land owners) my offers
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

/** Every order I'm the buyer or the land owner of. */
const myOrders = async (userId, orderId = null) => {
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
      br.buyer_id AS request_buyer_id,
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
     WHERE (COALESCE(o.buyer_id, br.buyer_id) = $1
       OR COALESCE(eo1.user_id, eo2.user_id) = $1)
       ${orderId == null ? "" : "AND o.id = $2"}
     ORDER BY o.created_at DESC, o.id DESC`,
    orderId == null ? [userId] : [userId, orderId]
  );

  return result.rows.map(withDueDate).map((row) => {
    const buyerId = row.buyer_id ?? row.request_buyer_id;
    const iAmBuyer = buyerId === userId;
    const {
      listing_estate,
      offer_estate,
      listing_owner,
      offer_owner,
      buyer_user_name,
      request_buyer_name,
      request_buyer_id,
      buyer_rating_note,
      owner_rating_note,
      ...order
    } = row;
    return {
      ...order,
      my_rating: iAmBuyer ? row.buyer_rating : row.owner_rating,
      counterpart_rating: iAmBuyer ? row.owner_rating : row.buyer_rating,
      my_rating_note: (iAmBuyer ? buyer_rating_note : owner_rating_note) ?? null,
      counterpart_rating_note: (iAmBuyer ? owner_rating_note : buyer_rating_note) ?? null,
      my_role: iAmBuyer ? "BUYER" : "ESTATE_OWNER",
      counterpart_user_id: iAmBuyer ? listing_owner ?? offer_owner : buyerId,
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
            br.buyer_name, br.buyer_id, br.required_date, br.requested_quantity,
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
    counterpart_user_id: row.buyer_id,
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
        counterpart_user_id: chat.counterpart_user_id,
        product_type: chat.product_type,
        quantity: chat.quantity,
        price: chat.my_pending_offer.offer_price_per_unit,
        their_price: chat.listed_price,
        created_at: chat.my_pending_offer.created_at,
      }));

    const sellOffers =
      req.user.role === "ESTATE_OWNER" ? await myPendingSellOffers(userId) : [];
    const pending = [...chatOffers, ...sellOffers];
    const negotiations = chats.filter(chat => chat.status === "OPEN");
    const activeOrders = orders.filter(order =>
      ["ACCEPTED", "AWAITING_RECEIPT", "COMPLETED"].includes(order.status));
    const counterpartIds = [...new Set(
      [...pending, ...negotiations, ...activeOrders]
        .map(item => item.counterpart_user_id)
        .filter(id => id != null),
    )];
    const scores = await coconutTrustScores(
      counterpartIds, req.user.role === "BUYER" ? "ESTATE_OWNER" : "BUYER");
    const withScore = ({counterpart_user_id, ...item}) => ({
      ...item,
      counterpart_trust_score: scores.get(counterpart_user_id) ?? null,
    });

    return res.status(200).json({
      pending: pending.map(withScore).sort(
        (a, b) => new Date(b.created_at) - new Date(a.created_at)
      ),
      negotiations: negotiations.map(withScore),
      deals: activeOrders
        .filter((order) => ["ACCEPTED", "AWAITING_RECEIPT"].includes(order.status))
        .map(withScore)
        .sort((a, b) =>
          String(a.due_date ?? "9999").localeCompare(String(b.due_date ?? "9999"))
        ),
      transactions: activeOrders
        .filter((order) => order.status === "COMPLETED")
        .map(withScore)
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

const getOrderCounterpart = async (req, res) => {
  try {
    const [order] = await myOrders(req.user.id, req.params.id);
    if (!order) return res.status(404).json({message: "Order not found"});
    return res.json(await coconutCounterpartProfile(
      order.counterpart_user_id,
      order.my_role === "BUYER" ? "ESTATE_OWNER" : "BUYER",
      order.counterpart_name,
    ));
  } catch (error) {
    return serverError(res, "Get order profile", error);
  }
};

const getSellOfferCounterpart = async (req, res) => {
  try {
    const {rows: [offer]} = await pool.query(
      `SELECT br.buyer_id, br.buyer_name, eo.user_id AS owner_id, eo.estate_name
       FROM sell_requests sr
       JOIN buyer_requests br ON br.id = sr.buyer_request_id
       JOIN estate_owners eo ON eo.id = sr.estate_owner_id
       WHERE sr.id = $1 AND (br.buyer_id = $2 OR eo.user_id = $2)`,
      [req.params.id, req.user.id],
    );
    if (!offer) return res.status(404).json({message: "Offer not found"});
    const isBuyer = req.user.id === offer.buyer_id;
    return res.json(await coconutCounterpartProfile(
      isBuyer ? offer.owner_id : offer.buyer_id,
      isBuyer ? "ESTATE_OWNER" : "BUYER",
      isBuyer ? offer.estate_name : offer.buyer_name,
    ));
  } catch (error) {
    return serverError(res, "Get offer profile", error);
  }
};

const sriLankaDate = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Asia/Colombo",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

const getOwnerHandoverCount = async (req, res) => {
  try {
    const today = sriLankaDate.format(new Date());
    const orders = await myOrders(req.user.id);
    const due = new Set(orders.filter(order =>
      order.my_role === "ESTATE_OWNER" &&
      order.status === "ACCEPTED" &&
      order.due_date === today
    ).map(order => order.id));
    return res.json({count: due.size});
  } catch (error) {
    return serverError(res, "Get orders to hand over today", error);
  }
};

module.exports = {
  getActivity, myOrders, getOrderCounterpart, getSellOfferCounterpart,
  getOwnerHandoverCount,
};

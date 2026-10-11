const pool = require("../config/db");
const { listChats } = require("./chatController");
const { addDays, withDueDate, DUE_DATE_COLUMNS } = require("../utils/geo");

/*
|--------------------------------------------------------------------------
| NOTIFICATIONS
|--------------------------------------------------------------------------
| Built from what is waiting for the user right now, so they clear
| themselves once acted on:
|   OFFER       a price offer from the other side, waiting in a chat
|   SELL_OFFER  (buyers) an estate's offer on one of my requests
|   DELIVERY    an order not yet completed, due within UPCOMING_DAYS
*/

const UPCOMING_DAYS = 7;

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  return res.status(500).json({ message: "Server error", error: error.message });
};

/** Today as "YYYY-MM-DD" in the server's local time zone. */
const localToday = () => {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
};

const daysBetween = (from, to) =>
  Math.round((new Date(`${to}T00:00:00Z`) - new Date(`${from}T00:00:00Z`)) / 86400000);

const NAMES = {
  RAW_COCONUT: "raw coconuts",
  HUSKED_COCONUT: "husked coconuts",
  DEHUSKED_COCONUT: "dehusked coconuts",
};
const productName = (type) =>
  NAMES[String(type || "").toUpperCase()] || "coconuts";

const nuts = (n) => Number(n || 0).toLocaleString("en-US");
const rupees = (n) => `Rs. ${Number(n || 0).toLocaleString("en-US")}`;

const offerItems = async (userId) =>
  (await listChats(pool, userId))
    .filter((chat) => chat.waiting_offer)
    .map((chat) => ({
      key: `offer-${chat.waiting_offer.id}`,
      type: "OFFER",
      title: `New offer from ${chat.counterpart_name}`,
      body:
        `${rupees(chat.waiting_offer.offer_price_per_unit)} / nut for ` +
        `${nuts(chat.quantity)} ${productName(chat.product_type)}. ` +
        "Accept or reject it in the chat.",
      at: chat.waiting_offer.created_at,
      negotiation_id: chat.id,
    }));

/** Orders not yet completed, due within the next week (or overdue). */
const deliveryItems = (rows, role) => {
  const today = localToday();
  const until = addDays(today, UPCOMING_DAYS);
  return rows
    .map(withDueDate)
    .map((row) => ({ ...row, due: row.due_date }))
    .filter((row) => row.due && row.due <= until)
    .map((row) => {
      const days = daysBetween(today, row.due);
      const when =
        days < 0
          ? `was due ${-days} day${days === -1 ? "" : "s"} ago`
          : days === 0
            ? "is due today"
            : days === 1
              ? "is due tomorrow"
              : `is due in ${days} days`;
      const what = `${nuts(row.quantity)} ${productName(row.product_type)}`;
      return {
        key: `delivery-${row.id}-${row.due}`,
        type: "DELIVERY",
        title:
          role === "BUYER"
            ? `Order #${row.id} ${when}`
            : `Delivery to ${row.counterpart} ${when}`,
        body:
          role === "BUYER"
            ? `${what} from ${row.counterpart}, total ${rupees(row.total_value)}.`
            : `${what}, total ${rupees(row.total_value)}. Complete the deal once delivered.`,
        at: `${row.due}T00:00:00.000Z`,
        due_date: row.due,
        urgent: days <= 1,
        order_id: row.id,
        negotiation_id: row.negotiation_id ?? null,
      };
    });
};

const ORDER_COLUMNS = `
  o.id,
  o.total_value,
  COALESCE(pl.product_type, sr.product_type) AS product_type,
  COALESCE(pl.quantity, sr.quantity) AS quantity,
  ${DUE_DATE_COLUMNS},
  n.id AS negotiation_id
`;

const ORDER_JOINS = `
  FROM orders o
  LEFT JOIN product_listings pl ON pl.id = o.listing_id
  LEFT JOIN sell_requests sr
    ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
  LEFT JOIN buyer_requests br ON br.id = o.buyer_request_id
  LEFT JOIN negotiations n ON n.order_id = o.id
`;

const buyerNotifications = async (userId) => {
  const sellOffers = await pool.query(
    `SELECT sr.id, sr.seller_price_per_unit, sr.quantity, sr.product_type,
            sr.created_at, br.id AS request_id, eo.estate_name, eo.name AS owner_name
     FROM sell_requests sr
     JOIN buyer_requests br ON br.id = sr.buyer_request_id
     LEFT JOIN estate_owners eo ON eo.id = sr.estate_owner_id
     WHERE br.buyer_id = $1
       AND LOWER(COALESCE(sr.status, 'pending')) = 'pending'
       AND UPPER(COALESCE(br.status, 'PENDING')) = 'PENDING'`,
    [userId]
  );

  const orders = await pool.query(
    `SELECT ${ORDER_COLUMNS},
            COALESCE(eo1.estate_name, eo2.estate_name, 'the estate') AS counterpart
     ${ORDER_JOINS}
     LEFT JOIN estate_owners eo1 ON eo1.id = pl.estate_owner_id
     LEFT JOIN estate_owners eo2 ON eo2.id = sr.estate_owner_id
     WHERE o.buyer_id = $1 AND o.status = 'ACCEPTED'`,
    [userId]
  );

  return [
    ...(await offerItems(userId)),
    ...sellOffers.rows.map((row) => ({
      key: `sell-offer-${row.id}`,
      type: "SELL_OFFER",
      title: `${row.estate_name || row.owner_name || "An estate"} answered your request`,
      body:
        `${rupees(row.seller_price_per_unit)} / nut for ${nuts(row.quantity)} ` +
        `${productName(row.product_type)}. Accept it in My Activity.`,
      at: row.created_at,
      request_id: row.request_id,
    })),
    ...deliveryItems(orders.rows, "BUYER"),
  ];
};

const ownerNotifications = async (userId) => {
  const orders = await pool.query(
    `SELECT ${ORDER_COLUMNS},
            COALESCE(u.name, br.buyer_name, 'the buyer') AS counterpart
     ${ORDER_JOINS}
     LEFT JOIN users u ON u.id = o.buyer_id
     LEFT JOIN estate_owners eo1 ON eo1.id = pl.estate_owner_id
     LEFT JOIN estate_owners eo2 ON eo2.id = sr.estate_owner_id
     WHERE o.status = 'ACCEPTED' AND (eo1.user_id = $1 OR eo2.user_id = $1)`,
    [userId]
  );

  return [...(await offerItems(userId)), ...deliveryItems(orders.rows, "ESTATE_OWNER")];
};

/** Urgent deliveries first, then the newest offers, then other deliveries. */
const rank = (item) => (item.urgent ? 0 : item.type === "DELIVERY" ? 2 : 1);

const getNotifications = async (req, res) => {
  try {
    const items =
      req.user.role === "BUYER"
        ? await buyerNotifications(req.user.id)
        : await ownerNotifications(req.user.id);

    items.sort((a, b) => {
      if (rank(a) !== rank(b)) return rank(a) - rank(b);
      if (a.type === "DELIVERY") return a.due_date.localeCompare(b.due_date);
      return new Date(b.at) - new Date(a.at);
    });

    return res.status(200).json(items);
  } catch (error) {
    return serverError(res, "Get notifications", error);
  }
};

module.exports = { getNotifications, localToday };

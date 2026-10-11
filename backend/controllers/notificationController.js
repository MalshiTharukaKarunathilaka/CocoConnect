const pool = require("../config/db");
const { listChats } = require("./chatController");

/*
|--------------------------------------------------------------------------
| ALERTS
|--------------------------------------------------------------------------
| Built from what is waiting for the user right now, so they clear
| themselves once acted on:
|   OFFER       a price offer from the other side, waiting in a chat
|   CHAT        new messages from the other side
|   SELL_OFFER  (buyers) an estate's offer on one of my requests that has
|               no chat (offers made before offer chats existed)
*/

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  return res.status(500).json({ message: "Server error", error: error.message });
};

const NAMES = {
  RAW_COCONUT: "raw coconuts",
  HUSKED_COCONUT: "husked coconuts",
  DEHUSKED_COCONUT: "dehusked coconuts",
};
const productName = (type) => NAMES[String(type || "").toUpperCase()] || "coconuts";

const nuts = (n) => Number(n || 0).toLocaleString("en-US");
const rupees = (n) => `Rs. ${Number(n || 0).toLocaleString("en-US")}`;

const chatItems = async (userId) => {
  const chats = await listChats(pool, userId);
  const items = [];

  for (const chat of chats) {
    if (chat.waiting_offer) {
      items.push({
        key: `offer-${chat.waiting_offer.id}`,
        type: "OFFER",
        title: `New offer from ${chat.counterpart_name}`,
        body:
          `${rupees(chat.waiting_offer.offer_price_per_unit)} / nut for ` +
          `${nuts(chat.quantity)} ${productName(chat.product_type)}. ` +
          "Accept or reject it in the chat.",
        at: chat.waiting_offer.created_at,
        negotiation_id: chat.id,
      });
    }

    // Plain messages; an unanswered offer above already covers its own.
    const last = chat.last_message;
    if (
      chat.unread_count > 0 &&
      last &&
      !last.is_mine &&
      last.offer_price_per_unit == null
    ) {
      items.push({
        key: `chat-${last.id}`,
        type: "CHAT",
        title:
          chat.unread_count === 1
            ? `New message from ${chat.counterpart_name}`
            : `${chat.unread_count} new messages from ${chat.counterpart_name}`,
        body: last.text || "",
        at: last.created_at,
        negotiation_id: chat.id,
      });
    }
  }
  return items;
};

const sellOfferItems = async (userId) => {
  const result = await pool.query(
    `SELECT sr.id, sr.seller_price_per_unit, sr.quantity, sr.product_type,
            sr.created_at, br.id AS request_id, eo.estate_name, eo.name AS owner_name,
            n.id AS negotiation_id
     FROM sell_requests sr
     JOIN buyer_requests br ON br.id = sr.buyer_request_id
     LEFT JOIN estate_owners eo ON eo.id = sr.estate_owner_id
     LEFT JOIN negotiations n ON n.sell_request_id = sr.id
     WHERE br.buyer_id = $1
       AND LOWER(COALESCE(sr.status, 'pending')) = 'pending'
       AND UPPER(COALESCE(br.status, 'PENDING')) = 'PENDING'`,
    [userId]
  );
  return result.rows
    .filter((row) => row.negotiation_id === null)
    .map((row) => ({
      key: `sell-offer-${row.id}`,
      type: "SELL_OFFER",
      title: `${row.estate_name || row.owner_name || "An estate"} answered your request`,
      body:
        `${rupees(row.seller_price_per_unit)} / nut for ${nuts(row.quantity)} ` +
        `${productName(row.product_type)}. Accept it under Orders.`,
      at: row.created_at,
      request_id: row.request_id,
    }));
};

const getNotifications = async (req, res) => {
  try {
    const items = [
      ...(await chatItems(req.user.id)),
      ...(req.user.role === "BUYER" ? await sellOfferItems(req.user.id) : []),
    ];
    items.sort((a, b) => new Date(b.at) - new Date(a.at));
    return res.status(200).json(items);
  } catch (error) {
    return serverError(res, "Get notifications", error);
  }
};

module.exports = { getNotifications };

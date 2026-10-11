const pool = require("../config/db");
const { dayOf } = require("../utils/geo");

/*
|--------------------------------------------------------------------------
| CHATS - one API for both sides of a negotiation
|--------------------------------------------------------------------------
| A chat is a negotiation on a listing, between the buyer who opened it and
| the estate owner who listed it. Either side can send messages and price
| offers. Only the side that did NOT send an offer can accept or reject it;
| accepting creates the order. Each new offer replaces any still-pending one.
*/

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  return res.status(500).json({ message: "Server error", error: error.message });
};

const hasPrice = (message) =>
  message.offer_price_per_unit !== null && message.offer_price_per_unit !== undefined;

const time = (value) => (value ? new Date(value).getTime() : 0);

/**
 * The negotiation with listing details and the caller's side, or null when
 * the caller is neither its buyer nor the listing's estate owner.
 */
const loadChat = async (db, negotiationId, userId) => {
  const result = await db.query(
    `SELECT
      n.*,
      pl.product_type,
      pl.quantity,
      pl.offer_price_per_unit AS listed_price,
      pl.available_date,
      eo.user_id AS owner_user_id,
      eo.estate_name,
      eo.name AS owner_name,
      eo.location AS estate_location,
      u.name AS buyer_name,
      u.location AS buyer_location
     FROM negotiations n
     JOIN product_listings pl ON pl.id = n.listing_id
     LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
     JOIN users u ON u.id = n.buyer_id
     WHERE n.id = $1`,
    [negotiationId]
  );
  const chat = result.rows[0];
  if (!chat) return null;
  if (chat.buyer_id === userId) return { ...chat, role: "BUYER" };
  if (chat.owner_user_id === userId) return { ...chat, role: "ESTATE_OWNER" };
  return null;
};

/**
 * Fills in offer_status. Offers sent before statuses existed have none:
 * the latest one counts as pending while the chat is open. A pending offer
 * in a closed chat is shown as CLOSED.
 */
const withOfferStatus = (messages, chat, orderPrice) => {
  const offers = messages.filter(hasPrice);
  const latest = offers[offers.length - 1];

  return messages.map((message) => {
    if (!hasPrice(message)) return { ...message, offer_status: null };

    let status = message.offer_status;
    if (!status) {
      if (message !== latest) status = "SUPERSEDED";
      else if (chat.status === "OPEN") status = "PENDING";
      else if (
        chat.status === "ACCEPTED" &&
        Number(orderPrice) === Number(message.offer_price_per_unit)
      ) {
        status = "ACCEPTED";
      } else status = "SUPERSEDED";
    }
    if (status === "PENDING" && chat.status !== "OPEN") status = "CLOSED";
    return { ...message, offer_status: status };
  });
};

const loadMessages = async (db, chat) => {
  const result = await db.query(
    `SELECT id, sender_id, message, offer_price_per_unit, offer_status, created_at
     FROM negotiation_messages
     WHERE negotiation_id = $1
     ORDER BY created_at, id`,
    [chat.id]
  );
  const order = chat.order_id
    ? (await db.query("SELECT * FROM orders WHERE id = $1", [chat.order_id])).rows[0]
    : null;
  return {
    order,
    messages: withOfferStatus(result.rows, chat, order?.final_price_per_unit),
  };
};

const lastReadColumn = (role) =>
  role === "BUYER" ? "buyer_last_read_at" : "owner_last_read_at";

/**
 * Saves a message or offer. A new offer replaces any offer still waiting
 * for an answer, so only the latest one can be accepted.
 */
const postMessage = async (db, negotiationId, userId, text, offerPrice) => {
  if (offerPrice) {
    await db.query(
      `UPDATE negotiation_messages
       SET offer_status = 'SUPERSEDED'
       WHERE negotiation_id = $1 AND offer_status = 'PENDING'`,
      [negotiationId]
    );
    // Older offers without a status are superseded implicitly (not latest).
  }

  const result = await db.query(
    `INSERT INTO negotiation_messages
      (negotiation_id, sender_id, message, offer_price_per_unit, offer_status, created_at)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *, true AS is_mine`,
    [
      negotiationId,
      userId,
      text || null,
      offerPrice || null,
      offerPrice ? "PENDING" : null,
      new Date(),
    ]
  );
  return result.rows[0];
};

/** Validates { message, offerPricePerUnit }; returns an error string or null. */
const checkMessageBody = (body) => {
  const text = body.message ? String(body.message).trim() : "";
  const price = body.offerPricePerUnit;
  if (!text && !price) return "Send a message or an offer price";
  if (price && !(Number(price) > 0)) return "Offer price must be above 0";
  return null;
};

const createOrder = async (db, chat, price) => {
  const total = Number(price) * Number(chat.quantity);
  const offer = chat.sell_request_id
    ? (
        await db.query("SELECT * FROM sell_requests WHERE id = $1", [
          chat.sell_request_id,
        ])
      ).rows[0]
    : null;

  const order = await db.query(
    `INSERT INTO orders
      (listing_id, buyer_request_id, buyer_id, final_price_per_unit, total_value, status)
     VALUES ($1, $2, $3, $4, $5, 'ACCEPTED')
     RETURNING *`,
    [
      chat.listing_id,
      offer ? offer.buyer_request_id : null,
      chat.buyer_id,
      Number(price),
      total,
    ]
  );
  await db.query(
    `UPDATE negotiations SET status = 'ACCEPTED', order_id = $2 WHERE id = $1`,
    [chat.id, order.rows[0].id]
  );

  if (offer) await settleRequest(db, offer, price, chat.id);
  return order.rows[0];
};

/**
 * A buyer request got its deal: this estate's offer is accepted at the
 * agreed price, the other estates' offers are declined and their chats
 * closed.
 */
const settleRequest = async (db, offer, price, keepChatId) => {
  await db.query(
    `UPDATE sell_requests
     SET status = CASE WHEN id = $1 THEN 'accepted' ELSE 'declined' END
     WHERE buyer_request_id = $2`,
    [offer.id, offer.buyer_request_id]
  );
  await db.query(
    "UPDATE sell_requests SET seller_price_per_unit = $2 WHERE id = $1",
    [offer.id, Number(price)]
  );
  await db.query("UPDATE buyer_requests SET status = 'ACCEPTED' WHERE id = $1", [
    offer.buyer_request_id,
  ]);

  const others = await db.query(
    `SELECT n.id
     FROM negotiations n
     JOIN sell_requests sr ON sr.id = n.sell_request_id
     WHERE sr.buyer_request_id = $1 AND n.status = 'OPEN'`,
    [offer.buyer_request_id]
  );
  for (const other of others.rows) {
    if (other.id === keepChatId) continue;
    await db.query("UPDATE negotiations SET status = 'REJECTED' WHERE id = $1", [
      other.id,
    ]);
  }
};

/**
 * Opens the chat for an estate's offer on a buyer request. The chat runs on
 * a private listing (status OFFER, hidden from the marketplace) and starts
 * with the offer itself, which the buyer can accept or reject.
 */
const openOfferChat = async (db, { estateId, ownerUserId, offer, request }) => {
  const listing = await db.query(
    `INSERT INTO product_listings
      (estate_owner_id, product_type, quantity, available_date,
       offer_price_per_unit, status)
     VALUES ($1, $2, $3, $4, $5, 'OFFER')
     RETURNING id`,
    [
      estateId,
      offer.product_type,
      offer.quantity,
      offer.available_date || request.required_date,
      offer.seller_price_per_unit,
    ]
  );
  const chat = await db.query(
    `INSERT INTO negotiations (listing_id, buyer_id, sell_request_id)
     VALUES ($1, $2, $3)
     RETURNING id`,
    [listing.rows[0].id, request.buyer_id, offer.id]
  );
  const needed = dayOf(request.required_date);
  await postMessage(
    db,
    chat.rows[0].id,
    ownerUserId,
    `Offer for your request of ${Number(request.requested_quantity).toLocaleString(
      "en-US"
    )} nuts${needed ? ` needed by ${needed}` : ""}.`,
    Number(offer.seller_price_per_unit)
  );
  return chat.rows[0].id;
};

/** One row for the chats list, from the caller's side. */
const summarise = (chat, messages, userId) => {
  const role = chat.buyer_id === userId ? "BUYER" : "ESTATE_OWNER";
  const lastRead = time(chat[lastReadColumn(role)]);
  const statused = withOfferStatus(messages, chat, chat.order_price);
  const last = statused[statused.length - 1];
  const waiting = statused
    .filter((m) => m.sender_id !== userId && m.offer_status === "PENDING")
    .pop();
  const mine = statused
    .filter((m) => m.sender_id === userId && m.offer_status === "PENDING")
    .pop();

  return {
    id: chat.id,
    status: chat.status,
    order_id: chat.order_id,
    order_status: chat.order_status,
    my_role: role,
    counterpart_name:
      role === "BUYER" ? chat.estate_name || chat.owner_name || "Estate" : chat.buyer_name,
    product_type: chat.product_type,
    quantity: chat.quantity,
    listed_price: chat.listed_price,
    // Set when the chat started from an estate's offer on a buyer request.
    sell_request_id: chat.sell_request_id ?? null,
    last_message: last
      ? {
          id: last.id,
          text: last.message,
          offer_price_per_unit: last.offer_price_per_unit,
          offer_status: last.offer_status,
          is_mine: last.sender_id === userId,
          created_at: last.created_at,
        }
      : null,
    last_activity_at: last ? last.created_at : chat.created_at,
    unread_count: statused.filter(
      (m) => m.sender_id !== userId && time(m.created_at) > lastRead
    ).length,
    // An offer from the other side is waiting for my answer.
    offer_waiting: chat.status === "OPEN" && Boolean(waiting),
    waiting_offer:
      chat.status === "OPEN" && waiting
        ? {
            id: waiting.id,
            offer_price_per_unit: waiting.offer_price_per_unit,
            created_at: waiting.created_at,
          }
        : null,
    // My own offer, waiting for the other side.
    my_pending_offer:
      chat.status === "OPEN" && mine
        ? {
            id: mine.id,
            offer_price_per_unit: mine.offer_price_per_unit,
            created_at: mine.created_at,
          }
        : null,
  };
};

/** Every chat the user is in, newest activity first. Shared with notifications. */
const listChats = async (db, userId) => {
  const chats = await db.query(
    `SELECT
      n.id, n.status, n.order_id, n.created_at, n.buyer_id, n.sell_request_id,
      n.buyer_last_read_at, n.owner_last_read_at,
      o.status AS order_status,
      o.final_price_per_unit AS order_price,
      pl.product_type, pl.quantity, pl.offer_price_per_unit AS listed_price,
      eo.estate_name, eo.name AS owner_name,
      u.name AS buyer_name
     FROM negotiations n
     JOIN product_listings pl ON pl.id = n.listing_id
     LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
     JOIN users u ON u.id = n.buyer_id
     LEFT JOIN orders o ON o.id = n.order_id
     WHERE n.buyer_id = $1 OR eo.user_id = $1`,
    [userId]
  );

  const messages = await db.query(
    `SELECT m.id, m.negotiation_id, m.sender_id, m.message,
            m.offer_price_per_unit, m.offer_status, m.created_at
     FROM negotiation_messages m
     JOIN negotiations n ON n.id = m.negotiation_id
     JOIN product_listings pl ON pl.id = n.listing_id
     LEFT JOIN estate_owners eo ON eo.id = pl.estate_owner_id
     WHERE n.buyer_id = $1 OR eo.user_id = $1
     ORDER BY m.created_at, m.id`,
    [userId]
  );

  const byChat = new Map();
  for (const message of messages.rows) {
    if (!byChat.has(message.negotiation_id)) byChat.set(message.negotiation_id, []);
    byChat.get(message.negotiation_id).push(message);
  }

  return chats.rows
    .map((chat) => summarise(chat, byChat.get(chat.id) || [], userId))
    .sort(
      (a, b) => time(b.last_activity_at) - time(a.last_activity_at) || b.id - a.id
    );
};

/*
|--------------------------------------------------------------------------
| ROUTE HANDLERS
|--------------------------------------------------------------------------
*/
const getChats = async (req, res) => {
  try {
    return res.status(200).json(await listChats(pool, req.user.id));
  } catch (error) {
    return serverError(res, "Get chats", error);
  }
};

const getChat = async (req, res) => {
  try {
    const chat = await loadChat(pool, req.params.id, req.user.id);
    if (!chat) return res.status(404).json({ message: "Chat not found" });

    const { order, messages } = await loadMessages(pool, chat);

    // Opening the chat reads it.
    await pool.query(
      `UPDATE negotiations SET ${lastReadColumn(chat.role)} = $2 WHERE id = $1`,
      [chat.id, new Date()]
    );

    const anyOffer = messages.some(hasPrice);
    return res.status(200).json({
      id: chat.id,
      status: chat.status,
      my_role: chat.role,
      order_id: chat.order_id,
      order_status: order?.status ?? null,
      order_price: order?.final_price_per_unit ?? null,
      counterpart_name:
        chat.role === "BUYER"
          ? chat.estate_name || chat.owner_name || "Estate"
          : chat.buyer_name,
      counterpart_location:
        chat.role === "BUYER" ? chat.estate_location : chat.buyer_location,
      listing: {
        id: chat.listing_id,
        product_type: chat.product_type,
        quantity: chat.quantity,
        offer_price_per_unit: chat.listed_price,
        available_date: chat.available_date,
        estate_name: chat.estate_name,
        owner_name: chat.owner_name,
      },
      // The listed price is the estate's opening offer; the buyer can take
      // it until someone sends a different price.
      can_accept_listing: chat.role === "BUYER" && chat.status === "OPEN" && !anyOffer,
      messages: messages.map(({ sender_id, ...message }) => ({
        ...message,
        is_mine: sender_id === req.user.id,
      })),
    });
  } catch (error) {
    return serverError(res, "Get chat", error);
  }
};

const sendChatMessage = async (req, res) => {
  try {
    const problem = checkMessageBody(req.body);
    if (problem) return res.status(400).json({ message: problem });

    const chat = await loadChat(pool, req.params.id, req.user.id);
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.status !== "OPEN") {
      return res.status(409).json({ message: "This negotiation is closed" });
    }

    const message = await postMessage(
      pool,
      chat.id,
      req.user.id,
      req.body.message ? String(req.body.message).trim() : "",
      req.body.offerPricePerUnit ? Number(req.body.offerPricePerUnit) : null
    );
    // An estate's new price in an offer chat updates the offer itself, so
    // the buyer's request shows the latest price.
    if (chat.sell_request_id && chat.role === "ESTATE_OWNER" && req.body.offerPricePerUnit) {
      await pool.query(
        `UPDATE sell_requests SET seller_price_per_unit = $2
         WHERE id = $1 AND LOWER(COALESCE(status, 'pending')) = 'pending'`,
        [chat.sell_request_id, Number(req.body.offerPricePerUnit)]
      );
    }

    // Writing in a chat also means you've seen it.
    await pool.query(
      `UPDATE negotiations SET ${lastReadColumn(chat.role)} = $2 WHERE id = $1`,
      [chat.id, new Date()]
    );
    return res.status(201).json(message);
  } catch (error) {
    return serverError(res, "Send chat message", error);
  }
};

/** Finds a pending offer the caller may answer, or sends the error. */
const findAnswerableOffer = async (db, req, res) => {
  const chat = await loadChat(db, req.params.id, req.user.id);
  if (!chat) {
    res.status(404).json({ message: "Chat not found" });
    return null;
  }
  if (chat.status !== "OPEN") {
    res.status(409).json({ message: "This negotiation is closed" });
    return null;
  }
  const { messages } = await loadMessages(db, chat);
  const offer = messages.find((m) => String(m.id) === String(req.params.messageId));
  if (!offer || !hasPrice(offer)) {
    res.status(404).json({ message: "Offer not found" });
    return null;
  }
  if (offer.sender_id === req.user.id) {
    res.status(403).json({ message: "The other side answers your offer" });
    return null;
  }
  if (offer.offer_status !== "PENDING") {
    res.status(409).json({ message: "This offer was already answered or replaced" });
    return null;
  }
  return { chat, offer };
};

const acceptOffer = async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const found = await findAnswerableOffer(client, req, res);
    if (!found) {
      await client.query("ROLLBACK");
      return undefined;
    }
    const { chat, offer } = found;

    const order = await createOrder(client, chat, offer.offer_price_per_unit);
    await client.query(
      `UPDATE negotiation_messages SET offer_status = 'ACCEPTED' WHERE id = $1`,
      [offer.id]
    );
    await client.query(
      `UPDATE negotiation_messages SET offer_status = 'SUPERSEDED'
       WHERE negotiation_id = $1 AND offer_status = 'PENDING'`,
      [chat.id]
    );
    await client.query("COMMIT");

    return res.status(201).json({ message: "Deal accepted", order });
  } catch (error) {
    await client.query("ROLLBACK");
    return serverError(res, "Accept offer", error);
  } finally {
    client.release();
  }
};

const rejectOffer = async (req, res) => {
  try {
    const found = await findAnswerableOffer(pool, req, res);
    if (!found) return undefined;

    await pool.query(
      `UPDATE negotiation_messages SET offer_status = 'REJECTED' WHERE id = $1`,
      [found.offer.id]
    );
    return res.status(200).json({ message: "Offer rejected" });
  } catch (error) {
    return serverError(res, "Reject offer", error);
  }
};

/** The buyer takes the listed price before any other price was offered. */
const acceptListing = async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const chat = await loadChat(client, req.params.id, req.user.id);
    if (!chat) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Chat not found" });
    }
    if (chat.role !== "BUYER") {
      await client.query("ROLLBACK");
      return res.status(403).json({ message: "Only the buyer can accept the listed price" });
    }
    if (chat.status !== "OPEN") {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "This negotiation is closed" });
    }
    const { messages } = await loadMessages(client, chat);
    if (messages.some(hasPrice)) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message: "Prices were offered in the chat - answer the latest offer instead",
      });
    }

    const order = await createOrder(client, chat, chat.listed_price);
    await client.query("COMMIT");
    return res.status(201).json({ message: "Deal accepted", order });
  } catch (error) {
    await client.query("ROLLBACK");
    return serverError(res, "Accept listing", error);
  } finally {
    client.release();
  }
};

/** Either side ends the negotiation without a deal. */
const closeChat = async (req, res) => {
  try {
    const chat = await loadChat(pool, req.params.id, req.user.id);
    if (!chat) return res.status(404).json({ message: "Chat not found" });
    if (chat.status !== "OPEN") {
      return res.status(409).json({ message: "This negotiation is already closed" });
    }
    await pool.query(`UPDATE negotiations SET status = 'REJECTED' WHERE id = $1`, [
      chat.id,
    ]);
    return res.status(200).json({ message: "Negotiation closed" });
  } catch (error) {
    return serverError(res, "Close chat", error);
  }
};

module.exports = {
  getChats,
  getChat,
  sendChatMessage,
  acceptOffer,
  rejectOffer,
  acceptListing,
  closeChat,
  // Shared with the older buyer/owner routes and notifications.
  listChats,
  postMessage,
  openOfferChat,
  settleRequest,
};

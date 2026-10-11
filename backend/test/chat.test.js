// Chats shared by buyers and estate owners: offers answered on their own
// card by the other side, unread counts, notifications and the day's
// average price. Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5096";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5096";

const call = async (method, path, { token, body } = {}) => {
  const response = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
};

const signup = async (name, phone, role) =>
  (await call("POST", "/api/auth/signup", {
    body: { name, phone, password: "secret123", role, location: "Colombo" },
  })).data;

const day = (offset) => {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

const list = async (quantity, availableDate, price) =>
  (await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: { productType: "RAW_COCONUT", quantity, availableDate, offerPricePerUnit: price },
  })).data.listing.id;

const open = async (listingId) =>
  (await call("POST", "/api/buyer/negotiations", {
    token: buyer.token,
    body: { listingId },
  })).data.id;

const say = (who, chatId, body) =>
  call("POST", `/api/chats/${chatId}/messages`, { token: who.token, body });

const chatOf = async (who, chatId) =>
  (await call("GET", `/api/chats/${chatId}`, { token: who.token })).data;

const summaryOf = async (who, chatId) =>
  (await call("GET", "/api/chats", { token: who.token })).data.find((c) => c.id === chatId);

before(async () => {
  const http = require("http");
  const originalListen = http.Server.prototype.listen;
  http.Server.prototype.listen = function (...args) {
    server = this;
    return originalListen.apply(this, args);
  };
  require("../server");
  http.Server.prototype.listen = originalListen;
  await new Promise((resolve) => setTimeout(resolve, 200));
});

after(() => server.close());

let owner;
let buyer;
let stranger;
let chatId;

test("both sides see the chat; strangers don't", async () => {
  owner = await signup("Nimal Owner", "0710000011", "ESTATE_OWNER");
  buyer = await signup("Lanka Mills", "0770000011", "BUYER");
  stranger = await signup("Other Buyer", "0770000012", "BUYER");
  await call("PATCH", "/api/owner/estate", {
    token: owner.token,
    body: { estateName: "Kelani Palms" },
  });

  chatId = await open(await list(2000, day(1), 135));

  const mine = await summaryOf(buyer, chatId);
  assert.equal(mine.my_role, "BUYER");
  assert.equal(mine.counterpart_name, "Kelani Palms");
  const theirs = await summaryOf(owner, chatId);
  assert.equal(theirs.my_role, "ESTATE_OWNER");
  assert.equal(theirs.counterpart_name, "Lanka Mills");

  const nope = await call("GET", `/api/chats/${chatId}`, { token: stranger.token });
  assert.equal(nope.status, 404);

  const chat = await chatOf(buyer, chatId);
  assert.equal(chat.can_accept_listing, true, "listed price is the opening offer");
  assert.equal(Number(chat.listing.offer_price_per_unit), 135);
});

test("an offer is answered only by the other side", async () => {
  await say(buyer, chatId, { message: "Can you do 128?", offerPricePerUnit: 128 });

  const ownerView = await summaryOf(owner, chatId);
  assert.equal(ownerView.unread_count, 1);
  assert.equal(ownerView.offer_waiting, true);
  assert.equal(Number(ownerView.waiting_offer.offer_price_per_unit), 128);

  const notes = (await call("GET", "/api/notifications", { token: owner.token })).data;
  assert.ok(notes.some((n) => n.type === "OFFER" && n.negotiation_id === chatId));

  const buyerChat = await chatOf(buyer, chatId);
  assert.equal(buyerChat.can_accept_listing, false);
  const offer = buyerChat.messages.find((m) => m.offer_price_per_unit);
  assert.equal(offer.offer_status, "PENDING");
  assert.equal(offer.is_mine, true);

  const own = await call("POST", `/api/chats/${chatId}/offers/${offer.id}/accept`, {
    token: buyer.token,
  });
  assert.equal(own.status, 403, "can't accept your own offer");

  // Opening the chat marks it read.
  await chatOf(owner, chatId);
  assert.equal((await summaryOf(owner, chatId)).unread_count, 0);

  const rejected = await call("POST", `/api/chats/${chatId}/offers/${offer.id}/reject`, {
    token: owner.token,
  });
  assert.equal(rejected.status, 200);
  const after = await chatOf(owner, chatId);
  assert.equal(after.status, "OPEN", "rejecting an offer keeps the chat open");
  assert.equal(after.messages.find((m) => m.id === offer.id).offer_status, "REJECTED");
  const cleared = (await call("GET", "/api/notifications", { token: owner.token })).data;
  assert.ok(!cleared.some((n) => n.type === "OFFER"), "answered offers drop out");
});

test("a new offer replaces the pending one; accepting creates the order", async () => {
  await say(owner, chatId, { offerPricePerUnit: 132 });
  const buyerNotes = (await call("GET", "/api/notifications", { token: buyer.token })).data;
  assert.ok(buyerNotes.some((n) => n.type === "OFFER" && n.title.includes("Kelani Palms")));

  await say(buyer, chatId, { message: "Meet me at 130", offerPricePerUnit: 130 });

  const chat = await chatOf(owner, chatId);
  const ownerOffer = chat.messages.find((m) => Number(m.offer_price_per_unit) === 132);
  const buyerOffer = chat.messages.find((m) => Number(m.offer_price_per_unit) === 130);
  assert.equal(ownerOffer.offer_status, "SUPERSEDED");
  assert.equal(buyerOffer.offer_status, "PENDING");

  const stale = await call("POST", `/api/chats/${chatId}/offers/${ownerOffer.id}/accept`, {
    token: buyer.token,
  });
  assert.equal(stale.status, 409, "a replaced offer can't be accepted");

  const accepted = await call(
    "POST",
    `/api/chats/${chatId}/offers/${buyerOffer.id}/accept`,
    { token: owner.token }
  );
  assert.equal(accepted.status, 201);
  assert.equal(Number(accepted.data.order.final_price_per_unit), 130);
  assert.equal(Number(accepted.data.order.total_value), 130 * 2000);

  const done = await chatOf(buyer, chatId);
  assert.equal(done.status, "ACCEPTED");
  assert.equal(done.order_status, "ACCEPTED");
  assert.equal(
    done.messages.find((m) => m.id === buyerOffer.id).offer_status,
    "ACCEPTED"
  );

  const closed = await say(buyer, chatId, { message: "Thanks!" });
  assert.equal(closed.status, 409);
});

test("upcoming deliveries show as notifications on both sides", async () => {
  const ownerNotes = (await call("GET", "/api/notifications", { token: owner.token })).data;
  const delivery = ownerNotes.find((n) => n.type === "DELIVERY");
  assert.ok(delivery, JSON.stringify(ownerNotes));
  assert.match(delivery.title, /due tomorrow/);
  assert.equal(delivery.urgent, true);
  assert.equal(ownerNotes[0].type, "DELIVERY", "urgent deliveries come first");

  const buyerNotes = (await call("GET", "/api/notifications", { token: buyer.token })).data;
  assert.ok(buyerNotes.some((n) => n.type === "DELIVERY" && /Kelani Palms/.test(n.body)));

  // Far-off orders aren't "upcoming" yet.
  const later = await open(await list(500, day(30), 140));
  await call("POST", `/api/chats/${later}/accept-listing`, { token: buyer.token });
  const notes = (await call("GET", "/api/notifications", { token: owner.token })).data;
  assert.equal(notes.filter((n) => n.type === "DELIVERY").length, 1);
});

test("the buyer can take the listed price only before any offer", async () => {
  const fresh = await open(await list(1000, day(3), 126));
  const notOwner = await call("POST", `/api/chats/${fresh}/accept-listing`, {
    token: owner.token,
  });
  assert.equal(notOwner.status, 403);

  const other = await open(await list(800, day(3), 125));
  await say(owner, other, { offerPricePerUnit: 124 });
  const blocked = await call("POST", `/api/chats/${other}/accept-listing`, {
    token: buyer.token,
  });
  assert.equal(blocked.status, 409);

  const ok = await call("POST", `/api/chats/${fresh}/accept-listing`, {
    token: buyer.token,
  });
  assert.equal(ok.status, 201);
  assert.equal(Number(ok.data.order.final_price_per_unit), 126);

  const closed = await call("POST", `/api/chats/${other}/close`, { token: owner.token });
  assert.equal(closed.status, 200);
  const view = await chatOf(buyer, other);
  assert.equal(view.status, "REJECTED");
  assert.equal(view.messages[0].offer_status, "CLOSED");
});

test("average price is for orders the customers need on that day", async () => {
  // Two orders needed today, at 120 and 124.
  for (const price of [120, 124]) {
    const id = await open(await list(1000, day(0), price));
    await call("POST", `/api/chats/${id}/accept-listing`, { token: buyer.token });
  }

  const stats = (await call("GET", "/api/owner/market-stats?type=RAW_COCONUT", {
    token: owner.token,
  })).data;
  assert.equal(stats.avg_day, day(0));
  assert.equal(stats.avg_day_is_today, true);
  assert.equal(stats.avg_day_order_count, 2);
  assert.equal(stats.avg_day_price, 122);
  assert.ok(stats.last_deal.quantity > 0);
});

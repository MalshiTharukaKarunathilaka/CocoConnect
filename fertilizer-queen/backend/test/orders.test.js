// Orders tab overview for both sides, completing deals with a price
// dispute, and admin review. Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5095";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5095";

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
let admin;
let orderId;
let openChat;

test("activity: pending offers, negotiations, deals on both sides", async () => {
  owner = await signup("Nimal Owner", "0710000021", "ESTATE_OWNER");
  buyer = await signup("Lanka Mills", "0770000021", "BUYER");
  await call("PATCH", "/api/owner/estate", {
    token: owner.token,
    body: { estateName: "Kelani Palms" },
  });

  const list = async (quantity, price) =>
    (await call("POST", "/api/owner/listings", {
      token: owner.token,
      body: {
        productType: "RAW_COCONUT",
        quantity,
        availableDate: "2026-11-20",
        offerPricePerUnit: price,
      },
    })).data.listing.id;
  const open = async (listingId) =>
    (await call("POST", "/api/buyer/negotiations", {
      token: buyer.token,
      body: { listingId },
    })).data.id;

  // A deal at the listed price.
  const dealChat = await open(await list(2000, 130));
  const accepted = await call("POST", `/api/chats/${dealChat}/accept-listing`, {
    token: buyer.token,
  });
  orderId = accepted.data.order.id;

  // An open chat where the buyer's offer waits for the owner.
  openChat = await open(await list(1000, 135));
  await call("POST", `/api/chats/${openChat}/messages`, {
    token: buyer.token,
    body: { offerPricePerUnit: 128 },
  });

  // The owner's offer on a buyer request.
  const request = (await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "RAW_COCONUT",
      requestedQuantity: 500,
      requiredDate: "2026-11-25",
      biddingPricePerUnit: 125,
    },
  })).data.buyerRequest;
  await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: { buyerRequestId: request.id, quantity: 500, sellerPricePerUnit: 127 },
  });

  const mine = (await call("GET", "/api/activity", { token: buyer.token })).data;
  assert.deepEqual(
    mine.pending.map((p) => [p.kind, Number(p.price)]),
    [["CHAT_OFFER", 128]],
    "the buyer's own waiting offer"
  );
  // The open listing chat, plus the chat the estate's offer on the
  // request started.
  assert.equal(mine.negotiations.length, 2);
  assert.ok(mine.negotiations.some((c) => c.id === openChat));
  assert.ok(mine.negotiations.some((c) => c.sell_request_id));
  assert.equal(mine.deals.length, 1);
  assert.equal(mine.deals[0].counterpart_name, "Kelani Palms");
  assert.equal(mine.deals[0].my_role, "BUYER");
  assert.equal(mine.deals[0].due_date, "2026-11-20");
  assert.equal(mine.deals[0].negotiation_id, dealChat);
  assert.equal(mine.transactions.length, 0);

  const theirs = (await call("GET", "/api/activity", { token: owner.token })).data;
  assert.deepEqual(
    theirs.pending.map((p) => [p.kind, Number(p.price)]),
    [["SELL_OFFER", 127]],
    "the buyer's chat offer waits for the owner, so it isn't the owner's pending"
  );
  assert.equal(theirs.pending[0].counterpart_name, "Lanka Mills");
  assert.equal(theirs.deals[0].counterpart_name, "Lanka Mills");
  assert.equal(theirs.deals[0].my_role, "ESTATE_OWNER");
});

test("completing at a different price needs a flagged dispute", async () => {
  const unflagged = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token,
    body: { deliveredQuantity: 2000, finalPricePerUnit: 135 },
  });
  assert.equal(unflagged.status, 409);
  assert.equal(unflagged.data.code, "PRICE_REVIEW_REQUIRED");

  const flagged = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token,
    body: {
      deliveredQuantity: 2000,
      finalPricePerUnit: 135,
      requestPriceReview: true,
      disputeNote: "Graded A by the buyer",
    },
  });
  assert.equal(flagged.status, 200);
  const order = flagged.data.order;
  assert.equal(order.status, "COMPLETED");
  assert.equal(Number(order.delivered_price_per_unit), 130, "agreed price protected");
  assert.equal(Number(order.dispute_price_per_unit), 135);
  assert.equal(order.dispute_status, "PENDING");

  const buyerView = (await call("GET", "/api/activity", { token: buyer.token })).data;
  assert.equal(buyerView.deals.length, 0);
  assert.equal(buyerView.transactions[0].id, orderId);
  assert.equal(buyerView.transactions[0].dispute_status, "PENDING");
});

test("only admins review disputes; approving applies the new price", async () => {
  const notAdmin = await call("GET", "/api/admin/disputes", { token: owner.token });
  assert.equal(notAdmin.status, 403);

  admin = (await call("POST", "/api/auth/login", {
    body: { phone: "0700000000", password: "admin123" },
  })).data;
  assert.equal(admin.user.role, "ADMIN");

  const disputes = (await call("GET", "/api/admin/disputes", { token: admin.token })).data;
  const dispute = disputes.find((d) => d.id === orderId);
  assert.equal(dispute.estate_name, "Kelani Palms");
  assert.equal(dispute.buyer_name, "Lanka Mills");
  assert.equal(dispute.dispute_note, "Graded A by the buyer");

  const approved = await call("POST", `/api/admin/disputes/${orderId}/approve`, {
    token: admin.token,
  });
  assert.equal(approved.status, 200);
  assert.equal(Number(approved.data.order.delivered_price_per_unit), 135);
  assert.equal(approved.data.order.dispute_status, "APPROVED");

  const again = await call("POST", `/api/admin/disputes/${orderId}/reject`, {
    token: admin.token,
  });
  assert.equal(again.status, 409);
});

test("completing at the agreed price needs no review", async () => {
  // Owner accepts the buyer's 128 offer, then completes at 128.
  const chat = (await call("GET", `/api/chats/${openChat}`, { token: owner.token })).data;
  const offer = chat.messages.find((m) => m.offer_status === "PENDING");
  const accepted = await call(
    "POST",
    `/api/chats/${openChat}/offers/${offer.id}/accept`,
    { token: owner.token }
  );
  const done = await call(
    "POST",
    `/api/owner/orders/${accepted.data.order.id}/complete`,
    { token: owner.token, body: { deliveredQuantity: 990, finalPricePerUnit: 128 } }
  );
  assert.equal(done.status, 200);
  assert.equal(done.data.order.dispute_status, null);
});

test("an offer on a buyer request starts a chat; accepting it there closes the request", async () => {
  const rival = await call("POST", "/api/auth/signup", {
    body: { name: "Rival Owner", phone: "0710000022", password: "secret123", role: "ESTATE_OWNER", location: "Kandy" },
  });
  const request = (await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "RAW_COCONUT",
      requestedQuantity: 700,
      requiredDate: "2026-12-01",
      biddingPricePerUnit: 120,
    },
  })).data.buyerRequest;

  const sent = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: { buyerRequestId: request.id, quantity: 700, sellerPricePerUnit: 126 },
  });
  assert.equal(sent.status, 201);
  const chatId = sent.data.negotiationId;
  assert.ok(chatId, "a chat was opened");
  const rivalSent = await call("POST", "/api/owner/sell-requests", {
    token: rival.data.token,
    body: { buyerRequestId: request.id, quantity: 700, sellerPricePerUnit: 125 },
  });

  // The buyer sees the chat, starting with the estate's offer to answer.
  const chat = (await call("GET", `/api/chats/${chatId}`, { token: buyer.token })).data;
  assert.equal(chat.counterpart_name, "Kelani Palms");
  assert.equal(chat.can_accept_listing, false);
  const offer = chat.messages[0];
  assert.equal(Number(offer.offer_price_per_unit), 126);
  assert.equal(offer.offer_status, "PENDING");
  assert.match(offer.message, /700 nuts needed by 2026-12-01/);

  // The private chat listing never reaches the marketplace or My Listings.
  const market = (await call("GET", "/api/buyer/listings?type=RAW_COCONUT")).data;
  assert.ok(market.every((l) => Number(l.quantity) !== 700));
  const mine = (await call("GET", "/api/owner/listings", { token: owner.token })).data;
  assert.ok(mine.every((l) => l.status !== "OFFER"));

  // Listed once under the owner's pending orders, with its chat.
  const pending = (await call("GET", "/api/activity", { token: owner.token })).data.pending;
  const listed = pending.filter((p) => p.request_id === request.id);
  assert.equal(listed.length, 1);
  assert.equal(listed[0].negotiation_id, chatId);

  const accepted = await call("POST", `/api/chats/${chatId}/offers/${offer.id}/accept`, {
    token: buyer.token,
  });
  assert.equal(accepted.status, 201);
  assert.equal(accepted.data.order.buyer_request_id, request.id);

  const requests = (await call("GET", "/api/buyer/requests", { token: buyer.token })).data;
  assert.equal(requests.find((r) => r.id === request.id).status, "ACCEPTED");
  const rivalChat = await call("GET", `/api/chats/${rivalSent.data.negotiationId}`, {
    token: buyer.token,
  });
  assert.equal(rivalChat.data.status, "REJECTED", "the other estate's chat closes");

  const deal = (await call("GET", "/api/activity", { token: buyer.token })).data.deals.find(
    (d) => d.id === accepted.data.order.id
  );
  assert.equal(deal.due_date, "2026-12-01", "due on the buyer's required date");
  assert.equal(deal.counterpart_name, "Kelani Palms");
});

test("interested buyers can be matched to the estate's harvest", async () => {
  for (const [quantity, date] of [[400, "2026-12-14"], [400, "2026-12-03"], [5000, "2026-12-12"]]) {
    await call("POST", "/api/buyer/requests", {
      token: buyer.token,
      body: {
        productType: "HUSKED_COCONUT",
        requestedQuantity: quantity,
        requiredDate: date,
        biddingPricePerUnit: 140,
      },
    });
  }
  // Harvest of 1,000 nuts available 15 Dec: buyers needing 8-15 Dec, up to 1,000.
  const matched = (await call(
    "GET",
    "/api/owner/buyer-requests?type=HUSKED_COCONUT&availableDate=2026-12-15&maxQuantity=1000",
    { token: owner.token }
  )).data;
  assert.deepEqual(
    matched.map((r) => String(r.required_date).slice(0, 10)),
    ["2026-12-14"]
  );
});

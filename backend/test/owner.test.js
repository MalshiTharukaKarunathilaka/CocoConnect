// End-to-end checks of the estate owner routes and how they connect with
// the buyer side, against the in-memory database. Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5098";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5098";

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

const signup = async (name, phone, role, location) =>
  (await call("POST", "/api/auth/signup", {
    body: { name, phone, password: "secret123", role, location },
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
let otherOwner;
let buyer;
let listingId;

test("owner routes need an estate owner login", async () => {
  owner = await signup("Nimal Owner", "0711111111", "Estate Owner", "Kurunegala");
  otherOwner = await signup("Kamal Owner", "0712222222", "ESTATE_OWNER", "Puttalam");
  buyer = await signup("Senuji Test", "0771234567", "BUYER", "Colombo");

  assert.equal((await call("GET", "/api/owner/estate")).status, 401);
  assert.equal(
    (await call("GET", "/api/owner/estate", { token: buyer.token })).status,
    403
  );
});

test("estate is created on first use and can be renamed", async () => {
  const estate = await call("GET", "/api/owner/estate", { token: owner.token });
  assert.equal(estate.status, 200);
  assert.equal(estate.data.estate_name, "Nimal Owner Estate");
  assert.equal(estate.data.location, "Kurunegala");

  const again = await call("GET", "/api/owner/estate", { token: owner.token });
  assert.equal(again.data.id, estate.data.id, "same estate, not a second one");

  const renamed = await call("PATCH", "/api/owner/estate", {
    token: owner.token,
    body: { estateName: "Hill Top Estate", location: "Kandy" },
  });
  assert.equal(renamed.data.estate_name, "Hill Top Estate");
});

test("listings belong to the logged-in owner's estate", async () => {
  const created = await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: {
      productType: "raw_coconut",
      quantity: 900,
      availableDate: "2026-12-05",
      offerPricePerUnit: 132,
    },
  });
  assert.equal(created.status, 201);
  listingId = created.data.listing.id;

  const mine = await call("GET", "/api/owner/listings", { token: owner.token });
  assert.equal(mine.data.length, 1);
  const theirs = await call("GET", "/api/owner/listings", { token: otherOwner.token });
  assert.equal(theirs.data.length, 0);

  // Buyers see it with the renamed estate.
  const market = await call("GET", "/api/buyer/listings?type=RAW_COCONUT");
  const seen = market.data.find((l) => l.id === listingId);
  assert.equal(seen.estate_name, "Hill Top Estate");
});

test("two-way negotiation: buyer and owner see each other's messages", async () => {
  const started = await call("POST", "/api/buyer/negotiations", {
    token: buyer.token,
    body: { listingId },
  });
  const id = started.data.id;

  await call("POST", `/api/buyer/negotiations/${id}/messages`, {
    token: buyer.token,
    body: { message: "Can you do Rs. 120?", offerPricePerUnit: 120 },
  });

  const chats = await call("GET", "/api/owner/negotiations", { token: owner.token });
  assert.equal(chats.data.length, 1);
  assert.equal(chats.data[0].buyer_name, "Senuji Test");
  assert.equal(Number(chats.data[0].message_count), 1);

  const other = await call("GET", `/api/owner/negotiations/${id}`, {
    token: otherOwner.token,
  });
  assert.equal(other.status, 404, "another owner can't read it");

  const ownerView = await call("GET", `/api/owner/negotiations/${id}`, {
    token: owner.token,
  });
  assert.equal(ownerView.data.buyer.name, "Senuji Test");
  assert.equal(ownerView.data.messages[0].is_mine, false);

  const reply = await call("POST", `/api/owner/negotiations/${id}/messages`, {
    token: owner.token,
    body: { message: "Best I can do", offerPricePerUnit: 126 },
  });
  assert.equal(reply.status, 201);

  const buyerView = await call("GET", `/api/buyer/negotiations/${id}`, {
    token: buyer.token,
  });
  assert.deepEqual(
    buyerView.data.messages.map((m) => [m.is_mine, Number(m.offer_price_per_unit)]),
    [
      [true, 120],
      [false, 126],
    ]
  );

  // Accepting takes the owner's counter-offer.
  const accepted = await call("POST", `/api/buyer/negotiations/${id}/accept`, {
    token: buyer.token,
  });
  assert.equal(Number(accepted.data.order.final_price_per_unit), 126);

  const closed = await call("POST", `/api/owner/negotiations/${id}/messages`, {
    token: owner.token,
    body: { message: "hello?" },
  });
  assert.equal(closed.status, 409);

  const orders = await call("GET", "/api/owner/orders", { token: owner.token });
  assert.equal(orders.data.length, 1);
  assert.equal(orders.data[0].buyer_name, "Senuji Test");
  assert.equal(orders.data[0].negotiation_id, id);
});

test("owner can decline a negotiation", async () => {
  const started = await call("POST", "/api/buyer/negotiations", {
    token: buyer.token,
    body: { listingId },
  });
  const declined = await call(
    "POST",
    `/api/owner/negotiations/${started.data.id}/decline`,
    { token: owner.token }
  );
  assert.equal(declined.status, 200);

  const buyerView = await call("GET", `/api/buyer/negotiations/${started.data.id}`, {
    token: buyer.token,
  });
  assert.equal(buyerView.data.status, "REJECTED");
});

test("buyer request -> owner offers -> buyer accepts one", async () => {
  const request = (await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "HUSKED_COCONUT",
      requestedQuantity: 500,
      requiredDate: "2026-12-20",
      biddingPricePerUnit: 140,
    },
  })).data.buyerRequest;

  const rawOnly = await call("GET", "/api/owner/buyer-requests?type=RAW_COCONUT", {
    token: owner.token,
  });
  assert.ok(
    rawOnly.data.every((r) => r.product_type === "RAW_COCONUT"),
    "type filter keeps husked requests off the raw page"
  );

  const husked = await call("GET", "/api/owner/buyer-requests?type=HUSKED_COCONUT", {
    token: owner.token,
  });
  const seen = husked.data.find((r) => r.id === request.id);
  assert.equal(seen.my_offer_id, null);

  const offer = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: { buyerRequestId: request.id, quantity: 500, sellerPricePerUnit: 145 },
  });
  assert.equal(offer.status, 201);
  assert.equal(offer.data.sellRequest.product_type, "HUSKED_COCONUT");

  const duplicate = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: { buyerRequestId: request.id, quantity: 500, sellerPricePerUnit: 144 },
  });
  assert.equal(duplicate.status, 409);

  const cheaper = await call("POST", "/api/owner/sell-requests", {
    token: otherOwner.token,
    body: { buyerRequestId: request.id, quantity: 500, sellerPricePerUnit: 142 },
  });
  assert.equal(cheaper.status, 201);

  const marked = await call("GET", "/api/owner/buyer-requests?type=HUSKED_COCONUT", {
    token: owner.token,
  });
  assert.equal(
    Number(marked.data.find((r) => r.id === request.id).my_offer_price),
    145
  );

  const mine = await call("GET", "/api/buyer/requests", { token: buyer.token });
  assert.equal(Number(mine.data.find((r) => r.id === request.id).response_count), 2);

  const responses = await call("GET", `/api/buyer/requests/${request.id}/responses`, {
    token: buyer.token,
  });
  assert.deepEqual(
    responses.data.map((r) => Number(r.seller_price_per_unit)),
    [142, 145],
    "cheapest first"
  );
  assert.equal(responses.data[1].estate_name, "Hill Top Estate");

  const blocked = await call("DELETE", `/api/buyer/requests/${request.id}`, {
    token: buyer.token,
  });
  assert.equal(blocked.status, 409, "can't delete once owners responded");

  const accepted = await call(
    "POST",
    `/api/buyer/responses/${responses.data[1].id}/accept`,
    { token: buyer.token }
  );
  assert.equal(accepted.status, 201);
  assert.equal(Number(accepted.data.order.total_value), 145 * 500);

  const again = await call(
    "POST",
    `/api/buyer/responses/${responses.data[0].id}/accept`,
    { token: buyer.token }
  );
  assert.equal(again.status, 409, "request closed after accepting one offer");

  const sent = await call("GET", "/api/owner/sell-requests", { token: owner.token });
  assert.equal(sent.data[0].status, "accepted");
  const otherSent = await call("GET", "/api/owner/sell-requests", {
    token: otherOwner.token,
  });
  assert.equal(otherSent.data[0].status, "declined");

  const open = await call("GET", "/api/owner/buyer-requests?type=HUSKED_COCONUT", {
    token: owner.token,
  });
  assert.ok(!open.data.some((r) => r.id === request.id), "closed request hidden");

  const ownerOrders = await call("GET", "/api/owner/orders", { token: owner.token });
  const fromOffer = ownerOrders.data.find((o) => o.buyer_request_id === request.id);
  assert.equal(fromOffer.product_type, "HUSKED_COCONUT");
  assert.equal(fromOffer.buyer_name, "Senuji Test");

  const buyerOrders = await call("GET", "/api/buyer/orders", { token: buyer.token });
  const buyerSide = buyerOrders.data.find((o) => o.buyer_request_id === request.id);
  assert.equal(buyerSide.estate_name, "Hill Top Estate");
  assert.equal(buyerSide.quantity, 500);
});

test("profile: estate details and summary counts", async () => {
  const bad = await call("PATCH", "/api/owner/estate", {
    token: owner.token,
    body: { estateName: "Hill Top Estate", yearEstablished: "20x5" },
  });
  assert.equal(bad.status, 400);

  const saved = await call("PATCH", "/api/owner/estate", {
    token: owner.token,
    body: {
      estateName: "Hill Top Estate",
      location: "Kandy",
      totalLandArea: "25 acres",
      primaryCrop: "Coconut",
      yearEstablished: "2015",
    },
  });
  assert.equal(saved.status, 200);
  assert.equal(saved.data.total_land_area, "25 acres");
  assert.equal(saved.data.year_established, 2015);

  // Earlier tests left: 1 active listing, 1 open chat (declined one closed),
  // 1 accepted order from the chat and 1 from an accepted offer.
  const summary = await call("GET", "/api/owner/summary", { token: owner.token });
  assert.equal(summary.status, 200);
  assert.equal(summary.data.estate.primary_crop, "Coconut");
  assert.equal(summary.data.active_listings, 1);
  assert.equal(summary.data.open_chats, 0);
  assert.equal(summary.data.orders_active, 2);
  assert.equal(summary.data.orders_completed, 0);

  const buyerSummary = await call("GET", "/api/buyer/summary", { token: buyer.token });
  assert.equal(buyerSummary.status, 200);
  assert.equal(buyerSummary.data.orders_active, 2);
  assert.equal(buyerSummary.data.open_requests, 0);
});

test("deals: owner accepts buyer's offer, completes with actual figures", async () => {
  const listing = (await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: {
      productType: "RAW_COCONUT",
      quantity: 2000,
      availableDate: "2026-12-10",
      offerPricePerUnit: 135,
    },
  })).data.listing;

  const chat = (await call("POST", "/api/buyer/negotiations", {
    token: buyer.token,
    body: { listingId: listing.id },
  })).data;
  await call("POST", `/api/buyer/negotiations/${chat.id}/messages`, {
    token: buyer.token,
    body: { offerPricePerUnit: 128 },
  });

  const notMine = await call("POST", `/api/owner/negotiations/${chat.id}/accept`, {
    token: otherOwner.token,
  });
  assert.equal(notMine.status, 404);

  const accepted = await call("POST", `/api/owner/negotiations/${chat.id}/accept`, {
    token: owner.token,
  });
  assert.equal(accepted.status, 201);
  assert.equal(Number(accepted.data.order.final_price_per_unit), 128, "buyer's offer");
  assert.equal(Number(accepted.data.order.total_value), 128 * 2000);
  const orderId = accepted.data.order.id;

  const buyerView = await call("GET", `/api/buyer/negotiations/${chat.id}`, {
    token: buyer.token,
  });
  assert.equal(buyerView.data.status, "ACCEPTED");

  const orders = await call("GET", "/api/owner/orders", { token: owner.token });
  const deal = orders.data.find((o) => o.id === orderId);
  assert.match(String(deal.due_date), /^2026-12-10/);
  assert.equal(deal.buyer_name, "Senuji Test");
  assert.equal(deal.quantity, 2000);

  const bad = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token,
    body: { deliveredQuantity: 0, finalPricePerUnit: 128 },
  });
  assert.equal(bad.status, 400);

  const other = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: otherOwner.token,
    body: { deliveredQuantity: 1950, finalPricePerUnit: 128 },
  });
  assert.equal(other.status, 404, "another owner can't complete it");

  const done = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token,
    body: { deliveredQuantity: 1950, finalPricePerUnit: 127 },
  });
  assert.equal(done.status, 200);
  assert.equal(done.data.order.status, "COMPLETED");
  assert.equal(done.data.order.delivered_quantity, 1950);
  assert.equal(Number(done.data.order.final_price_per_unit), 128, "agreed price kept");
  assert.ok(done.data.order.completed_at);

  const twice = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token,
    body: { deliveredQuantity: 1950, finalPricePerUnit: 127 },
  });
  assert.equal(twice.status, 409);

  const buyerOrders = await call("GET", "/api/buyer/orders", { token: buyer.token });
  assert.equal(buyerOrders.data.find((o) => o.id === orderId).status, "COMPLETED");

  const stats = await call("GET", "/api/owner/market-stats?type=RAW_COCONUT", {
    token: owner.token,
  });
  assert.equal(stats.status, 200);
  assert.equal(stats.data.last_deal.quantity, 1950, "uses delivered figures");
  assert.equal(stats.data.last_deal.price, 127);
  assert.ok(stats.data.week_avg_price > 0);

  const offers = await call("GET", "/api/owner/sell-requests", { token: owner.token });
  const acceptedOffer = offers.data.find((o) => o.status === "accepted");
  assert.ok(acceptedOffer.order_id, "accepted offer links to its order");
  assert.equal(acceptedOffer.order_status, "ACCEPTED");
});

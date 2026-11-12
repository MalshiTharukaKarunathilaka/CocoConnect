// One journey through the whole app with every account type, against the
// in-memory database: estate owner, buyer, service provider and admin.
// It checks the hand-offs between the sides (what one side does, the other
// sees), not each route on its own. Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5092";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5092";

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
const ok = async (method, path, options, status = 200) => {
  const r = await call(method, path, options);
  assert.equal(r.status, status, `${method} ${path} -> ${r.status} ${JSON.stringify(r.data)}`);
  return r.data;
};

const KURUNEGALA = { latitude: 7.4863, longitude: 80.3647 };
const signup = async (name, phone, role, extra = {}) =>
  ok("POST", "/api/auth/signup", {
    body: { name, phone, password: "secret123", role, location: "Kurunegala", ...KURUNEGALA, ...extra },
  }, 201);

before(async () => {
  const http = require("http");
  const originalListen = http.Server.prototype.listen;
  http.Server.prototype.listen = function (...args) {
    server = this;
    return originalListen.apply(this, args);
  };
  require("../server");
  http.Server.prototype.listen = originalListen;
  await new Promise((resolve) => setTimeout(resolve, 300));
});

after(() => server.close());

let owner;
let buyer;
let provider;
let admin;

test("everyone signs up and lands on their own side", async () => {
  owner = await signup("Nimal Owner", "0712000001", "ESTATE_OWNER");
  buyer = await signup("Lanka Mills", "0712000002", "BUYER");
  provider = await signup("Sunil Machinery", "0712000003", "SERVICE_PROVIDER", {
    service_provider: {
      identity_number: "821940129V", category: "Machinery", machinery_type: "Tractor",
      district: "Kurunegala", address: "Machinery Yard", radius_km: 15, terms_accepted: true,
    },
  });
  admin = await ok("POST", "/api/auth/login", { body: { phone: "0700000000", password: "admin123" } });

  assert.deepEqual([owner, buyer, provider, admin].map((u) => u.user.role), ["ESTATE_OWNER", "BUYER", "SERVICE_PROVIDER", "ADMIN"]);

  // Each side is closed to the others.
  assert.equal((await call("GET", "/api/owner/estate", { token: buyer.token })).status, 403);
  assert.equal((await call("GET", "/api/buyer/orders", { token: owner.token })).status, 403);
  assert.equal((await call("GET", "/api/machinery/machines", { token: buyer.token })).status, 403);
  assert.equal((await call("GET", "/api/machinery/provider/machines", { token: owner.token })).status, 403);
  assert.equal((await call("GET", "/api/owner/orders", { token: provider.token })).status, 403);
  assert.equal((await call("GET", "/api/admin/disputes", { token: owner.token })).status, 403);
});

let listingId;
let chatId;
let orderId;

test("OWNER -> BUYER: a harvest is listed, found, negotiated and bought", async () => {
  const made = await ok("POST", "/api/owner/listings", {
    token: owner.token,
    body: { productType: "raw_coconut", quantity: 1000, availableDate: "2026-12-05", offerPricePerUnit: 130 },
  }, 201);
  listingId = made.listing.id;

  // The buyer finds it, with the distance from their own location.
  const market = await ok("GET", "/api/buyer/listings?type=RAW_COCONUT&lat=7.4863&lng=80.3647", { token: buyer.token });
  const seen = market.find((l) => l.id === listingId);
  assert.ok(seen, "the buyer sees the owner's listing");
  assert.equal(seen.estate_name, "Nimal Owner Estate");
  assert.equal(seen.distance_km, 0);

  // Buyer offers, owner counters, buyer accepts: an order appears on both sides.
  const chat = await ok("POST", "/api/buyer/negotiations", { token: buyer.token, body: { listingId } }, 201);
  chatId = chat.id;
  await ok("POST", `/api/buyer/negotiations/${chatId}/messages`, {
    token: buyer.token, body: { message: "Rs. 120?", offerPricePerUnit: 120 },
  }, 201);
  await ok("POST", `/api/owner/negotiations/${chatId}/messages`, {
    token: owner.token, body: { message: "Rs. 126", offerPricePerUnit: 126 },
  }, 201);
  const accepted = await ok("POST", `/api/buyer/negotiations/${chatId}/accept`, { token: buyer.token }, 201);
  orderId = accepted.order.id;
  assert.equal(Number(accepted.order.final_price_per_unit), 126);

  const buyerOrders = await ok("GET", "/api/buyer/orders", { token: buyer.token });
  const ownerOrders = await ok("GET", "/api/owner/orders", { token: owner.token });
  assert.ok(buyerOrders.some((o) => o.id === orderId));
  assert.ok(ownerOrders.some((o) => o.id === orderId));

  // Both activity feeds show the deal, from their own point of view.
  const theirs = await ok("GET", "/api/activity", { token: owner.token });
  const mine = await ok("GET", "/api/activity", { token: buyer.token });
  assert.equal(theirs.deals.find((d) => d.id === orderId).my_role, "ESTATE_OWNER");
  assert.equal(mine.deals.find((d) => d.id === orderId).my_role, "BUYER");
  assert.equal(theirs.deals.find((d) => d.id === orderId).counterpart_name, "Lanka Mills");
  assert.equal(mine.deals.find((d) => d.id === orderId).counterpart_name, "Nimal Owner Estate");

  // Delivery at the agreed price completes without a review.
  const done = await ok("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token, body: { deliveredQuantity: 1000, finalPricePerUnit: 126 },
  });
  assert.equal(done.order.status, "COMPLETED");
  const after = await ok("GET", "/api/activity", { token: buyer.token });
  assert.ok(after.transactions.some((t) => t.id === orderId), "the buyer sees it as a finished transaction");
  assert.ok(!after.deals.some((d) => d.id === orderId));
});

test("BUYER -> OWNER -> BUYER: a request is answered, bought, and a price dispute is settled by the admin", async () => {
  const request = (await ok("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: { productType: "HUSKED_COCONUT", requestedQuantity: 500, requiredDate: "2026-12-20", biddingPricePerUnit: 140 },
  }, 201)).buyerRequest;

  // The owner sees the nearby request and answers it.
  const open = await ok("GET", "/api/owner/buyer-requests?type=HUSKED_COCONUT&lat=7.4863&lng=80.3647", { token: owner.token });
  const seen = open.find((r) => r.id === request.id);
  assert.ok(seen, "the owner sees the buyer's request");
  assert.equal(seen.distance_km, 0);
  await ok("POST", "/api/owner/sell-requests", {
    token: owner.token, body: { buyerRequestId: request.id, quantity: 500, sellerPricePerUnit: 145 },
  }, 201);

  // The buyer sees the offer and accepts it: the request closes, an order exists.
  const responses = await ok("GET", `/api/buyer/requests/${request.id}/responses`, { token: buyer.token });
  assert.equal(responses.length, 1);
  assert.equal(responses[0].estate_name, "Nimal Owner Estate");
  const bought = await ok("POST", `/api/buyer/responses/${responses[0].id}/accept`, { token: buyer.token }, 201);
  assert.equal(Number(bought.order.total_value), 145 * 500);
  const mine = await ok("GET", "/api/buyer/requests", { token: buyer.token });
  assert.equal(String(mine.find((r) => r.id === request.id).status).toLowerCase(), "accepted");

  // The owner delivers at a different price: the order completes at the agreed
  // price and waits for the admin, who approves it. The buyer sees the result.
  const flagged = await ok("POST", `/api/owner/orders/${bought.order.id}/complete`, {
    token: owner.token,
    body: { deliveredQuantity: 500, finalPricePerUnit: 150, requestPriceReview: true, disputeNote: "Graded A" },
  });
  assert.equal(flagged.order.dispute_status, "PENDING");
  assert.equal(Number(flagged.order.delivered_price_per_unit), 145);
  const disputes = await ok("GET", "/api/admin/disputes", { token: admin.token });
  assert.ok(disputes.some((d) => d.id === bought.order.id));
  const approved = await ok("POST", `/api/admin/disputes/${bought.order.id}/approve`, { token: admin.token });
  assert.equal(Number(approved.order.delivered_price_per_unit), 150);
  const buyerAfter = await ok("GET", "/api/buyer/orders", { token: buyer.token });
  assert.equal(Number(buyerAfter.find((o) => o.id === bought.order.id).delivered_price_per_unit), 150);
});

test("PROVIDER <-> OWNER: a machine is registered, requested, negotiated, confirmed and cancelled", async () => {
  const machine = await ok("POST", "/api/machinery/provider/machines", {
    token: provider.token, body: { name: "Sunil Tractor", category: "Tractor" },
  }, 201);
  const slasher = await ok("PUT", `/api/machinery/provider/machines/${machine.id}/rates`, {
    token: provider.token, body: { name: "Slasher", unit: "acre", rate: 5000 },
  });

  // The owner's map lists it with its rates, and the provider's location.
  const machines = await ok("GET", "/api/machinery/machines", { token: owner.token });
  const listed = machines.find((m) => m.id === machine.id);
  assert.ok(listed, "the owner sees the provider's machine");
  assert.equal(listed.services[0].name, "Slasher");
  assert.equal(Number(listed.services[0].rate), 5000);
  assert.equal(listed.provider_name, "Sunil Machinery");
  assert.equal(typeof listed.latitude, "number");

  // The owner requests; the provider sees it on their calendar.
  const request = await ok("POST", `/api/machinery/machines/${machine.id}/bookings`, {
    token: owner.token,
    body: {
      estate_name: "Nimal Owner Estate", address: "Kurunegala",
      starts_at: "2030-05-10T02:30:00.000Z", ends_at: "2030-05-10T06:30:00.000Z",
      items: [{ service_id: slasher.id, quantity: 4 }],
    },
  }, 201);
  assert.equal(request.status, "PENDING");
  assert.equal(Number(request.proposed_total), 20000);
  const calendar = await ok("GET", `/api/machinery/provider/machines/${machine.id}/calendar?month=2030-05`, { token: provider.token });
  assert.equal(calendar.bookings.length, 1);

  // They agree a price together; only then can the provider confirm.
  let booking = await ok("POST", `/api/machinery/bookings/${request.id}/messages`, {
    token: provider.token,
    body: { expected_version: request.version, message: "Rs. 18,000 for the job", offer_total: 18000 },
  }, 201);
  booking = await ok("POST", `/api/machinery/bookings/${request.id}/agree`, {
    token: owner.token, body: { expected_version: booking.version },
  });
  booking = await ok("POST", `/api/machinery/bookings/${request.id}/accept`, {
    token: provider.token, body: { expected_version: booking.version },
  });
  assert.equal(booking.status, "CONFIRMED");
  assert.equal(Number(booking.agreed_total), 18000);

  // The owner's My Bookings shows it confirmed at the agreed price, and the
  // calendar other owners see only shows the time as reserved.
  const mine = await ok("GET", "/api/machinery/bookings", { token: owner.token });
  const mineRow = mine.find((b) => b.id === request.id);
  assert.equal(mineRow.status, "CONFIRMED");
  assert.equal(Number(mineRow.agreed_total), 18000);
  const rival = await signup("Rival Owner", "0712000009", "ESTATE_OWNER");
  const publicCalendar = await ok("GET", `/api/machinery/machines/${machine.id}/calendar?month=2030-05`, { token: rival.token });
  assert.equal(publicCalendar.reserved.length, 1);
  assert.equal(JSON.stringify(publicCalendar).includes("agreed_total"), false);
  assert.equal((await call("GET", `/api/machinery/bookings/${request.id}`, { token: rival.token })).status, 404);

  // The owner cancels: both sides see it, and the time is free again.
  const cancelled = await ok("POST", `/api/machinery/bookings/${request.id}/cancel`, {
    token: owner.token, body: { expected_version: booking.version },
  });
  assert.equal(cancelled.status, "CANCELLED");
  const seenByProvider = await ok("GET", `/api/machinery/bookings/${request.id}`, { token: provider.token });
  assert.equal(seenByProvider.status, "CANCELLED");
  const freeAgain = await ok("GET", `/api/machinery/machines/${machine.id}/calendar?month=2030-05`, { token: rival.token });
  assert.equal(freeAgain.reserved.length, 0);
});

test("one login works on both sides of a deal: the same account sees the same chat", async () => {
  // A second listing and chat to check both sides read one shared conversation.
  const made = await ok("POST", "/api/owner/listings", {
    token: owner.token,
    body: { productType: "dehusked_coconut", quantity: 400, availableDate: "2026-12-10", offerPricePerUnit: 160 },
  }, 201);
  const chat = await ok("POST", "/api/buyer/negotiations", { token: buyer.token, body: { listingId: made.listing.id } }, 201);
  await ok("POST", `/api/chats/${chat.id}/messages`, { token: buyer.token, body: { message: "Is it fresh?" } }, 201);
  // The owner is alerted to the buyer's message before opening the chat...
  const alerts = await ok("GET", "/api/notifications", { token: owner.token });
  const alert = alerts.find((n) => n.type === "CHAT" && n.negotiation_id === chat.id);
  assert.ok(alert, "the owner is alerted");
  assert.equal(alert.body, "Is it fresh?");
  // ...and both sides then read the same conversation. Opening it clears the alert.
  const ownerSide = await ok("GET", `/api/chats/${chat.id}`, { token: owner.token });
  const buyerSide = await ok("GET", `/api/chats/${chat.id}`, { token: buyer.token });
  assert.equal(ownerSide.messages.length, buyerSide.messages.length);
  assert.equal(ownerSide.messages.at(-1).text ?? ownerSide.messages.at(-1).message, "Is it fresh?");
  const cleared = await ok("GET", "/api/notifications", { token: owner.token });
  assert.ok(!cleared.some((n) => n.negotiation_id === chat.id));
});

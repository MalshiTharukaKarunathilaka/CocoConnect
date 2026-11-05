// End-to-end checks of the auth and buyer routes against the in-memory
// database. Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5099";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5099";

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

const pool = () => require("../config/db");

before(async () => {
  // server.js starts listening as soon as it is required.
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

let buyer;
let otherBuyer;

test("signup validates input and rejects duplicate phones", async () => {
  const missing = await call("POST", "/api/auth/signup", { body: { name: "A" } });
  assert.equal(missing.status, 400);

  const badRole = await call("POST", "/api/auth/signup", {
    body: { name: "A", phone: "0711111111", password: "secret1", role: "Pilot" },
  });
  assert.equal(badRole.status, 400);

  const noLocation = await call("POST", "/api/auth/signup", {
    body: { name: "A", phone: "0711111111", password: "secret1", role: "BUYER" },
  });
  assert.equal(noLocation.status, 400);
  assert.equal(noLocation.data.message, "Location is required");

  const created = await call("POST", "/api/auth/signup", {
    body: { name: "Test Buyer", phone: "077 123 4567", password: "secret123", role: "Buyer", location: "Colombo" },
  });
  assert.equal(created.status, 201);
  assert.equal(created.data.user.role, "BUYER");
  assert.equal(created.data.user.phone, "0771234567");
  assert.ok(created.data.token);
  assert.equal(created.data.user.password_hash, undefined);
  buyer = created.data;

  const duplicate = await call("POST", "/api/auth/signup", {
    body: { name: "Again", phone: "0771234567", password: "secret123", role: "BUYER", location: "Colombo" },
  });
  assert.equal(duplicate.status, 409);

  const other = await call("POST", "/api/auth/signup", {
    body: { name: "Other Buyer", phone: "0779999999", password: "secret123", role: "BUYER", location: "Kandy" },
  });
  otherBuyer = other.data;
});

test("login, current user and profile update", async () => {
  const wrong = await call("POST", "/api/auth/login", {
    body: { phone: "0771234567", password: "nope" },
  });
  assert.equal(wrong.status, 401);

  const ok = await call("POST", "/api/auth/login", {
    body: { phone: "0771234567", password: "secret123" },
  });
  assert.equal(ok.status, 200);
  buyer.token = ok.data.token;

  const me = await call("GET", "/api/auth/me", { token: buyer.token });
  assert.equal(me.data.name, "Test Buyer");

  const noName = await call("PATCH", "/api/auth/me", {
    token: buyer.token,
    body: { name: " " },
  });
  assert.equal(noName.status, 400);

  const updated = await call("PATCH", "/api/auth/me", {
    token: buyer.token,
    body: { name: "Senuji Test", location: "Colombo" },
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.data.name, "Senuji Test");
  assert.equal(updated.data.location, "Colombo");
});

test("buyer routes need a buyer login", async () => {
  assert.equal((await call("GET", "/api/buyer/requests")).status, 401);

  const owner = await call("POST", "/api/auth/signup", {
    body: { name: "Owner", phone: "0712222222", password: "secret123", role: "Estate Owner", location: "Kurunegala" },
  });
  const asOwner = await call("GET", "/api/buyer/requests", { token: owner.data.token });
  assert.equal(asOwner.status, 403);
});

test("listings: filter by type, hide sold, sort", async () => {
  const raw = await call("GET", "/api/buyer/listings?type=RAW_COCONUT&sort=price_asc");
  assert.equal(raw.status, 200);
  assert.deepEqual(
    raw.data.map((l) => Number(l.offer_price_per_unit)),
    [125.5, 130, 140]
  );
  assert.ok(raw.data.every((l) => l.estate_name));

  const husked = await call("GET", "/api/buyer/listings?type=HUSKED_COCONUT");
  assert.equal(husked.data.length, 1);

  const one = await call("GET", `/api/buyer/listings/${raw.data[0].id}`);
  assert.equal(one.data.estate_name, "Silva Plantations");

  assert.equal((await call("GET", "/api/buyer/listings/9999")).status, 404);
});

test("buyer requests: create, read, update, delete", async () => {
  const token = buyer.token;

  const bad = await call("POST", "/api/buyer/requests", { token, body: {} });
  assert.equal(bad.status, 400);

  const created = await call("POST", "/api/buyer/requests", {
    token,
    body: {
      productType: "raw_coconut",
      requestedQuantity: 1200,
      requiredDate: "2026-12-15",
      biddingPricePerUnit: 115,
    },
  });
  assert.equal(created.status, 201);
  const request = created.data.buyerRequest;
  assert.equal(request.buyer_name, "Senuji Test");
  assert.equal(request.location, "Colombo");
  assert.equal(request.product_type, "RAW_COCONUT");

  const mine = await call("GET", "/api/buyer/requests", { token });
  assert.equal(mine.data.length, 1, "only my own requests are listed");

  const updated = await call("PUT", `/api/buyer/requests/${request.id}`, {
    token,
    body: { requestedQuantity: 1500, requiredDate: "2026-12-20", biddingPricePerUnit: 118 },
  });
  assert.equal(updated.status, 200);
  assert.equal(updated.data.buyerRequest.requested_quantity, 1500);

  const notMine = await call("PUT", `/api/buyer/requests/${request.id}`, {
    token: otherBuyer.token,
    body: { requestedQuantity: 1, requiredDate: "2026-12-20", biddingPricePerUnit: 1 },
  });
  assert.equal(notMine.status, 404, "another buyer can't edit it");

  const otherDelete = await call("DELETE", `/api/buyer/requests/${request.id}`, {
    token: otherBuyer.token,
  });
  assert.equal(otherDelete.status, 404, "another buyer can't delete it");

  const deleted = await call("DELETE", `/api/buyer/requests/${request.id}`, { token });
  assert.equal(deleted.status, 200);
  assert.equal((await call("GET", "/api/buyer/requests", { token })).data.length, 0);
});

test("a request an estate owner answered can't be deleted", async () => {
  const token = buyer.token;
  const created = await call("POST", "/api/buyer/requests", {
    token,
    body: {
      productType: "RAW_COCONUT",
      requestedQuantity: 500,
      requiredDate: "2026-12-10",
      biddingPricePerUnit: 120,
    },
  });
  const id = created.data.buyerRequest.id;

  await pool().query(
    `INSERT INTO sell_requests
      (estate_owner_id, buyer_request_id, product_type, quantity, seller_price_per_unit)
     VALUES (1, $1, 'RAW_COCONUT', 500, 125)`,
    [id]
  );

  const blocked = await call("DELETE", `/api/buyer/requests/${id}`, { token });
  assert.equal(blocked.status, 409);
});

test("negotiation: start, message, counter-offer, accept, complete", async () => {
  const token = buyer.token;
  const listing = (await call("GET", "/api/buyer/listings?type=RAW_COCONUT&sort=newest"))
    .data.find((l) => l.estate_name === "Green Valley Estate");

  const started = await call("POST", "/api/buyer/negotiations", {
    token,
    body: { listingId: listing.id },
  });
  assert.equal(started.status, 201);
  const id = started.data.id;

  const reopened = await call("POST", "/api/buyer/negotiations", {
    token,
    body: { listingId: listing.id },
  });
  assert.equal(reopened.status, 200);
  assert.equal(reopened.data.id, id, "reopens instead of duplicating");

  const empty = await call("POST", `/api/buyer/negotiations/${id}/messages`, {
    token,
    body: {},
  });
  assert.equal(empty.status, 400);

  await call("POST", `/api/buyer/negotiations/${id}/messages`, {
    token,
    body: { message: "Can you do Rs. 118?" },
  });
  await call("POST", `/api/buyer/negotiations/${id}/messages`, {
    token,
    body: { offerPricePerUnit: 118 },
  });

  // The estate owner replies with a counter-offer from their side.
  const ownerUser = await call("POST", "/api/auth/signup", {
    body: { name: "Nimal", phone: "0713333333", password: "secret123", role: "ESTATE_OWNER", location: "Gampaha" },
  });
  await pool().query(
    `INSERT INTO negotiation_messages
       (negotiation_id, sender_id, message, offer_price_per_unit, created_at)
     VALUES ($1, $2, 'Best I can do', 124, $3)`,
    [id, ownerUser.data.user.id, new Date()]
  );

  const detail = await call("GET", `/api/buyer/negotiations/${id}`, { token });
  assert.equal(detail.status, 200);
  assert.equal(detail.data.messages.length, 3);
  assert.deepEqual(
    detail.data.messages.map((m) => m.is_mine),
    [true, true, false]
  );
  assert.equal(detail.data.listing.estate_name, "Green Valley Estate");

  const peek = await call("GET", `/api/buyer/negotiations/${id}`, {
    token: otherBuyer.token,
  });
  assert.equal(peek.status, 404, "another buyer can't read it");

  const list = await call("GET", "/api/buyer/negotiations", { token });
  assert.equal(list.data.length, 1);
  assert.equal(Number(list.data[0].message_count), 3);

  const accepted = await call("POST", `/api/buyer/negotiations/${id}/accept`, { token });
  assert.equal(accepted.status, 201);
  assert.equal(Number(accepted.data.order.final_price_per_unit), 124, "owner's latest offer");
  assert.equal(Number(accepted.data.order.total_value), 124 * 1200);

  const closed = await call("POST", `/api/buyer/negotiations/${id}/messages`, {
    token,
    body: { message: "hello?" },
  });
  assert.equal(closed.status, 409);

  const again = await call("POST", `/api/buyer/negotiations/${id}/accept`, { token });
  assert.equal(again.status, 409, "can't accept twice");

  const orders = await call("GET", "/api/buyer/orders", { token });
  assert.equal(orders.data.length, 1);
  assert.equal(orders.data[0].status, "ACCEPTED");
  assert.equal(orders.data[0].negotiation_id, id);
  assert.equal(orders.data[0].estate_name, "Green Valley Estate");

  const orderId = orders.data[0].id;
  const completed = await call("PATCH", `/api/buyer/orders/${orderId}/complete`, { token });
  assert.equal(completed.status, 200);
  assert.equal(completed.data.order.status, "COMPLETED");

  const twice = await call("PATCH", `/api/buyer/orders/${orderId}/complete`, { token });
  assert.equal(twice.status, 404);

  const after = await call("GET", `/api/buyer/negotiations/${id}`, { token });
  assert.equal(after.data.status, "ACCEPTED");
  assert.equal(after.data.order_status, "COMPLETED");
});

test("negotiation: reject closes it, and accept uses listed price with no counter", async () => {
  const token = buyer.token;
  const listings = (await call("GET", "/api/buyer/listings?type=RAW_COCONUT")).data;
  const silva = listings.find((l) => l.estate_name === "Silva Plantations");
  const grove = listings.find((l) => l.estate_name === "Coconut Grove");

  const toReject = (await call("POST", "/api/buyer/negotiations", {
    token,
    body: { listingId: silva.id },
  })).data.id;
  const rejected = await call("POST", `/api/buyer/negotiations/${toReject}/reject`, { token });
  assert.equal(rejected.status, 200);
  assert.equal(rejected.data.negotiation.status, "REJECTED");

  const toAccept = (await call("POST", "/api/buyer/negotiations", {
    token,
    body: { listingId: grove.id },
  })).data.id;
  const accepted = await call("POST", `/api/buyer/negotiations/${toAccept}/accept`, { token });
  assert.equal(Number(accepted.data.order.final_price_per_unit), 140);
});

test("dates come back as plain YYYY-MM-DD", async () => {
  const raw = await call("GET", "/api/buyer/listings?type=HUSKED_COCONUT");
  assert.match(String(raw.data[0].available_date), /^2026-11-20/);
});

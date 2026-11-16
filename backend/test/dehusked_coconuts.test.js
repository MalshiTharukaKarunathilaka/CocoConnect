// End-to-end dehusked coconut checks for both estate-owner and buyer flows.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5108";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5108";

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
  (
    await call("POST", "/api/auth/signup", {
      body: { name, phone, password: "secret123", role, location },
    })
  ).data;

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

test("dehusked coconut flow from estate listing through buyer marketplace", async () => {
  const owner = await signup(
    "Dehusked Estate Owner",
    "0715550108",
    "ESTATE_OWNER",
    "Kurunegala"
  );
  const buyer = await signup(
    "Dehusked Buyer",
    "0775550108",
    "BUYER",
    "Colombo"
  );

  const invalidListing = await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: {
      productType: "DEHUSKED_COCONUT",
      quantity: 10.5,
      availableDate: "2026-12-05",
      offerPricePerUnit: 160,
    },
  });
  assert.equal(invalidListing.status, 400);
  assert.match(invalidListing.data.message, /number of nuts/i);

  const listed = await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: {
      productType: "DEHUSKED_COCONUT",
      quantity: 750,
      availableDate: "2026-12-05",
      offerPricePerUnit: 160,
    },
  });
  assert.equal(listed.status, 201);
  assert.equal(listed.data.listing.product_type, "DEHUSKED_COCONUT");
  assert.equal(listed.data.listing.quantity, 750);
  assert.equal(Number(listed.data.listing.offer_price_per_unit), 160);

  const marketplace = await call(
    "GET",
    "/api/buyer/listings?type=DEHUSKED_COCONUT"
  );
  assert.equal(marketplace.status, 200);
  const listedCoconuts = marketplace.data.find(
    (listing) => listing.id === listed.data.listing.id
  );
  assert.ok(listedCoconuts);
  assert.equal(listedCoconuts.quantity, 750);

  const invalidRequest = await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "DEHUSKED_COCONUT",
      requestedQuantity: 0,
      requiredDate: "2026-12-10",
      biddingPricePerUnit: 155,
    },
  });
  assert.equal(invalidRequest.status, 400);

  const requested = await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "DEHUSKED_COCONUT",
      requestedQuantity: 500,
      requiredDate: "2026-12-10",
      biddingPricePerUnit: 155,
    },
  });
  assert.equal(requested.status, 201);
  assert.equal(requested.data.buyerRequest.product_type, "DEHUSKED_COCONUT");
  assert.equal(requested.data.buyerRequest.requested_quantity, 500);
  assert.equal(
    Number(requested.data.buyerRequest.bidding_price_per_unit),
    155
  );

  const openRequests = await call(
    "GET",
    "/api/owner/buyer-requests?type=DEHUSKED_COCONUT",
    { token: owner.token }
  );
  assert.equal(openRequests.status, 200);
  assert.equal(openRequests.data.length, 1);

  const offer = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: {
      buyerRequestId: requested.data.buyerRequest.id,
      quantity: 500,
      sellerPricePerUnit: 158,
      availableDate: "2026-12-05",
      paymentMethod: "Direct Bank Transfer",
    },
  });
  assert.equal(offer.status, 201);
  assert.equal(offer.data.sellRequest.product_type, "DEHUSKED_COCONUT");
  assert.equal(offer.data.sellRequest.quantity, 500);
  assert.equal(Number(offer.data.sellRequest.seller_price_per_unit), 158);
  assert.equal(offer.data.sellRequest.payment_method, "Direct Bank Transfer");

  // A rolling deployment must not break sending offers when the API is
  // updated before migration 013 reaches the database.
  const pool = require("../config/db");
  await pool.query("ALTER TABLE sell_requests DROP COLUMN payment_method");
  const legacyRequest = await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "DEHUSKED_COCONUT",
      requestedQuantity: 250,
      requiredDate: "2026-12-15",
      biddingPricePerUnit: 150,
    },
  });
  assert.equal(legacyRequest.status, 201);

  const legacyOffer = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: {
      buyerRequestId: legacyRequest.data.buyerRequest.id,
      quantity: 250,
      sellerPricePerUnit: 151,
      paymentMethod: "Cash",
    },
  });
  assert.equal(legacyOffer.status, 201);
  assert.equal(legacyOffer.data.sellRequest.product_type, "DEHUSKED_COCONUT");
  assert.equal(legacyOffer.data.sellRequest.payment_method, "Cash");
  const migratedOffer = await pool.query(
    "SELECT payment_method FROM sell_requests WHERE id = $1",
    [legacyOffer.data.sellRequest.id]
  );
  assert.equal(migratedOffer.rows[0].payment_method, "Cash");
});

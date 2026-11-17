// End-to-end coconut husk checks for both estate-owner and buyer flows.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5107";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5107";

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

test("only husks flow from estate listing through buyer marketplace", async () => {
  const owner = await signup(
    "Husk Land Owner",
    "0715550107",
    "ESTATE_OWNER",
    "Kurunegala"
  );
  const buyer = await signup(
    "Husk Buyer",
    "0775550107",
    "BUYER",
    "Colombo"
  );

  const invalidListing = await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: {
      productType: "COCONUT_HUSK",
      quantity: 10.5,
      availableDate: "2026-12-05",
      offerPricePerUnit: 25,
    },
  });
  assert.equal(invalidListing.status, 400);
  assert.match(invalidListing.data.message, /number of nuts/i);

  const listed = await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: {
      productType: "COCONUT_HUSK",
      quantity: 750,
      availableDate: "2026-12-05",
      offerPricePerUnit: 25,
    },
  });
  assert.equal(listed.status, 201);
  assert.equal(listed.data.listing.product_type, "COCONUT_HUSK");
  assert.equal(listed.data.listing.quantity, 750);
  assert.equal(Number(listed.data.listing.offer_price_per_unit), 25);

  const marketplace = await call(
    "GET",
    "/api/buyer/listings?type=COCONUT_HUSK"
  );
  assert.equal(marketplace.status, 200);
  const listedHusks = marketplace.data.find(
    (listing) => listing.id === listed.data.listing.id
  );
  assert.ok(listedHusks);
  assert.equal(listedHusks.quantity, 750);

  const invalidRequest = await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "COCONUT_HUSK",
      requestedQuantity: 0,
      requiredDate: "2026-12-10",
      biddingPricePerUnit: 22,
    },
  });
  assert.equal(invalidRequest.status, 400);

  const requested = await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "COCONUT_HUSK",
      requestedQuantity: 500,
      requiredDate: "2026-12-10",
      biddingPricePerUnit: 22,
    },
  });
  assert.equal(requested.status, 201);
  assert.equal(requested.data.buyerRequest.product_type, "COCONUT_HUSK");
  assert.equal(requested.data.buyerRequest.requested_quantity, 500);
  assert.equal(Number(requested.data.buyerRequest.bidding_price_per_unit), 22);

  const openRequests = await call(
    "GET",
    "/api/owner/buyer-requests?type=COCONUT_HUSK",
    { token: owner.token }
  );
  assert.equal(openRequests.status, 200);
  assert.equal(openRequests.data.length, 1);

  const offer = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: {
      buyerRequestId: requested.data.buyerRequest.id,
      quantity: 500,
      sellerPricePerUnit: 24,
      availableDate: "2026-12-05",
      paymentMethod: "Direct Bank Transfer",
    },
  });
  assert.equal(offer.status, 201);
  assert.equal(offer.data.sellRequest.product_type, "COCONUT_HUSK");
  assert.equal(offer.data.sellRequest.quantity, 500);
  assert.equal(Number(offer.data.sellRequest.seller_price_per_unit), 24);
  assert.equal(offer.data.sellRequest.payment_method, "Direct Bank Transfer");

  // A rolling deployment must not break sending offers when the API is
  // updated before migration 013 reaches the database.
  const pool = require("../config/db");
  await pool.query("ALTER TABLE sell_requests DROP COLUMN payment_method");
  const legacyRequest = await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "COCONUT_HUSK",
      requestedQuantity: 250,
      requiredDate: "2026-12-15",
      biddingPricePerUnit: 20,
    },
  });
  assert.equal(legacyRequest.status, 201);

  const legacyOffer = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: {
      buyerRequestId: legacyRequest.data.buyerRequest.id,
      quantity: 250,
      sellerPricePerUnit: 21,
      paymentMethod: "Cash",
    },
  });
  assert.equal(legacyOffer.status, 201);
  assert.equal(legacyOffer.data.sellRequest.payment_method, "Cash");
  const migratedOffer = await pool.query(
    "SELECT payment_method FROM sell_requests WHERE id = $1",
    [legacyOffer.data.sellRequest.id]
  );
  assert.equal(migratedOffer.rows[0].payment_method, "Cash");
});

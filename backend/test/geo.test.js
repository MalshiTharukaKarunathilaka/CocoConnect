// Locations at sign-up, "within N km" filters on both sides, and matching
// listings to a buyer's request. Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5097";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5097";

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

// Real places, so the distances are easy to sanity-check on a map.
const COLOMBO = { location: "Colombo", latitude: 6.9271, longitude: 79.8612 };
const KELANIYA = { location: "Kelaniya", latitude: 6.9553, longitude: 79.922 }; // ~7 km
const GAMPAHA = { location: "Gampaha", latitude: 7.084, longitude: 79.9939 }; // ~22 km
const KURUNEGALA = { location: "Kurunegala", latitude: 7.4863, longitude: 80.3647 }; // ~83 km
const KANDY = { location: "Kandy", latitude: 7.2906, longitude: 80.6337 };

const signup = async (name, phone, role, place) => {
  const result = await call("POST", "/api/auth/signup", {
    body: { name, phone, password: "secret123", role, ...place },
  });
  assert.equal(result.status, 201, JSON.stringify(result.data));
  return result.data;
};

const list = async (owner, quantity, availableDate, offerPricePerUnit) => {
  const result = await call("POST", "/api/owner/listings", {
    token: owner.token,
    body: { productType: "RAW_COCONUT", quantity, availableDate, offerPricePerUnit },
  });
  assert.equal(result.status, 201);
  return result.data.listing.id;
};

const mine = (rows, ids) => rows.filter((row) => ids.includes(row.id));

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

let buyer;
let near;
let mid;
let far;
const ids = {};

test("sign-up stores the picked location; bad coordinates are rejected", async () => {
  const bad = await call("POST", "/api/auth/signup", {
    body: {
      name: "X",
      phone: "0700000001",
      password: "secret123",
      role: "BUYER",
      location: "Nowhere",
      latitude: 123,
      longitude: 80,
    },
  });
  assert.equal(bad.status, 400);

  buyer = await signup("Colombo Buyer", "0770000001", "BUYER", COLOMBO);
  assert.equal(buyer.user.latitude, COLOMBO.latitude);
  assert.equal(buyer.user.longitude, COLOMBO.longitude);

  near = await signup("Kelaniya Owner", "0710000001", "ESTATE_OWNER", KELANIYA);
  mid = await signup("Gampaha Owner", "0710000002", "ESTATE_OWNER", GAMPAHA);
  far = await signup("Kurunegala Owner", "0710000003", "ESTATE_OWNER", KURUNEGALA);

  const me = await call("GET", "/api/auth/me", { token: near.token });
  assert.equal(me.data.location, "Kelaniya");
  assert.equal(me.data.latitude, KELANIYA.latitude);
});

test("buyers see estates within the chosen distance", async () => {
  ids.near = await list(near, 1500, "2026-11-20", 135);
  ids.nearSmall = await list(near, 800, "2026-11-20", 110);
  ids.nearEarly = await list(near, 1200, "2026-11-15", 126);
  ids.mid = await list(mid, 1000, "2026-11-22", 128);
  ids.midLate = await list(mid, 2000, "2026-12-10", 125);
  ids.far = await list(far, 3000, "2026-11-19", 120);
  const all = Object.values(ids);

  const at = `lat=${COLOMBO.latitude}&lng=${COLOMBO.longitude}`;

  const within10 = await call(
    "GET",
    `/api/buyer/listings?type=RAW_COCONUT&${at}&radiusKm=10`
  );
  assert.deepEqual(
    mine(within10.data, all).map((l) => l.id).sort(),
    [ids.near, ids.nearSmall, ids.nearEarly].sort()
  );
  const one = within10.data.find((l) => l.id === ids.near);
  assert.ok(one.distance_km > 6 && one.distance_km < 9, `${one.distance_km} km`);
  assert.equal(one.latitude, undefined, "coordinates are not sent to clients");
  // Seeded estates have no account, so no location: left out of a radius.
  assert.ok(within10.data.every((l) => l.distance_km !== null));

  const within25 = await call(
    "GET",
    `/api/buyer/listings?type=RAW_COCONUT&${at}&radiusKm=25`
  );
  assert.equal(mine(within25.data, all).length, 5, "Kurunegala is too far");

  const nearest = await call(
    "GET",
    `/api/buyer/listings?type=RAW_COCONUT&${at}&sort=nearest`
  );
  const order = mine(nearest.data, all).map((l) => l.id);
  assert.equal(order[order.length - 1], ids.far);

  const anywhere = await call("GET", "/api/buyer/listings?type=RAW_COCONUT");
  assert.equal(mine(anywhere.data, all).length, 6);
  assert.ok(anywhere.data.every((l) => l.distance_km === null));
});

test("listings matching a request: enough nuts, date within 7 days, cheapest first", async () => {
  const match = await call(
    "GET",
    "/api/buyer/listings?type=RAW_COCONUT&minQuantity=1000" +
      "&requiredDate=2026-11-18&sort=price_asc"
  );
  assert.equal(match.status, 200);
  // Seeded listing 1 (1200 nuts, 18 Nov, Rs. 130) matches too.
  assert.deepEqual(
    match.data.map((l) => Number(l.offer_price_per_unit)),
    [120, 128, 130, 135]
  );
  assert.ok(match.data.every((l) => l.quantity >= 1000));

  const nearby = await call(
    "GET",
    "/api/buyer/listings?type=RAW_COCONUT&minQuantity=1000" +
      `&requiredDate=2026-11-18&sort=price_asc&lat=${COLOMBO.latitude}` +
      `&lng=${COLOMBO.longitude}&radiusKm=25`
  );
  assert.deepEqual(
    nearby.data.map((l) => l.id),
    [ids.mid, ids.near]
  );

  const bad = await call(
    "GET",
    "/api/buyer/listings?requiredDate=next-week"
  );
  assert.equal(bad.status, 400);
});

test("estate owners see buyer requests within the chosen distance", async () => {
  const kandyBuyer = await signup("Kandy Buyer", "0770000002", "BUYER", KANDY);
  const request = async (who, price) =>
    (await call("POST", "/api/buyer/requests", {
      token: who.token,
      body: {
        productType: "RAW_COCONUT",
        requestedQuantity: 1000,
        requiredDate: "2026-11-25",
        biddingPricePerUnit: price,
      },
    })).data.buyerRequest.id;
  const colomboRequest = await request(buyer, 120);
  const kandyRequest = await request(kandyBuyer, 140);

  const within10 = await call(
    "GET",
    "/api/owner/buyer-requests?type=RAW_COCONUT&radiusKm=10",
    { token: near.token }
  );
  assert.deepEqual(within10.data.map((r) => r.id), [colomboRequest]);
  assert.ok(within10.data[0].distance_km < 9);
  assert.equal(within10.data[0].latitude, undefined);

  const byPrice = await call("GET", "/api/owner/buyer-requests?type=RAW_COCONUT", {
    token: near.token,
  });
  const ours = byPrice.data.filter((r) =>
    [colomboRequest, kandyRequest].includes(r.id)
  );
  assert.deepEqual(ours.map((r) => r.id), [kandyRequest, colomboRequest]);

  const byDistance = await call(
    "GET",
    "/api/owner/buyer-requests?type=RAW_COCONUT&sort=nearest",
    { token: near.token }
  );
  assert.equal(byDistance.data[0].id, colomboRequest);
});

test("profile update can move the user", async () => {
  const moved = await call("PATCH", "/api/auth/me", {
    token: buyer.token,
    body: { name: "Colombo Buyer", ...KANDY },
  });
  assert.equal(moved.status, 200);
  assert.equal(moved.data.location, "Kandy");
  assert.equal(moved.data.latitude, KANDY.latitude);

  // Without coordinates, the saved ones stay.
  const renamed = await call("PATCH", "/api/auth/me", {
    token: buyer.token,
    body: { name: "Renamed", location: "Kandy" },
  });
  assert.equal(renamed.data.latitude, KANDY.latitude);
});

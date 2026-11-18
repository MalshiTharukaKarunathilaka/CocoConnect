// Authentication and access control: sign-up, password hashing, login,
// JWT checks and role-based access, against the in-memory database.
// Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

process.env.DB_MODE = "memory";
process.env.PORT = "5094";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5094";

const call = async (method, path, { token, header, body } = {}) => {
  const response = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(header ? { Authorization: header } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
};

const pool = () => require("../config/db");

const signup = (body) =>
  call("POST", "/api/auth/signup", {
    body: { password: "secret1", location: "Colombo", ...body },
  });

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
let owner;

test("signup creates an account and never returns the password", async () => {
  const res = await signup({ name: "Auth Buyer", phone: "0761000001", role: "Buyer" });
  assert.equal(res.status, 201);
  assert.ok(res.data.token, "a login token is returned");
  assert.equal(res.data.user.name, "Auth Buyer");
  assert.equal(res.data.user.role, "BUYER", "'Buyer' is stored as BUYER");
  assert.equal(res.data.user.password, undefined);
  assert.equal(res.data.user.password_hash, undefined);
  buyer = res.data;

  const ownerRes = await signup({
    name: "Auth Owner",
    phone: "0761000002",
    role: "Estate Owner",
    location: "Kurunegala",
  });
  assert.equal(ownerRes.status, 201);
  assert.equal(ownerRes.data.user.role, "ESTATE_OWNER");
  owner = ownerRes.data;
});

test("passwords are stored as bcrypt hashes, not plain text", async () => {
  const { rows } = await pool().query(
    "SELECT password_hash FROM users WHERE id = $1",
    [buyer.user.id]
  );
  const hash = rows[0].password_hash;
  assert.notEqual(hash, "secret1");
  assert.match(hash, /^\$2[aby]\$10\$/, "bcrypt hash with cost 10");
  assert.equal(await bcrypt.compare("secret1", hash), true);
  assert.equal(await bcrypt.compare("wrong-password", hash), false);
});

test("signup rejects invalid input and duplicate phones", async () => {
  const missing = await call("POST", "/api/auth/signup", { body: { name: "A" } });
  assert.equal(missing.status, 400);

  const shortPassword = await signup({
    name: "A", phone: "0761000003", role: "BUYER", password: "12345",
  });
  assert.equal(shortPassword.status, 400);
  assert.equal(shortPassword.data.message, "Password must be at least 6 characters");

  const noLocation = await signup({
    name: "A", phone: "0761000003", role: "BUYER", location: " ",
  });
  assert.equal(noLocation.status, 400);
  assert.equal(noLocation.data.message, "Location is required");

  const badCoords = await signup({
    name: "A", phone: "0761000003", role: "BUYER", latitude: 200, longitude: 80,
  });
  assert.equal(badCoords.status, 400);
  assert.equal(badCoords.data.message, "Invalid location coordinates");

  const unknownRole = await signup({ name: "A", phone: "0761000003", role: "Pilot" });
  assert.equal(unknownRole.status, 400);
  assert.equal(unknownRole.data.message, "Unknown account type");

  const admin = await signup({ name: "A", phone: "0761000003", role: "ADMIN" });
  assert.equal(admin.status, 400, "nobody can sign up as an admin");

  const duplicate = await signup({ name: "Copy", phone: "0761000001", role: "BUYER" });
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.data.message, "This phone number is already registered");

  const spaced = await signup({ name: "Copy", phone: "076 100 0001", role: "BUYER" });
  assert.equal(spaced.status, 409, "spaces in the phone don't create a second account");
});

test("login checks the password and doesn't reveal which phones exist", async () => {
  const missing = await call("POST", "/api/auth/login", { body: { phone: "0761000001" } });
  assert.equal(missing.status, 400);

  const wrongPassword = await call("POST", "/api/auth/login", {
    body: { phone: "0761000001", password: "not-it" },
  });
  const unknownPhone = await call("POST", "/api/auth/login", {
    body: { phone: "0769999999", password: "secret1" },
  });
  assert.equal(wrongPassword.status, 401);
  assert.equal(unknownPhone.status, 401);
  assert.equal(wrongPassword.data.message, unknownPhone.data.message);
  assert.equal(wrongPassword.data.token, undefined);

  const ok = await call("POST", "/api/auth/login", {
    body: { phone: "076-100 0001", password: "secret1" },
  });
  assert.equal(ok.status, 200);
  assert.equal(ok.data.user.id, buyer.user.id);
  assert.equal(ok.data.user.password_hash, undefined);
  assert.ok(ok.data.token);
});

test("the token is a signed JWT with the user's id and role, valid for 7 days", () => {
  const payload = jwt.verify(buyer.token, process.env.JWT_SECRET);
  assert.equal(payload.id, buyer.user.id);
  assert.equal(payload.role, "BUYER");
  assert.equal(payload.exp - payload.iat, 7 * 24 * 60 * 60);

  assert.throws(() => jwt.verify(buyer.token, "some-other-secret"));
});

test("a valid token returns the current user", async () => {
  const me = await call("GET", "/api/auth/me", { token: owner.token });
  assert.equal(me.status, 200);
  assert.equal(me.data.id, owner.user.id);
  assert.equal(me.data.role, "ESTATE_OWNER");
  assert.equal(me.data.password_hash, undefined);
});

test("protected routes reject missing, malformed, forged and expired tokens", async () => {
  const none = await call("GET", "/api/auth/me");
  assert.equal(none.status, 401);
  assert.equal(none.data.message, "Login required");

  const wrongScheme = await call("GET", "/api/auth/me", { header: `Token ${buyer.token}` });
  assert.equal(wrongScheme.status, 401);

  const garbage = await call("GET", "/api/auth/me", { token: "not.a.token" });
  assert.equal(garbage.status, 401);

  // Same contents, but signed with a secret the server doesn't know.
  const forged = jwt.sign({ id: buyer.user.id, role: "ADMIN" }, "attacker-secret");
  assert.equal((await call("GET", "/api/auth/me", { token: forged })).status, 401);

  const expired = jwt.sign(
    { id: buyer.user.id, name: "Auth Buyer", role: "BUYER" },
    process.env.JWT_SECRET,
    { expiresIn: -10 }
  );
  const expiredRes = await call("GET", "/api/auth/me", { token: expired });
  assert.equal(expiredRes.status, 401);
  assert.equal(expiredRes.data.message, "Session expired, please log in again");

  const ghost = jwt.sign({ id: 999999, role: "BUYER" }, process.env.JWT_SECRET);
  const ghostRes = await call("GET", "/api/auth/me", { token: ghost });
  assert.equal(ghostRes.status, 401, "token for a deleted account");
});

test("role-based access: each role only reaches its own routes", async () => {
  // Public: anyone can browse listings.
  assert.equal((await call("GET", "/api/buyer/listings")).status, 200);

  // Logged out: protected routes need a login.
  assert.equal((await call("GET", "/api/buyer/requests")).status, 401);
  assert.equal((await call("GET", "/api/owner/estate")).status, 401);

  // Own routes work.
  assert.equal((await call("GET", "/api/buyer/requests", { token: buyer.token })).status, 200);
  assert.equal((await call("GET", "/api/owner/estate", { token: owner.token })).status, 200);

  // Other roles' routes are forbidden.
  const ownerOnBuyer = await call("GET", "/api/buyer/requests", { token: owner.token });
  assert.equal(ownerOnBuyer.status, 403);
  assert.equal(ownerOnBuyer.data.message, "Not allowed for this account type");
  assert.equal((await call("GET", "/api/owner/estate", { token: buyer.token })).status, 403);

  // Admin routes are closed to buyers and estate owners.
  assert.equal((await call("GET", "/api/admin/disputes", { token: buyer.token })).status, 403);
  assert.equal((await call("GET", "/api/admin/disputes", { token: owner.token })).status, 403);
});

test("a role change applies on the next request, not at the next login", async () => {
  const res = await signup({ name: "Switcher", phone: "0761000004", role: "BUYER" });
  const token = res.data.token;
  assert.equal((await call("GET", "/api/owner/estate", { token })).status, 403);

  await pool().query("UPDATE users SET role = 'ESTATE_OWNER' WHERE id = $1", [
    res.data.user.id,
  ]);

  // The token still says BUYER, but the server checks the current role.
  assert.equal((await call("GET", "/api/owner/estate", { token })).status, 200);
  assert.equal((await call("GET", "/api/buyer/requests", { token })).status, 403);
});

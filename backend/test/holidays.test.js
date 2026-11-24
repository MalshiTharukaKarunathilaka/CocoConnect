// Only the approved 2026 and 2027 Sri Lankan public holidays are served.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5089";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

const { getHolidays, APPROVED_HOLIDAYS } = require("../utils/holidays");

test("the approved list contains only public holidays for 2026 and 2027", async () => {
  assert.equal(APPROVED_HOLIDAYS.length, 51);
  assert.ok(APPROVED_HOLIDAYS.every((holiday) => holiday.type === "public"));
  assert.ok(
    APPROVED_HOLIDAYS.every(
      (holiday) => holiday.date.startsWith("2026-") || holiday.date.startsWith("2027-")
    )
  );

  const holidays2026 = await getHolidays({ year: 2026 });
  assert.equal(holidays2026.holidays.length, 26);
  assert.equal(holidays2026.stale, false);
  assert.equal(holidays2026.fetched_at, null);
  assert.equal(
    holidays2026.holidays.filter((holiday) => holiday.date === "2026-05-01").length,
    2
  );

  const holidays2028 = await getHolidays({ year: 2028 });
  assert.deepEqual(holidays2028.holidays, []);
});

let server;
const base = "http://localhost:5089";
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

test("GET /api/holidays needs login and returns only the requested approved year", async () => {
  const call = async (path, token) => {
    const response = await fetch(base + path, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    });
    return { status: response.status, data: await response.json() };
  };

  assert.equal((await call("/api/holidays")).status, 401);

  const signup = await fetch(base + "/api/auth/signup", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      name: "Owner",
      phone: "0712345678",
      password: "secret123",
      role: "ESTATE_OWNER",
      location: "Kurunegala",
    }),
  });
  const { token } = await signup.json();

  const holidays2027 = await call("/api/holidays?year=2027", token);
  assert.equal(holidays2027.status, 200);
  assert.equal(holidays2027.data.holidays.length, 25);
  assert.ok(
    holidays2027.data.holidays.every((holiday) => holiday.date.startsWith("2027-"))
  );

  const holidays2028 = await call("/api/holidays?year=2028", token);
  assert.deepEqual(holidays2028.data.holidays, []);
  assert.equal((await call("/api/holidays?year=abc", token)).status, 400);
});

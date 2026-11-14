// Sri Lankan holidays from Google's free public calendar: the feed is parsed,
// kept for a day, and the last good copy is served if Google is unreachable.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5089";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

const holidays = require("../utils/holidays");

// A slice of the real feed's shape: folded line, escaped comma, public holiday,
// observance, and a two-day event.
const ICS = [
  "BEGIN:VCALENDAR",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20261224",
  "DTEND;VALUE=DATE:20261225",
  "SUMMARY:Christmas Eve",
  "DESCRIPTION:Observance",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20260103",
  "DTEND;VALUE=DATE:20260104",
  "DESCRIPTION:Public holiday",
  "SUMMARY:Duruthu Full Moon Poya Day",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20260413",
  "DTEND;VALUE=DATE:20260415",
  "DESCRIPTION:Public holiday",
  "SUMMARY:Sinhala and Tamil New Year\\, with a comma and a very long name that the",
  "  feed folds onto a second line",
  "END:VEVENT",
  "BEGIN:VEVENT",
  "DTSTART;VALUE=DATE:20270101",
  "DTEND;VALUE=DATE:20270102",
  "DESCRIPTION:Public holiday\\nTo hide observances\\, go to Settings",
  "SUMMARY:New Year's Day",
  "END:VEVENT",
  "END:VCALENDAR",
].join("\r\n");

const okFeed = (text = ICS) => async () => ({ ok: true, status: 200, text: async () => text });

test("the feed is parsed into dated holidays, public ones marked as such", () => {
  const list = holidays.parseIcs(ICS);
  assert.deepEqual(list.map((h) => h.date), ["2026-01-03", "2026-04-13", "2026-04-14", "2026-12-24", "2027-01-01"]);
  const poya = list.find((h) => h.date === "2026-01-03");
  assert.deepEqual(poya, { date: "2026-01-03", name: "Duruthu Full Moon Poya Day", type: "public" });
  assert.equal(list.find((h) => h.date === "2026-12-24").type, "observance");
  // escaped commas and folded lines are put back together
  assert.match(list.find((h) => h.date === "2026-04-13").name, /^Sinhala and Tamil New Year, with a comma and a very long name that the feed folds onto a second line$/);
  // a two-day event is one entry for each day
  assert.equal(list.filter((h) => h.name.startsWith("Sinhala")).length, 2);
  assert.equal(list.find((h) => h.date === "2027-01-01").type, "public");
  assert.deepEqual(holidays.parseIcs(""), []);
});

test("the feed is downloaded once a day and the last good copy survives an outage", async () => {
  let calls = 0;
  let working = true;
  holidays.setFetcher(async () => {
    calls += 1;
    if (!working) throw new Error("offline");
    return okFeed()();
  });
  const t0 = Date.parse("2026-11-12T10:00:00Z");

  const first = await holidays.getHolidays({ now: t0 });
  assert.equal(first.stale, false);
  assert.equal(first.holidays.length, 5);
  await holidays.getHolidays({ now: t0 + 3600 * 1000 });
  assert.equal(calls, 1, "kept for the day");

  assert.equal((await holidays.getHolidays({ year: 2026, now: t0 })).holidays.length, 4);

  working = false;
  const next = await holidays.getHolidays({ now: t0 + 25 * 3600 * 1000 });
  assert.equal(calls, 2);
  assert.equal(next.stale, true);
  assert.equal(next.holidays.length, 5, "the old copy is still served");
  await holidays.getHolidays({ now: t0 + 25 * 3600 * 1000 + 60 * 1000 });
  assert.equal(calls, 2, "no hammering Google while it is down");

  working = true;
  const back = await holidays.getHolidays({ now: t0 + 26 * 3600 * 1000 });
  assert.equal(back.stale, false);
  assert.equal(calls, 3);
});

test("with no copy at all and Google down, the answer is empty and marked stale", async () => {
  holidays.setFetcher(async () => ({ ok: false, status: 503, text: async () => "" }));
  const result = await holidays.getHolidays({ now: Date.now() });
  assert.deepEqual(result, { stale: true, fetched_at: null, holidays: [] });
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

test("GET /api/holidays needs a login and can be filtered by year", async () => {
  holidays.setFetcher(okFeed());
  const call = async (path, token) => {
    const r = await fetch(base + path, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
    return { status: r.status, data: await r.json() };
  };
  assert.equal((await call("/api/holidays")).status, 401);

  const signup = await fetch(base + "/api/auth/signup", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name: "Owner", phone: "0712345678", password: "secret123", role: "ESTATE_OWNER", location: "Kurunegala" }),
  });
  const { token } = await signup.json();

  const all = await call("/api/holidays", token);
  assert.equal(all.status, 200);
  assert.equal(all.data.holidays.length, 5);
  assert.equal(all.data.stale, false);
  const y = await call("/api/holidays?year=2027", token);
  assert.deepEqual(y.data.holidays.map((h) => h.date), ["2027-01-01"]);
  assert.equal((await call("/api/holidays?year=abc", token)).status, 400);
});

// The real feed, when the internet is reachable. Skipped (not failed) offline.
test("Google's real feed has Sri Lankan Poya days", async (t) => {
  holidays.setFetcher(null);
  let result;
  try {
    result = await holidays.getHolidays({ now: Date.now() });
  } catch (error) {
    return t.skip("no internet");
  }
  if (result.stale || result.holidays.length === 0) return t.skip("Google feed not reachable");
  assert.ok(result.holidays.length > 100);
  assert.ok(result.holidays.some((h) => /Poya/i.test(h.name) && h.type === "public"));
  assert.ok(result.holidays.every((h) => /^\d{4}-\d{2}-\d{2}$/.test(h.date) && h.name));
});

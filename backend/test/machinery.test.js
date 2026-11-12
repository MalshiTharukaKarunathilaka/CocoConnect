// End-to-end checks of the machinery routes against the in-memory database,
// which has the team's machinery tables and eight sample machines.
// Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5093";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
let db;
const base = "http://localhost:5093";

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

const signup = async (name, phone, role, location, coords = {}) =>
  (await call("POST", "/api/auth/signup", {
    body: { name, phone, password: "secret123", role, location, ...coords },
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
  db = require("../config/db");
  await new Promise((resolve) => setTimeout(resolve, 300));
});

after(() => server.close());

const inDays = (n) => {
  const d = new Date(Date.now() + 5.5 * 3600 * 1000); // today in Sri Lanka
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};

const KURUNEGALA = { latitude: 7.4863, longitude: 80.3647 };
const COLOMBO = { latitude: 6.9271, longitude: 79.8612 };

let owner;
let otherOwner;
let farOwner;
let buyer;
let provider;
let machines;
let massey; // three tractor services
let slasher;
let trailerMachine;
let trailer;

const book = (token, overrides = {}) =>
  call("POST", "/api/machinery/bookings", {
    token,
    body: {
      machineId: massey.id,
      items: [{ serviceId: slasher.id, qty: 4.5 }], // 4.5 acres x Rs. 5,000 = Rs. 22,500
      agreedTotal: 22000,
      date: inDays(5),
      time: "06:00 AM",
      estate: "Green Valley",
      chat: [{ mine: true, text: "Hi", at: new Date().toISOString() }, { mine: false, text: "Sure" }],
      ...overrides,
    },
  });

test("machinery routes need a login and the right account type", async () => {
  owner = await signup("Nimal Owner", "0711000001", "ESTATE_OWNER", "Kurunegala", KURUNEGALA);
  otherOwner = await signup("Kamal Owner", "0711000002", "ESTATE_OWNER", "Puttalam");
  farOwner = await signup("Far Owner", "0711000006", "ESTATE_OWNER", "Colombo", COLOMBO);
  buyer = await signup("Buyer One", "0711000003", "BUYER", "Colombo");
  provider = await signup("Sunil Provider", "0711000004", "SERVICE_PROVIDER", "Kurunegala", KURUNEGALA);

  assert.equal((await call("GET", "/api/machinery/machines")).status, 401);
  assert.equal((await call("POST", "/api/machinery/bookings", { token: buyer.token, body: {} })).status, 403);
  assert.equal((await call("POST", "/api/machinery/machines", { token: owner.token, body: {} })).status, 403);
  assert.equal((await call("GET", "/api/machinery/bookings", { token: provider.token })).status, 403);
});

test("the map lists active machines nearest first, with their services", async () => {
  const all = await call("GET", "/api/machinery/machines", { token: owner.token });
  assert.equal(all.status, 200);
  assert.equal(all.data.length, 8);
  machines = all.data;

  const first = machines[0];
  assert.ok(first.name && first.provider && ["TRACTOR", "BACKHOE", "HAND_TRACTOR"].includes(first.type));
  assert.equal(typeof first.latitude, "number");
  assert.equal(typeof first.distance_km, "number");
  assert.ok(first.service_list.length > 0 && first.service_list.every((s) => s.id && s.rate > 0));
  assert.equal(first.rate, first.service_list[0].rate);
  assert.equal(first.radius_km, 25);
  assert.equal(first.jobs, 0);
  assert.equal(first.rating, null);
  const km = machines.map((m) => m.distance_km);
  assert.deepEqual(km, [...km].sort((a, b) => a - b));

  massey = machines.find((m) => m.name === "Massey Ferguson 240");
  slasher = massey.service_list.find((s) => s.name === "Slasher");
  trailerMachine = machines.find((m) => m.name === "Kubota M6040 4WD");
  trailer = trailerMachine.service_list.find((s) => s.name === "Coconut Haulage Trailer");
  assert.equal(slasher.rate, 5000);
  assert.equal(trailer.unit, "day");
  assert.equal(massey.services, "Slasher · Disc Ploughing · Rotary Tiller");

  const hoes = await call("GET", "/api/machinery/machines?type=backhoe", { token: owner.token });
  assert.equal(hoes.data.length, 2);
  assert.ok(hoes.data.every((m) => m.type === "BACKHOE"));

  const near = await call("GET", "/api/machinery/machines?radius=3", { token: owner.token });
  assert.ok(near.data.length > 0 && near.data.length < 8);
  assert.ok(near.data.every((m) => m.distance_km <= 3));

  assert.equal((await call("GET", "/api/machinery/machines?type=boat", { token: owner.token })).status, 400);
});

test("an owner books a machine and sees it in My Bookings", async () => {
  const made = await book(owner.token);
  assert.equal(made.status, 201);
  assert.match(made.data.code, /^#MC-\d+$/);
  assert.equal(made.data.agreed_total, 22000);
  assert.equal(made.data.list_total, 22500);
  assert.equal(made.data.status, "CONFIRMED");
  assert.equal(made.data.date, inDays(5));
  assert.equal(made.data.time, "06:00 AM");
  assert.equal(made.data.estate, "Green Valley");
  assert.deepEqual(
    made.data.items.map((i) => [i.name, i.unit, i.qty, i.rate]),
    [["Slasher", "acre", 4.5, 5000]]
  );
  assert.equal(made.data.chat.length, 2);
  assert.equal(made.data.chat[0].mine, true);
  assert.equal(made.data.chat[1].mine, false);
  assert.equal(made.data.machine.name, massey.name);
  assert.ok(made.data.km > 0);

  // The row follows the team's design: agreed offer, saved with real moments.
  const row = (await db.query("SELECT * FROM machinery_bookings WHERE id = $1", [made.data.id])).rows[0];
  assert.equal(row.offer_agreed, true);
  assert.equal(Number(row.agreed_total), 22000);
  assert.equal(Number(row.proposed_total), 22000);
  assert.equal(row.version, 1);
  assert.equal(new Date(row.ends_at) - new Date(row.starts_at), 8 * 3600 * 1000);
  assert.equal(new Date(row.starts_at).toISOString().slice(11, 16), "00:30"); // 06:00 in Sri Lanka

  const mine = await call("GET", "/api/machinery/bookings", { token: owner.token });
  assert.equal(mine.data.length, 1);
  assert.equal(mine.data[0].machine.id, massey.id);
  assert.equal(mine.data[0].chat.length, 2);
  assert.equal(mine.data[0].chat[0].mine, true);

  const others = await call("GET", "/api/machinery/bookings", { token: otherOwner.token });
  assert.equal(others.data.length, 0);

  const after = await call("GET", "/api/machinery/machines", { token: owner.token });
  assert.equal(after.data.find((m) => m.id === massey.id).jobs, 0); // not done yet
});

test("late evening times keep the Sri Lankan day", async () => {
  const made = await book(owner.token, { date: inDays(7), time: "11:30 PM", agreedTotal: 22500 });
  assert.equal(made.status, 201);
  assert.equal(made.data.date, inDays(7));
  assert.equal(made.data.time, "11:30 PM");
  const mine = await call("GET", "/api/machinery/bookings", { token: owner.token });
  assert.ok(mine.data.some((b) => b.date === inDays(7) && b.time === "11:30 PM"));
});

test("the same service on the same day cannot be booked twice, but other services and days can", async () => {
  const clash = await book(otherOwner.token);
  assert.equal(clash.status, 409);
  assert.match(clash.data.message, /Slasher.*already booked/);

  const disc = massey.service_list.find((s) => s.name === "Disc Ploughing");
  const otherService = await book(otherOwner.token, { items: [{ serviceId: disc.id, qty: 2 }], agreedTotal: 14000 });
  assert.equal(otherService.status, 201);

  const otherDay = await book(otherOwner.token, { date: inDays(6) });
  assert.equal(otherDay.status, 201);

  const otherMachine = await book(otherOwner.token, {
    machineId: trailerMachine.id,
    items: [{ serviceId: trailer.id, qty: 1 }],
    agreedTotal: 14000,
  });
  assert.equal(otherMachine.status, 201);
});

test("a machine's calendar shows other people's bookings without their prices, and blocked days", async () => {
  await db.query("INSERT INTO machinery_availability (machine_id, day, state, note) VALUES ($1, $2, 'MAINTENANCE', 'Service')", [massey.id, inDays(9)]);

  const mine = await call("GET", `/api/machinery/machines/${massey.id}/schedule`, { token: owner.token });
  assert.equal(mine.status, 200);
  const slasherDay = mine.data.bookings.find((b) => b.date === inDays(5) && b.items.some((i) => i.name === "Slasher"));
  assert.equal(slasherDay.mine, true);
  assert.equal(slasherDay.agreed_total, 22000);
  assert.deepEqual(mine.data.blocked, [{ date: inDays(9), state: "MAINTENANCE", note: "Service" }]);

  const theirs = await call("GET", `/api/machinery/machines/${massey.id}/schedule`, { token: otherOwner.token });
  const sameDay = theirs.data.bookings.find((b) => b.date === inDays(5) && b.items.some((i) => i.name === "Slasher"));
  assert.equal(sameDay.mine, false);
  assert.equal(sameDay.agreed_total, undefined);
  assert.equal(sameDay.estate, undefined);
  assert.equal(sameDay.owner_user_id, undefined);

  assert.equal((await call("GET", "/api/machinery/machines/99999/schedule", { token: owner.token })).status, 404);
});

test("bad bookings are refused with a clear message", async () => {
  const refuse = async (overrides, status, pattern) => {
    const r = await book(owner.token, { date: inDays(10), ...overrides });
    assert.equal(r.status, status, JSON.stringify(overrides));
    assert.match(r.data.message, pattern);
  };
  const rotary = massey.service_list.find((s) => s.name === "Rotary Tiller");
  await refuse({ machineId: 99999 }, 404, /not found/i);
  await refuse({ machineId: "x" }, 400, /machine/i);
  await refuse({ items: [] }, 400, /service/i);
  await refuse({ items: [{ qty: 2 }] }, 400, /id/i);
  await refuse({ items: [{ serviceId: trailer.id, qty: 1 }] }, 400, /not offered/i); // another machine's service
  await refuse({ items: [{ serviceId: 999999, qty: 1 }] }, 400, /not offered/i);
  await refuse({ items: [{ serviceId: slasher.id, qty: 0 }] }, 400, /amount/i);
  await refuse({ items: [{ serviceId: slasher.id, qty: 5000 }] }, 400, /amount/i);
  await refuse({ items: [{ serviceId: slasher.id, qty: 1 }, { serviceId: slasher.id, qty: 2 }] }, 400, /twice/i);
  await refuse({ date: inDays(-1) }, 400, /passed/i);
  await refuse({ date: "2026-02-31" }, 400, /valid date/i);
  await refuse({ date: "soon" }, 400, /valid date/i);
  await refuse({ time: "6am" }, 400, /start time/i);
  await refuse({ agreedTotal: 1 }, 400, /too far/i);
  await refuse({ agreedTotal: 99999999 }, 400, /too far/i);
  await refuse({ agreedTotal: 21999.5 }, 400, /whole number/i);

  // The price comes from the database, so a changed rate in the request is ignored.
  const cheeky = await book(owner.token, {
    date: inDays(10),
    items: [{ serviceId: rotary.id, qty: 2, rate: 1 }],
    agreedTotal: 12000,
  });
  assert.equal(cheeky.status, 201);
  assert.equal(cheeky.data.items[0].rate, 6000);
  assert.equal(cheeky.data.list_total, 12000);
});

test("a provider only works within their service radius", async () => {
  // Colombo is about 75 km from the sample machines, which serve 25 km.
  const far = await book(farOwner.token, { date: inDays(11) });
  assert.equal(far.status, 400);
  assert.match(far.data.message, /within 25 km/);
  // An owner with no saved location is not checked.
  const unknown = await book(otherOwner.token, { date: inDays(11) });
  assert.equal(unknown.status, 201);
});

test("an owner can cancel their own booking, which frees the day", async () => {
  const made = await book(owner.token, { date: inDays(12) });
  assert.equal(made.status, 201);

  assert.equal((await call("PATCH", `/api/machinery/bookings/${made.data.id}/cancel`, { token: otherOwner.token })).status, 404);

  const done = await call("PATCH", `/api/machinery/bookings/${made.data.id}/cancel`, { token: owner.token });
  assert.equal(done.status, 200);
  assert.equal(done.data.status, "CANCELLED");
  const row = (await db.query("SELECT status, version FROM machinery_bookings WHERE id = $1", [made.data.id])).rows[0];
  assert.equal(row.status, "CANCELLED");
  assert.equal(row.version, 2);

  assert.equal((await call("PATCH", `/api/machinery/bookings/${made.data.id}/cancel`, { token: owner.token })).status, 409);

  const mine = await call("GET", "/api/machinery/bookings", { token: owner.token });
  assert.ok(!mine.data.some((b) => b.id === made.data.id));

  const again = await book(otherOwner.token, { date: inDays(12) });
  assert.equal(again.status, 201);
});

test("two owners racing for the same service: only one wins", async () => {
  const [a, b] = await Promise.all([
    book(owner.token, { date: inDays(20) }),
    book(otherOwner.token, { date: inDays(20) }),
  ]);
  const statuses = [a.status, b.status].sort();
  assert.ok(statuses[0] === 201 && statuses[1] === 409, `got ${statuses}`);
  const schedule = await call("GET", `/api/machinery/machines/${massey.id}/schedule`, { token: owner.token });
  assert.equal(schedule.data.bookings.filter((x) => x.date === inDays(20)).length, 1);
});

test("a service provider needs a profile, then lists, changes and hides their own machine", async () => {
  const noProfile = await call("POST", "/api/machinery/machines", {
    token: provider.token,
    body: { name: "Sunil's Kubota", type: "tractor", services: [{ name: "Slasher", unit: "acre", rate: 4800 }] },
  });
  assert.equal(noProfile.status, 400);
  assert.match(noProfile.data.message, /profile/i);
  assert.deepEqual((await call("GET", "/api/machinery/machines/mine", { token: provider.token })).data, []);

  // The provider profile is made at sign-up elsewhere in the app; add it here.
  await db.query(
    `INSERT INTO service_providers (user_id, identity_number, category, machinery_type, district, address, radius_km)
     VALUES ($1, 'N1234', 'Machinery', 'Tractor', 'Kurunegala', 'Kurunegala', 10)`,
    [provider.user.id]
  );

  const bad = await call("POST", "/api/machinery/machines", { token: provider.token, body: { name: "X" } });
  assert.equal(bad.status, 400);
  const noServices = await call("POST", "/api/machinery/machines", { token: provider.token, body: { name: "X", type: "TRACTOR", services: [] } });
  assert.equal(noServices.status, 400);

  const made = await call("POST", "/api/machinery/machines", {
    token: provider.token,
    body: { name: "Sunil's Kubota", type: "tractor", services: [{ name: "Slasher", unit: "acre", rate: 4800 }, { name: "Trailer", unit: "day", rate: 12000 }] },
  });
  assert.equal(made.status, 201);
  assert.equal(made.data.provider, "Sunil Provider");
  assert.equal(made.data.type, "TRACTOR");
  assert.equal(made.data.radius_km, 10);
  assert.equal(made.data.service_list.length, 2);

  const listed = await call("GET", "/api/machinery/machines", { token: owner.token });
  assert.equal(listed.data.length, 9);

  // Raise a rate, rename one service and add another.
  const [first, second] = made.data.service_list;
  const edited = await call("PATCH", `/api/machinery/machines/${made.data.id}`, {
    token: provider.token,
    body: { services: [{ id: first.id, name: "Slasher", unit: "acre", rate: 5200 }, { id: second.id, name: "Haulage Trailer", unit: "day", rate: 12000 }, { name: "Rotary", unit: "acre", rate: 6000 }] },
  });
  assert.equal(edited.status, 200);
  assert.deepEqual(edited.data.service_list.map((s) => [s.name, s.rate]), [["Slasher", 5200], ["Haulage Trailer", 12000], ["Rotary", 6000]]);
  const foreignService = await call("PATCH", `/api/machinery/machines/${made.data.id}`, {
    token: provider.token,
    body: { services: [{ id: trailer.id, name: "Stolen", unit: "day", rate: 1 }] },
  });
  assert.equal(foreignService.status, 400);

  const other = await signup("Other Provider", "0711000005", "SERVICE_PROVIDER", "Galle");
  await db.query("INSERT INTO service_providers (user_id, identity_number, category, machinery_type, district, address, radius_km) VALUES ($1, 'N5678', 'Machinery', 'Tractor', 'Galle', 'Galle', 5)", [other.user.id]);
  assert.equal((await call("PATCH", `/api/machinery/machines/${made.data.id}`, { token: other.token, body: { name: "Mine now" } })).status, 404);

  // An owner books it; the provider sees the job.
  const job = await book(owner.token, { machineId: made.data.id, items: [{ serviceId: first.id, qty: 3 }], agreedTotal: 15600, date: inDays(8) });
  assert.equal(job.status, 201);
  assert.equal(job.data.items[0].rate, 5200);
  const theirJobs = await call("GET", "/api/machinery/provider/bookings", { token: provider.token });
  assert.equal(theirJobs.data.length, 1);
  assert.equal(theirJobs.data[0].machine_name, "Sunil's Kubota");
  assert.equal(theirJobs.data[0].date, inDays(8));
  assert.equal(theirJobs.data[0].agreed_total, 15600);

  const hidden = await call("PATCH", `/api/machinery/machines/${made.data.id}`, { token: provider.token, body: { active: false } });
  assert.equal(hidden.data.active, false);
  const after = await call("GET", "/api/machinery/machines", { token: owner.token });
  assert.equal(after.data.length, 8);
  assert.equal((await book(owner.token, { machineId: made.data.id, items: [{ serviceId: first.id, qty: 1 }], date: inDays(9) })).status, 404);

  const mine = await call("GET", "/api/machinery/machines/mine", { token: provider.token });
  assert.equal(mine.data.length, 1);
  assert.equal(mine.data[0].active, false);
});

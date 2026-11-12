const pool = require("../config/db");
const { parseCoords, parseRadius, distanceKm, dayOf } = require("../utils/geo");

/*
|--------------------------------------------------------------------------
| MACHINERY
|--------------------------------------------------------------------------
| Works on the team's machinery tables:
|   service_providers       who lists machines (and how far they will travel)
|   machinery               a tractor, backhoe or hand tractor
|   machinery_services      what it does, with a rate per acre / hour / day
|   machinery_availability  days the provider has blocked
|   machinery_bookings      an estate owner's booking of a machine
|   machinery_booking_items the services in that booking
|   machinery_messages      the chat about the price
|
| A machine is shown where its provider's login is (users.latitude and
| longitude). Everything is checked on the server, and prices are taken from
| machinery_services, never from the app.
*/

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  return res.status(500).json({ message: "Server error", error: error.message });
};

const TYPE_OF = { Tractor: "TRACTOR", Backhoe: "BACKHOE", "Hand Tractor": "HAND_TRACTOR" };
const CATEGORY_OF = { TRACTOR: "Tractor", BACKHOE: "Backhoe", HAND_TRACTOR: "Hand Tractor" };
const UNITS = ["acre", "hour", "day"];
const ACTIVE = ["PENDING", "CONFIRMED"]; // bookings that hold a day
const TIME_PATTERN = /^(0[1-9]|1[0-2]):[0-5]\d (AM|PM)$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const MAX_ITEMS = 10;
const MAX_CHAT_LINES = 200;
const WORK_HOURS = 8; // a booking runs for a working day from its start time

// Sri Lanka is UTC+05:30 all year. Bookings are saved as real moments, and the
// day and clock shown to people are the Sri Lankan ones.
const COLOMBO_MS = 5.5 * 60 * 60 * 1000;
const colomboClock = (moment) => {
  const d = new Date(new Date(moment).getTime() + COLOMBO_MS);
  const iso = d.toISOString();
  const h24 = d.getUTCHours();
  const h = h24 % 12 === 0 ? 12 : h24 % 12;
  return {
    date: iso.slice(0, 10),
    time: `${String(h).padStart(2, "0")}:${iso.slice(14, 16)} ${h24 < 12 ? "AM" : "PM"}`,
  };
};
const colomboToday = () => colomboClock(new Date()).date;
const momentOf = (date, time) => {
  const [clock, ampm] = time.split(" ");
  const [hh, mm] = clock.split(":").map(Number);
  const h24 = (hh % 12) + (ampm === "PM" ? 12 : 0);
  return new Date(`${date}T${String(h24).padStart(2, "0")}:${String(mm).padStart(2, "0")}:00+05:30`);
};

const isRealDate = (text) => {
  if (!DATE_PATTERN.test(text)) return false;
  const date = new Date(`${text}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === text;
};

const ids = (rows, key) => [...new Set(rows.map((r) => Number(r[key])))].filter(Number.isInteger);
const inList = (list) => (list.length ? list.join(",") : "NULL"); // list holds checked integers only

const bookingCode = (id) => `#MC-${1000 + Number(id)}`;
const lineTotal = (item) => (item.unit === "day" ? Number(item.rate) : Math.round(Number(item.rate) * Number(item.qty)));

/*
|--------------------------------------------------------------------------
| Loading machines
|--------------------------------------------------------------------------
*/
const MACHINE_SELECT = `
  SELECT m.id, m.name, m.category, m.active, m.provider_id,
         sp.user_id AS provider_user_id, sp.radius_km, sp.district,
         u.name AS provider_name, u.latitude, u.longitude
  FROM machinery m
  JOIN service_providers sp ON sp.id = m.provider_id
  JOIN users u ON u.id = sp.user_id`;

/** Machines as the app shows them, with their services and finished-job count. */
const buildMachines = async (rows, origin) => {
  if (rows.length === 0) return [];
  const machineIds = ids(rows, "id");
  const services = await pool.query(
    `SELECT id, machine_id, name, unit, rate FROM machinery_services WHERE machine_id IN (${inList(machineIds)}) ORDER BY id`
  );
  const done = await pool.query(
    `SELECT machine_id, ends_at FROM machinery_bookings
     WHERE machine_id IN (${inList(machineIds)}) AND status = 'CONFIRMED'`
  );
  const now = Date.now();
  const jobs = {};
  for (const b of done.rows) {
    if (new Date(b.ends_at).getTime() < now) jobs[b.machine_id] = (jobs[b.machine_id] || 0) + 1;
  }

  return rows.map((m) => {
    const list = services.rows
      .filter((s) => s.machine_id === m.id)
      .map((s) => ({ id: s.id, name: s.name, unit: s.unit, rate: Number(s.rate) }));
    const head = list[0];
    const point = parseCoords(m.latitude, m.longitude);
    const km = origin && point ? Math.round(distanceKm(origin, point) * 10) / 10 : null;
    return {
      id: m.id,
      name: m.name,
      provider: m.provider_name,
      type: TYPE_OF[m.category] || "TRACTOR",
      services: list.map((s) => s.name).join(" · "),
      service_list: list,
      rate: head ? head.rate : 0,
      unit: head ? head.unit : "acre",
      latitude: point ? point.lat : null,
      longitude: point ? point.lng : null,
      radius_km: m.radius_km === null || m.radius_km === undefined ? null : Number(m.radius_km),
      active: m.active === true,
      rating: null, // nobody has rated machines yet
      jobs: jobs[m.id] || 0,
      photo: Number(m.id) % 4,
      distance_km: km,
    };
  });
};

const originOf = async (req) => {
  const fromQuery = parseCoords(req.query?.lat, req.query?.lng);
  if (fromQuery) return fromQuery;
  const me = await pool.query("SELECT latitude, longitude FROM users WHERE id = $1", [req.user.id]);
  return me.rows[0] ? parseCoords(me.rows[0].latitude, me.rows[0].longitude) : null;
};

/** Items of the given bookings, grouped by booking id. */
const itemsByBooking = async (bookingIds) => {
  const result = await pool.query(
    `SELECT id, booking_id, service_id, name, unit, quantity, rate FROM machinery_booking_items
     WHERE booking_id IN (${inList(bookingIds)}) ORDER BY id`
  );
  const map = {};
  for (const i of result.rows) {
    (map[i.booking_id] ||= []).push({
      id: i.id,
      service_id: i.service_id,
      name: i.name,
      unit: i.unit,
      qty: Number(i.quantity),
      rate: Number(i.rate),
    });
  }
  return map;
};

/*
|--------------------------------------------------------------------------
| MACHINES (everyone logged in can look)
|--------------------------------------------------------------------------
*/
const listMachines = async (req, res) => {
  try {
    const type = req.query.type ? String(req.query.type).toUpperCase() : null;
    if (type && !CATEGORY_OF[type]) {
      return res.status(400).json({ message: "Type must be TRACTOR, BACKHOE or HAND_TRACTOR" });
    }
    const result = type
      ? await pool.query(`${MACHINE_SELECT} WHERE m.active = true AND m.category = $1 ORDER BY m.id`, [CATEGORY_OF[type]])
      : await pool.query(`${MACHINE_SELECT} WHERE m.active = true ORDER BY m.id`);

    const origin = await originOf(req);
    const radius = parseRadius(req.query.radius);
    let machines = await buildMachines(result.rows, origin);
    machines = machines.filter((m) => m.latitude !== null); // the map needs a position
    if (radius && origin) machines = machines.filter((m) => m.distance_km !== null && m.distance_km <= radius);
    machines.sort((a, b) => (a.distance_km ?? Infinity) - (b.distance_km ?? Infinity));
    return res.status(200).json(machines);
  } catch (error) {
    return serverError(res, "List machines", error);
  }
};

/**
 * A machine's calendar: bookings from yesterday on, and days the provider has
 * blocked. Other people's bookings only show what is needed to grey the day
 * out (the services and the time), never who made them or what they paid.
 */
const getMachineSchedule = async (req, res) => {
  try {
    const machineId = Number(req.params.id);
    if (!Number.isInteger(machineId)) return res.status(400).json({ message: "Invalid machine" });
    const machine = await pool.query("SELECT id FROM machinery WHERE id = $1 AND active = true", [machineId]);
    if (machine.rows.length === 0) return res.status(404).json({ message: "Machine not found" });

    const since = dayOf(new Date(Date.now() - 86400000));
    const bookings = await pool.query(
      `SELECT id, owner_user_id, starts_at, agreed_total FROM machinery_bookings
       WHERE machine_id = $1 AND status IN ('PENDING', 'CONFIRMED') ORDER BY starts_at, id`,
      [machineId]
    );
    const rows = bookings.rows.filter((b) => colomboClock(b.starts_at).date >= since);
    const items = await itemsByBooking(ids(rows, "id"));

    const blocked = await pool.query(
      "SELECT day, state, note FROM machinery_availability WHERE machine_id = $1 AND state <> 'AVAILABLE' ORDER BY day",
      [machineId]
    );

    return res.status(200).json({
      bookings: rows.map((b) => {
        const mine = b.owner_user_id === req.user.id;
        const when = colomboClock(b.starts_at);
        return {
          id: b.id,
          code: bookingCode(b.id),
          date: when.date,
          time: when.time,
          items: (items[b.id] || []).map(({ service_id, name, unit, qty, rate }) => ({ service_id, name, unit, qty, rate })),
          mine,
          ...(mine ? { agreed_total: Number(b.agreed_total) } : {}),
        };
      }),
      blocked: blocked.rows
        .map((d) => ({ date: dayOf(d.day), state: d.state, note: d.note || "" }))
        .filter((d) => d.date >= since),
    });
  } catch (error) {
    return serverError(res, "Machine schedule", error);
  }
};

/*
|--------------------------------------------------------------------------
| BOOKINGS (estate owners)
|--------------------------------------------------------------------------
*/
const parseChat = (raw) => {
  if (!Array.isArray(raw)) return [];
  return raw
    .slice(-MAX_CHAT_LINES)
    .map((line) => {
      const at = new Date(line?.at);
      return {
        mine: line?.mine === true,
        text: String(line?.text || "").trim().slice(0, 500),
        at: Number.isNaN(at.getTime()) ? new Date() : at,
      };
    })
    .filter((line) => line.text);
};

/** The first requested service another active booking already holds that day, or null. */
const takenService = async (machineId, date, serviceIds, ownBookingId, ownItemIds) => {
  const result = await pool.query(
    `SELECT b.id, b.starts_at, i.id AS item_id, i.service_id, i.name
     FROM machinery_bookings b
     JOIN machinery_booking_items i ON i.booking_id = b.id
     WHERE b.machine_id = $1 AND b.status IN ('PENDING', 'CONFIRMED')`,
    [machineId]
  );
  for (const row of result.rows) {
    if (row.id === ownBookingId) continue;
    if (colomboClock(row.starts_at).date !== date) continue;
    if (!serviceIds.includes(row.service_id)) continue;
    if (ownItemIds) {
      // Re-check after our own insert: the item saved first wins.
      const mineForService = ownItemIds[row.service_id];
      if (mineForService === undefined || row.item_id > mineForService) continue;
    }
    return row.name;
  }
  return null;
};

const createBooking = async (req, res) => {
  try {
    const machineId = Number(req.body.machineId);
    if (!Number.isInteger(machineId)) return res.status(400).json({ message: "Choose a machine" });

    const found = await pool.query(`${MACHINE_SELECT} WHERE m.id = $1 AND m.active = true`, [machineId]);
    const machineRow = found.rows[0];
    if (!machineRow) return res.status(404).json({ message: "Machine not found" });

    // Services: only ids from this machine; the rate always comes from the database.
    const raw = req.body.items;
    if (!Array.isArray(raw) || raw.length === 0) return res.status(400).json({ message: "Pick at least one service" });
    if (raw.length > MAX_ITEMS) return res.status(400).json({ message: `Book at most ${MAX_ITEMS} services at a time` });
    const wantedIds = raw.map((i) => Number(i?.serviceId));
    if (wantedIds.some((id) => !Number.isInteger(id))) return res.status(400).json({ message: "Each service needs an id" });
    if (new Set(wantedIds).size !== wantedIds.length) return res.status(400).json({ message: "A service is listed twice" });

    const svc = await pool.query(
      `SELECT id, name, unit, rate FROM machinery_services WHERE machine_id = $1 AND id IN (${inList(wantedIds)})`,
      [machineId]
    );
    if (svc.rows.length !== wantedIds.length) {
      return res.status(400).json({ message: "One of those services is not offered by this machine" });
    }
    const items = [];
    for (const entry of raw) {
      const service = svc.rows.find((s) => s.id === Number(entry.serviceId));
      const qty = service.unit === "day" ? 1 : Number(entry.qty);
      if (!Number.isFinite(qty) || qty <= 0 || qty > 1000) {
        return res.status(400).json({ message: `Check the amount of work for ${service.name}` });
      }
      items.push({ service_id: service.id, name: service.name, unit: service.unit, qty, rate: Number(service.rate) });
    }

    const date = String(req.body.date || "");
    if (!isRealDate(date)) return res.status(400).json({ message: "Pick a valid date" });
    if (date < colomboToday()) return res.status(400).json({ message: "That day has already passed" });
    const time = String(req.body.time || "");
    if (!TIME_PATTERN.test(time)) return res.status(400).json({ message: "Pick a valid start time, like 06:00 AM" });

    const listTotal = items.reduce((sum, i) => sum + lineTotal(i), 0);
    const agreedTotal = Number(req.body.agreedTotal);
    if (!Number.isInteger(agreedTotal) || agreedTotal <= 0) {
      return res.status(400).json({ message: "The agreed price must be a whole number of rupees" });
    }
    if (agreedTotal < listTotal * 0.5 || agreedTotal > listTotal * 1.5) {
      return res.status(400).json({ message: "The agreed price is too far from the list price" });
    }

    // The provider only travels so far from where they are based.
    const me = await pool.query("SELECT name, location, latitude, longitude FROM users WHERE id = $1", [req.user.id]);
    const owner = me.rows[0];
    const estateAt = parseCoords(req.body.latitude, req.body.longitude) || parseCoords(owner.latitude, owner.longitude);
    const machineAt = parseCoords(machineRow.latitude, machineRow.longitude);
    const km = estateAt && machineAt ? Math.round(distanceKm(estateAt, machineAt) * 10) / 10 : 0;
    const reach = Number(machineRow.radius_km);
    if (estateAt && machineAt && reach > 0 && km > reach) {
      return res.status(400).json({ message: `This provider only works within ${reach} km of where they are based` });
    }

    const wantedServices = items.map((i) => i.service_id);
    const taken = await takenService(machineId, date, wantedServices, null, null);
    if (taken) return res.status(409).json({ message: `${taken} is already booked on that day` });

    const startsAt = momentOf(date, time);
    const endsAt = new Date(startsAt.getTime() + WORK_HOURS * 3600 * 1000);
    const estateName = String(req.body.estate || "").trim().slice(0, 160) || `${owner.name} Estate`;
    const address = String(req.body.address || owner.location || estateName).slice(0, 300);

    const inserted = await pool.query(
      `INSERT INTO machinery_bookings
         (machine_id, owner_user_id, estate_name, address, latitude, longitude, starts_at, ends_at,
          status, proposed_total, proposed_by, offer_agreed, agreed_total)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'CONFIRMED', $9, $2, true, $9)
       RETURNING *`,
      [machineId, req.user.id, estateName, address, estateAt ? estateAt.lat : null, estateAt ? estateAt.lng : null, startsAt, endsAt, agreedTotal]
    );
    const booking = inserted.rows[0];

    const ownItemIds = {};
    try {
      for (const item of items) {
        const row = await pool.query(
          `INSERT INTO machinery_booking_items (booking_id, service_id, name, unit, quantity, rate)
           VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
          [booking.id, item.service_id, item.name, item.unit, item.qty, item.rate]
        );
        ownItemIds[item.service_id] = row.rows[0].id;
      }

      // Two owners booking the same service at the same moment: the item saved
      // first wins, the other booking is undone.
      const clash = await takenService(machineId, date, wantedServices, booking.id, ownItemIds);
      if (clash) {
        await undoBooking(booking.id);
        return res.status(409).json({ message: `${clash} was just booked by someone else` });
      }

      // The chat about the price.
      for (const line of parseChat(req.body.chat)) {
        await pool.query(
          "INSERT INTO machinery_messages (booking_id, sender_id, message, created_at) VALUES ($1, $2, $3, $4)",
          [booking.id, line.mine ? req.user.id : Number(machineRow.provider_user_id), line.text, line.at]
        );
      }
    } catch (error) {
      await undoBooking(booking.id).catch(() => {});
      throw error;
    }

    const [machine] = await buildMachines([machineRow], estateAt);
    return res.status(201).json(await bookingOut(booking, machine, req.user.id));
  } catch (error) {
    return serverError(res, "Create machine booking", error);
  }
};

const undoBooking = async (bookingId) => {
  await pool.query("DELETE FROM machinery_messages WHERE booking_id = $1", [bookingId]);
  await pool.query("DELETE FROM machinery_booking_items WHERE booking_id = $1", [bookingId]);
  await pool.query("DELETE FROM machinery_bookings WHERE id = $1", [bookingId]);
};

/** A booking as the app shows it. */
const bookingOut = async (row, machine, viewerId, preloaded) => {
  const items = preloaded?.items?.[row.id] || (await itemsByBooking([row.id]))[row.id] || [];
  const chatRows =
    preloaded?.chat?.[row.id] ||
    (
      await pool.query(
        "SELECT sender_id, message, created_at FROM machinery_messages WHERE booking_id = $1 ORDER BY created_at, id",
        [row.id]
      )
    ).rows;
  const when = colomboClock(row.starts_at);
  const machineAt = machine && machine.latitude !== null ? { lat: machine.latitude, lng: machine.longitude } : null;
  const estateAt = parseCoords(row.latitude, row.longitude);
  return {
    id: row.id,
    code: bookingCode(row.id),
    machine_id: row.machine_id,
    items,
    list_total: items.reduce((sum, i) => sum + lineTotal(i), 0),
    agreed_total: Number(row.agreed_total ?? row.proposed_total),
    date: when.date,
    time: when.time,
    estate: row.estate_name,
    address: row.address,
    km: machineAt && estateAt ? Math.round(distanceKm(estateAt, machineAt) * 10) / 10 : 0,
    status: row.status,
    chat: chatRows.map((c) => ({ mine: c.sender_id === viewerId, text: c.message, at: new Date(c.created_at).toISOString() })),
    created_at: row.created_at,
    ...(machine ? { machine } : {}),
  };
};

const listMyBookings = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM machinery_bookings WHERE owner_user_id = $1 AND status IN ('PENDING', 'CONFIRMED') ORDER BY starts_at, id",
      [req.user.id]
    );
    const rows = result.rows;
    if (rows.length === 0) return res.status(200).json([]);

    const machineRows = await pool.query(`${MACHINE_SELECT} WHERE m.id IN (${inList(ids(rows, "machine_id"))})`);
    const machines = await buildMachines(machineRows.rows, null);
    const items = await itemsByBooking(ids(rows, "id"));
    const messages = await pool.query(
      `SELECT booking_id, sender_id, message, created_at FROM machinery_messages
       WHERE booking_id IN (${inList(ids(rows, "id"))}) ORDER BY created_at, id`
    );
    const chat = {};
    for (const m of messages.rows) (chat[m.booking_id] ||= []).push(m);

    return res.status(200).json(
      await Promise.all(
        rows.map((b) => bookingOut(b, machines.find((m) => m.id === b.machine_id), req.user.id, { items, chat: { ...Object.fromEntries(rows.map((r) => [r.id, []])), ...chat } }))
      )
    );
  } catch (error) {
    return serverError(res, "My machine bookings", error);
  }
};

const cancelBooking = async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ message: "Invalid booking" });

    const found = await pool.query("SELECT * FROM machinery_bookings WHERE id = $1", [id]);
    const booking = found.rows[0];
    if (!booking || booking.owner_user_id !== req.user.id) return res.status(404).json({ message: "Booking not found" });
    if (!ACTIVE.includes(booking.status)) return res.status(409).json({ message: "This booking is already cancelled" });
    if (colomboClock(booking.starts_at).date < colomboToday()) {
      return res.status(409).json({ message: "This job is already done, so it cannot be cancelled" });
    }

    await pool.query("UPDATE machinery_bookings SET status = 'CANCELLED', version = version + 1 WHERE id = $1", [id]);
    return res.status(200).json({ id, status: "CANCELLED" });
  } catch (error) {
    return serverError(res, "Cancel machine booking", error);
  }
};

/*
|--------------------------------------------------------------------------
| PROVIDERS (list and manage their own machines)
|--------------------------------------------------------------------------
*/
const providerOf = async (userId) => {
  const result = await pool.query("SELECT id FROM service_providers WHERE user_id = $1", [userId]);
  return result.rows[0] || null;
};

const parseServices = (raw) => {
  if (!Array.isArray(raw) || raw.length === 0) return { error: "Add at least one service with its rate" };
  const list = [];
  for (const entry of raw) {
    const name = String(entry?.name || "").trim();
    const unit = String(entry?.unit || "");
    const rate = Number(entry?.rate);
    const id = entry?.id === undefined ? null : Number(entry.id);
    if (!name || name.length > 80) return { error: "Each service needs a name" };
    if (!UNITS.includes(unit)) return { error: `Unit for ${name} must be acre, hour or day` };
    if (!Number.isFinite(rate) || rate <= 0 || rate > 1000000) return { error: `Check the rate for ${name}` };
    if (id !== null && !Number.isInteger(id)) return { error: "Invalid service" };
    list.push({ id, name, unit, rate });
  }
  return { list };
};

const createMachine = async (req, res) => {
  try {
    const provider = await providerOf(req.user.id);
    if (!provider) return res.status(400).json({ message: "Finish your service provider profile first" });

    const name = String(req.body.name || "").trim();
    const category = CATEGORY_OF[String(req.body.type || "").toUpperCase()];
    if (!name || name.length > 120) return res.status(400).json({ message: "Give the machine a name" });
    if (!category) return res.status(400).json({ message: "Type must be TRACTOR, BACKHOE or HAND_TRACTOR" });
    const parsed = parseServices(req.body.services);
    if (parsed.error) return res.status(400).json({ message: parsed.error });

    const made = await pool.query(
      "INSERT INTO machinery (provider_id, name, category, active) VALUES ($1, $2, $3, true) RETURNING id",
      [provider.id, name, category]
    );
    const machineId = made.rows[0].id;
    for (const s of parsed.list) {
      await pool.query("INSERT INTO machinery_services (machine_id, name, unit, rate) VALUES ($1, $2, $3, $4)", [machineId, s.name, s.unit, s.rate]);
    }
    const [machine] = await buildMachines((await pool.query(`${MACHINE_SELECT} WHERE m.id = $1`, [machineId])).rows, null);
    return res.status(201).json(machine);
  } catch (error) {
    return serverError(res, "Create machine", error);
  }
};

/** Change the name, hide or show a machine, and change, rename or add services. Services are never deleted, past bookings point at them. */
const updateMachine = async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ message: "Invalid machine" });
    const provider = await providerOf(req.user.id);
    const found = await pool.query("SELECT * FROM machinery WHERE id = $1", [id]);
    const machine = found.rows[0];
    if (!provider || !machine || machine.provider_id !== provider.id) return res.status(404).json({ message: "Machine not found" });

    const name = req.body.name === undefined ? machine.name : String(req.body.name).trim();
    if (!name || name.length > 120) return res.status(400).json({ message: "Give the machine a name" });
    const active = req.body.active === undefined ? machine.active : req.body.active === true;

    let services = null;
    if (req.body.services !== undefined) {
      const parsed = parseServices(req.body.services);
      if (parsed.error) return res.status(400).json({ message: parsed.error });
      services = parsed.list;
      const own = await pool.query("SELECT id FROM machinery_services WHERE machine_id = $1", [id]);
      if (services.some((s) => s.id !== null && !own.rows.some((o) => o.id === s.id))) {
        return res.status(400).json({ message: "One of those services is not on this machine" });
      }
    }

    await pool.query("UPDATE machinery SET name = $2, active = $3 WHERE id = $1", [id, name, active]);
    for (const s of services || []) {
      if (s.id === null) {
        await pool.query("INSERT INTO machinery_services (machine_id, name, unit, rate) VALUES ($1, $2, $3, $4)", [id, s.name, s.unit, s.rate]);
      } else {
        await pool.query("UPDATE machinery_services SET name = $2, unit = $3, rate = $4 WHERE id = $1", [s.id, s.name, s.unit, s.rate]);
      }
    }
    const [out] = await buildMachines((await pool.query(`${MACHINE_SELECT} WHERE m.id = $1`, [id])).rows, null);
    return res.status(200).json(out);
  } catch (error) {
    return serverError(res, "Update machine", error);
  }
};

const listMyMachines = async (req, res) => {
  try {
    const provider = await providerOf(req.user.id);
    if (!provider) return res.status(200).json([]);
    const rows = await pool.query(`${MACHINE_SELECT} WHERE m.provider_id = $1 ORDER BY m.id`, [provider.id]);
    return res.status(200).json(await buildMachines(rows.rows, null));
  } catch (error) {
    return serverError(res, "My machines", error);
  }
};

/** Bookings made on the provider's own machines. */
const listProviderBookings = async (req, res) => {
  try {
    const provider = await providerOf(req.user.id);
    if (!provider) return res.status(200).json([]);
    const result = await pool.query(
      `SELECT b.*, m.name AS machine_name FROM machinery_bookings b
       JOIN machinery m ON m.id = b.machine_id
       WHERE m.provider_id = $1 AND b.status IN ('PENDING', 'CONFIRMED')
       ORDER BY b.starts_at, b.id`,
      [provider.id]
    );
    const items = await itemsByBooking(ids(result.rows, "id"));
    return res.status(200).json(
      result.rows.map((b) => {
        const when = colomboClock(b.starts_at);
        const list = items[b.id] || [];
        return {
          id: b.id,
          code: bookingCode(b.id),
          machine_id: b.machine_id,
          machine_name: b.machine_name,
          estate: b.estate_name,
          address: b.address,
          date: when.date,
          time: when.time,
          items: list,
          list_total: list.reduce((sum, i) => sum + lineTotal(i), 0),
          agreed_total: Number(b.agreed_total ?? b.proposed_total),
          status: b.status,
        };
      })
    );
  } catch (error) {
    return serverError(res, "Provider bookings", error);
  }
};

module.exports = {
  listMachines,
  getMachineSchedule,
  createBooking,
  listMyBookings,
  cancelBooking,
  createMachine,
  updateMachine,
  listMyMachines,
  listProviderBookings,
};

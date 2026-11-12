// Sample machinery for demos and the in-memory test database: eight machines
// from eight made-up providers around Kurunegala (7.4863, 80.3647). Each
// provider is a user with the role SERVICE_PROVIDER, a service_providers row,
// a machine and its services. The demo logins cannot be used to sign in.
//
// Never added to the shared database unless someone runs
// `node scripts/seedMachinery.js`, or starts the backend with `npm run dev:memory`.
const CENTER = { lat: 7.4863, lng: 80.3647 };
const PASSWORD_HASH = "!demo-provider-cannot-log-in";

// provider, machine, category, dLat, dLng, services: [name, unit, rate] (first is the headline price)
const ROWS = [
  ["Sunil Machinery", "Massey Ferguson 240", "Tractor", 0.018, 0.022, [["Slasher", "acre", 5000], ["Disc Ploughing", "acre", 7000], ["Rotary Tiller", "acre", 6000]]],
  ["Nimal Farm Mechanization", "Kubota M6040 4WD", "Tractor", -0.024, 0.031, [["Slasher", "acre", 4800], ["Coconut Haulage Trailer", "day", 14000]]],
  ["Dambokka Agro", "Mahindra 575 DI", "Tractor", 0.035, -0.019, [["Koku Nagula", "acre", 4500], ["Rotary Tiller", "acre", 5500]]],
  ["Ruwan Tractor Service", "Swaraj 744 FE", "Tractor", -0.041, -0.028, [["Disc Ploughing", "acre", 6800], ["Coconut Haulage Trailer", "day", 13000]]],
  ["Saman Agro Services", "Kubota Power Tiller", "Hand Tractor", 0.027, 0.004, [["Weeding", "acre", 3200], ["Inter-row Tilling", "acre", 3000], ["Small Trailer Haulage", "day", 9000]]],
  ["Perera Farm Tools", "Yanmar 2-Wheel Tractor", "Hand Tractor", -0.013, -0.036, [["Inter-row Tilling", "acre", 3000], ["Small Trailer Haulage", "day", 8500]]],
  ["Kithsiri Earthmovers", "JCB 3CX", "Backhoe", 0.006, -0.043, [["Ditch & Drainage", "hour", 4200], ["Pit Digging", "hour", 4200]]],
  ["Lanka Excavations", "CAT 424B", "Backhoe", -0.052, 0.009, [["Ditch & Drainage", "hour", 6000], ["Land Clearing", "hour", 6500]]],
];

const round6 = (n) => Math.round(n * 1e6) / 1e6;

const DEMO_MACHINES = ROWS.map(([provider, name, category, dLat, dLng, services], i) => ({
  provider,
  name,
  category,
  phone: `07009000${String(i + 1).padStart(2, "0")}`, // made-up numbers, one per provider
  latitude: round6(CENTER.lat + dLat),
  longitude: round6(CENTER.lng + dLng),
  services,
}));

/**
 * Adds the sample providers and machines that are not there yet (matched by
 * the provider's made-up phone number). `db` is a pg Pool. Returns how many
 * machines were added.
 */
const seedDemoMachines = async (db) => {
  let added = 0;
  for (const m of DEMO_MACHINES) {
    const exists = await db.query("SELECT id FROM users WHERE phone = $1", [m.phone]);
    if (exists.rows.length > 0) continue;

    const user = await db.query(
      `INSERT INTO users (name, phone, password_hash, role, location, latitude, longitude)
       VALUES ($1, $2, $3, 'SERVICE_PROVIDER', 'Kurunegala', $4, $5) RETURNING id`,
      [m.provider, m.phone, PASSWORD_HASH, m.latitude, m.longitude]
    );
    const provider = await db.query(
      `INSERT INTO service_providers
         (user_id, identity_number, category, machinery_type, district, address, radius_km)
       VALUES ($1, $2, 'Machinery', $3, 'Kurunegala', 'Kurunegala', 25) RETURNING id`,
      [user.rows[0].id, `DEMO-${m.phone}`, m.category]
    );
    const machine = await db.query(
      "INSERT INTO machinery (provider_id, name, category, active) VALUES ($1, $2, $3, true) RETURNING id",
      [provider.rows[0].id, m.name, m.category]
    );
    for (const [name, unit, rate] of m.services) {
      await db.query("INSERT INTO machinery_services (machine_id, name, unit, rate) VALUES ($1, $2, $3, $4)", [
        machine.rows[0].id,
        name,
        unit,
        rate,
      ]);
    }
    added += 1;
  }
  return added;
};

/**
 * Removes everything seedDemoMachines added (and any bookings made on those
 * machines), matched by the made-up phone numbers. Real providers are never
 * touched. Returns how many demo providers were removed.
 */
const removeDemoMachines = async (db) => {
  const phones = DEMO_MACHINES.map((m) => m.phone);
  const users = await db.query(`SELECT id FROM users WHERE phone IN (${phones.map((p) => `'${p}'`).join(",")})`);
  const userIds = users.rows.map((u) => u.id);
  if (userIds.length === 0) return 0;
  const list = userIds.join(",");
  const providers = `(SELECT id FROM service_providers WHERE user_id IN (${list}))`;
  const machines = `(SELECT id FROM machinery WHERE provider_id IN ${providers})`;
  const bookings = `(SELECT id FROM machinery_bookings WHERE machine_id IN ${machines})`;

  await db.query(`DELETE FROM machinery_messages WHERE booking_id IN ${bookings}`);
  await db.query(`DELETE FROM machinery_booking_items WHERE booking_id IN ${bookings}`);
  await db.query(`DELETE FROM machinery_bookings WHERE machine_id IN ${machines}`);
  await db.query(`DELETE FROM machinery_availability WHERE machine_id IN ${machines}`);
  await db.query(`DELETE FROM machinery_services WHERE machine_id IN ${machines}`);
  await db.query(`DELETE FROM machinery WHERE provider_id IN ${providers}`);
  await db.query(`DELETE FROM service_providers WHERE user_id IN (${list})`);
  await db.query(`DELETE FROM users WHERE id IN (${list})`);
  return userIds.length;
};

module.exports = { DEMO_MACHINES, seedDemoMachines, removeDemoMachines };

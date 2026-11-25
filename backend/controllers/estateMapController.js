const pool = require("../config/db");

/*
|--------------------------------------------------------------------------
| ESTATE MAP
|--------------------------------------------------------------------------
| The land owner's map of the estate: the real shape of the land and what
| grows on it. Saved as one document per owner (table estate_maps, see
| sql/025_estate_maps.sql). The table is created on first use, so no manual
| migration is needed.
*/

const KINDS = [
  "coconut", "king", "pepper", "banana", "cinnamon", "cocoa",
  "guinea", "mana", "mite", "whitefly",
];
const AGES = ["0-5", "6-15", "16-25", "26-40", "41-50", "51-60", "61+"];
const SEVERITIES = ["Low", "Medium", "High"];
const MAX_MARKS = 3000;
const MAX_CORNERS = 200;

let tableReady = false;
const ensureTable = async () => {
  if (tableReady) return;
  await pool.query(
    `CREATE TABLE IF NOT EXISTS estate_maps (
       user_id integer PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
       plan jsonb,
       marks jsonb NOT NULL DEFAULT '[]'::jsonb,
       updated_at timestamptz NOT NULL DEFAULT now()
     )`
  );
  tableReady = true;
};

const isNum = (v) => typeof v === "number" && Number.isFinite(v);
const inRange = (v, lo, hi) => isNum(v) && v >= lo && v <= hi;
const text = (v, max) => String(v ?? "").trim().slice(0, max);

// Returns { value } or { error } for the estate outline and details.
const cleanPlan = (plan) => {
  if (plan === null || plan === undefined) return { value: null };
  if (typeof plan !== "object" || Array.isArray(plan)) {
    return { error: "plan must be an object or null" };
  }
  if (!inRange(plan.acres, 0.1, 5000)) {
    return { error: "plan.acres must be a number from 0.1 to 5000" };
  }
  if (!inRange(plan.lat, -90, 90) || !inRange(plan.lng, -180, 180)) {
    return { error: "plan.lat and plan.lng must be real coordinates" };
  }
  const name = text(plan.name, 120);
  if (!name) return { error: "plan.name is required" };

  const clean = {
    name,
    acres: plan.acres,
    lat: plan.lat,
    lng: plan.lng,
    place: text(plan.place, 200),
  };

  if (plan.boundary !== undefined && plan.boundary !== null) {
    if (
      !Array.isArray(plan.boundary) ||
      plan.boundary.length < 3 ||
      plan.boundary.length > MAX_CORNERS
    ) {
      return { error: `plan.boundary needs 3 to ${MAX_CORNERS} corners` };
    }
    const corners = [];
    for (const c of plan.boundary) {
      if (!Array.isArray(c) || !inRange(c[0], -90, 90) || !inRange(c[1], -180, 180)) {
        return { error: "every plan.boundary corner must be [latitude, longitude]" };
      }
      corners.push([c[0], c[1]]);
    }
    clean.boundary = corners;
  }
  return { value: clean };
};

const cleanMarks = (marks) => {
  if (!Array.isArray(marks)) return { error: "marks must be a list" };
  if (marks.length > MAX_MARKS) {
    return { error: `An estate map can hold up to ${MAX_MARKS} marks` };
  }
  const seen = new Set();
  const out = [];
  for (const m of marks) {
    if (!m || typeof m !== "object") return { error: "every mark must be an object" };
    const id = text(m.id, 64);
    if (!id || seen.has(id)) return { error: "every mark needs its own id" };
    seen.add(id);
    if (!KINDS.includes(m.kind)) return { error: `Unknown plant kind: ${text(m.kind, 30)}` };
    if (!inRange(m.lat, -90, 90) || !inRange(m.lng, -180, 180)) {
      return { error: "every mark needs real coordinates" };
    }
    if (!Number.isInteger(m.count) || m.count < 1 || m.count > 100000) {
      return { error: "count must be a whole number from 1 to 100,000" };
    }
    const age = m.age ?? null;
    if (age !== null && !AGES.includes(age)) return { error: "Unknown age range" };
    const severity = m.severity ?? null;
    if (severity !== null && !SEVERITIES.includes(severity)) {
      return { error: "severity must be Low, Medium or High" };
    }
    const updated = new Date(m.updated);
    out.push({
      id,
      kind: m.kind,
      lat: m.lat,
      lng: m.lng,
      count: m.count,
      age,
      severity,
      note: text(m.note, 120),
      updated: Number.isNaN(updated.getTime()) ? new Date().toISOString() : updated.toISOString(),
      status: text(m.status, 40) || "Pending validation",
    });
  }
  return { value: out };
};

// GET /api/owner/estate-map
const getEstateMap = async (req, res) => {
  try {
    await ensureTable();
    const result = await pool.query(
      "SELECT plan, marks, updated_at FROM estate_maps WHERE user_id = $1",
      [req.user.id]
    );
    const row = result.rows[0];
    if (!row) return res.status(200).json({ plan: null, marks: [], updated_at: null });
    return res.status(200).json({
      plan: row.plan,
      marks: row.marks,
      updated_at: row.updated_at,
    });
  } catch (error) {
    console.error("Get estate map error:", error);
    return res.status(500).json({ message: "Server error", error: error.message });
  }
};

// PUT /api/owner/estate-map  { plan, marks }
const saveEstateMap = async (req, res) => {
  try {
    const plan = cleanPlan(req.body?.plan);
    if (plan.error) return res.status(400).json({ message: plan.error });
    const marks = cleanMarks(req.body?.marks ?? []);
    if (marks.error) return res.status(400).json({ message: marks.error });

    await ensureTable();
    const result = await pool.query(
      `INSERT INTO estate_maps (user_id, plan, marks, updated_at)
       VALUES ($1, $2::jsonb, $3::jsonb, now())
       ON CONFLICT (user_id) DO UPDATE
         SET plan = EXCLUDED.plan, marks = EXCLUDED.marks, updated_at = now()
       RETURNING updated_at`,
      [req.user.id, JSON.stringify(plan.value), JSON.stringify(marks.value)]
    );
    return res.status(200).json({
      plan: plan.value,
      marks: marks.value,
      updated_at: result.rows[0].updated_at,
    });
  } catch (error) {
    console.error("Save estate map error:", error);
    return res.status(500).json({ message: "Server error", error: error.message });
  }
};

module.exports = { getEstateMap, saveEstateMap, cleanPlan, cleanMarks };

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");
const { parseCoords } = require("../utils/geo");
const { validateProvider, normalizeNic } = require("../utils/providerValidation");
const {
  validateFertilizerSupplier,
  validateCdo,
} = require("../utils/fertilizerRoleValidation");
const {
  areasForDistrict,
  formatAreas,
  regionalOffices,
  districts,
} = require("../utils/cdoDistrictAreas");
const { storageInfo } = require("./healthController");

const ROLES = [
  "BUYER",
  "ESTATE_OWNER",
  "ESTATE_MANAGER",
  "SERVICE_PROVIDER",
  "WORKER",
  "FERTILIZER_SUPPLIER",
  "CDO",
];

// Chip labels in the app → stored role codes.
const ROLE_ALIASES = {
  SUPPLIER: "FERTILIZER_SUPPLIER",
  FERTILIZER_SUPPLIER: "FERTILIZER_SUPPLIER",
};

// "Estate Owner" (as shown in the app) -> "ESTATE_OWNER"
const normaliseRole = (role) => {
  const code = String(role || "").trim().toUpperCase().replace(/\s+/g, "_");
  return ROLE_ALIASES[code] || code;
};

const normalisePhone = (phone) => {
  const cleaned = String(phone || "").replace(/[\s()-]/g, "");
  const mobile = cleaned.match(/^(?:\+?94|0)?(7\d{8})$/);
  return mobile ? `0${mobile[1]}` : cleaned;
};

const publicUser = (user) => ({
  id: user.id,
  name: user.name,
  phone: user.phone,
  role: user.role,
  location: user.location,
  latitude: user.latitude ?? null,
  longitude: user.longitude ?? null,
});

const hasCoords = (body) =>
  body.latitude !== undefined || body.longitude !== undefined;

const createToken = (user) =>
  jwt.sign(
    { id: user.id, name: user.name, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );

/*
|--------------------------------------------------------------------------
| SIGN UP
|--------------------------------------------------------------------------
*/
const signup = async (req, res) => {
  let client;
  try {
    const { name, password, location } = req.body;
    const phone = normalisePhone(req.body.phone);
    const role = normaliseRole(req.body.role);

    if (!name || !phone || !password || !role) {
      return res.status(400).json({
        message: "Name, phone, password and role are required",
      });
    }

    if (!String(location || "").trim()) {
      return res.status(400).json({ message: "Location is required" });
    }

    // Picked on the map in the app; optional for API clients.
    const coords = parseCoords(req.body.latitude, req.body.longitude);
    if (hasCoords(req.body) && !coords) {
      return res.status(400).json({ message: "Invalid location coordinates" });
    }

    if (!ROLES.includes(role)) {
      return res.status(400).json({ message: "Unknown account type" });
    }

    if (String(password).length < 6) {
      return res.status(400).json({
        message: "Password must be at least 6 characters",
      });
    }

    const provider = req.body.service_provider;
    const fertilizerSupplier = req.body.fertilizer_supplier;
    const cdo = req.body.cdo;

    if (provider) {
      const fieldErrors = validateProvider(req.body, role, phone, coords);
      if (Object.keys(fieldErrors).length) {
        return res.status(400).json({
          message: Object.values(fieldErrors)[0],
          fieldErrors,
        });
      }
    }
    if (fertilizerSupplier || role === "FERTILIZER_SUPPLIER") {
      const fieldErrors = validateFertilizerSupplier(
        { ...req.body, fertilizer_supplier: fertilizerSupplier || {} },
        role,
        phone,
        coords
      );
      if (Object.keys(fieldErrors).length) {
        return res.status(400).json({
          message: Object.values(fieldErrors)[0],
          fieldErrors,
        });
      }
    }
    if (cdo || role === "CDO") {
      const fieldErrors = validateCdo(
        { ...req.body, cdo: cdo || {} },
        role,
        phone,
        coords
      );
      if (Object.keys(fieldErrors).length) {
        return res.status(400).json({
          message: Object.values(fieldErrors)[0],
          fieldErrors,
        });
      }
    }

    const existing = await pool.query(
      "SELECT id FROM users WHERE phone = $1",
      [phone]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({
        message: "This phone number is already registered",
      });
    }

    const passwordHash = await bcrypt.hash(String(password), 10);

    client = await pool.connect();
    await client.query("BEGIN");
    const result = await client.query(
      `INSERT INTO users
        (name, phone, password_hash, role, location, latitude, longitude)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        String(name).trim(),
        phone,
        passwordHash,
        role,
        String(location).trim(),
        coords ? coords.lat : null,
        coords ? coords.lng : null,
      ]
    );

    const user = result.rows[0];
    if (provider) {
      await client.query(
        `INSERT INTO service_providers
          (user_id, identity_number, email, category, machinery_type, district, address, radius_km)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [user.id, normalizeNic(provider.identity_number), (provider.email || "").trim() || null,
         provider.category, provider.machinery_type ?? null, provider.district, provider.address.trim(), provider.radius_km]
      );
    }
    if (role === "FERTILIZER_SUPPLIER" && fertilizerSupplier) {
      const radius = fertilizerSupplier.radius_km;
      const coverage =
        String(fertilizerSupplier.coverage_note || "").trim() ||
        `Delivers within ${radius} km of ${String(location).trim()}.`;
      await client.query(
        `INSERT INTO fertilizer_suppliers
          (user_id, shop_name, identity_number, email, district, radius_km,
           willing_far, shop_type, brands, coverage_note)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          user.id,
          String(fertilizerSupplier.shop_name).trim(),
          normalizeNic(fertilizerSupplier.identity_number),
          String(fertilizerSupplier.email || "").trim() || null,
          fertilizerSupplier.district,
          radius,
          fertilizerSupplier.willing_far === true,
          fertilizerSupplier.shop_type || "Physical shop",
          String(fertilizerSupplier.brands || "").trim(),
          coverage,
        ]
      );
    }
    if (role === "CDO" && cdo) {
      const district = cdo.assigned_district;
      const areas =
        String(cdo.assigned_divisional_areas || "").trim() ||
        formatAreas(district);
      await client.query(
        `INSERT INTO cdo_officers
          (user_id, identity_number, email, employee_id, designation,
           regional_office, assigned_district, assigned_divisional_areas,
           id_card_filename, employment_doc_filename)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          user.id,
          normalizeNic(cdo.identity_number),
          String(cdo.email).trim(),
          String(cdo.employee_id).trim(),
          String(cdo.designation || "Coconut Development Officer").trim(),
          cdo.regional_office,
          district,
          areas,
          String(cdo.id_card_filename || "").trim() || null,
          String(cdo.employment_doc_filename || "").trim() || null,
        ]
      );
    }
    const token = createToken(user);
    await client.query("COMMIT");

    if (role === "WORKER") {
      await pool.query(
        `INSERT INTO worker (user_id, worker_name, job_category, jobs)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (user_id) DO NOTHING`,
        [user.id, JSON.stringify(String(name).trim()), "[]", "[]"]
      );
    }

    const profiles = await loadRoleProfiles(user);
    return res.status(201).json({
      message: "Account created successfully",
      storage: storageInfo(),
      token,
      user: publicUser(user),
      ...profiles,
    });
  } catch (error) {
    if (client) await client.query("ROLLBACK");
    if (error.code === "23505") {
      return res.status(409).json({ message: "This phone number is already registered" });
    }
    if (
      error.code === "42P01" &&
      (req.body.service_provider ||
        req.body.fertilizer_supplier ||
        req.body.cdo)
    ) {
      return res.status(503).json({
        message:
          "Provider registration database setup is incomplete. Contact the project administrator.",
      });
    }
    console.error("Signup error:", error);

    return res.status(500).json({
      message: "Server error",
    });
  } finally {
    if (client) client.release();
  }
};

const loadRoleProfiles = async (user) => {
  const out = {};
  if (user.role === "FERTILIZER_SUPPLIER") {
    const result = await pool.query(
      "SELECT * FROM fertilizer_suppliers WHERE user_id = $1",
      [user.id]
    );
    if (result.rows[0]) out.fertilizer_supplier = publicSupplier(result.rows[0]);
  }
  if (user.role === "CDO") {
    const result = await pool.query(
      "SELECT * FROM cdo_officers WHERE user_id = $1",
      [user.id]
    );
    if (result.rows[0]) out.cdo = publicCdo(result.rows[0]);
  }
  return out;
};

const publicSupplier = (row) => ({
  shop_name: row.shop_name,
  identity_number: row.identity_number,
  email: row.email,
  district: row.district,
  radius_km: row.radius_km,
  willing_far: row.willing_far,
  shop_type: row.shop_type,
  brands: row.brands,
  coverage_note: row.coverage_note,
});

const publicCdo = (row) => ({
  identity_number: row.identity_number,
  email: row.email,
  employee_id: row.employee_id,
  designation: row.designation,
  regional_office: row.regional_office,
  assigned_district: row.assigned_district,
  assigned_divisional_areas: row.assigned_divisional_areas,
  id_card_filename: row.id_card_filename,
  employment_doc_filename: row.employment_doc_filename,
});

/*
|--------------------------------------------------------------------------
| LOG IN
|--------------------------------------------------------------------------
*/
const login = async (req, res) => {
  try {
    const phone = normalisePhone(req.body.phone);
    const { password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({
        message: "Phone and password are required",
      });
    }

    const result = await pool.query(
      "SELECT * FROM users WHERE phone IN ($1, $2, $3, $4)",
      /^07\d{8}$/.test(phone)
        ? [phone, `+94${phone.slice(1)}`, `94${phone.slice(1)}`, phone.slice(1)]
        : [phone, phone, phone, phone]
    );
    // Same message for unknown phone and wrong password, so the response
    // does not reveal which phone numbers are registered.
    let user;
    for (const candidate of result.rows) {
      if (await bcrypt.compare(String(password), candidate.password_hash)) {
        user = candidate;
        break;
      }
    }
    if (!user) {
      return res.status(401).json({
        message: "Incorrect phone number or password",
      });
    }

    const profiles = await loadRoleProfiles(user);
    return res.status(200).json({
      message: "Logged in successfully",
      token: createToken(user),
      user: publicUser(user),
      ...profiles,
    });
  } catch (error) {
    console.error("Login error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/*
|--------------------------------------------------------------------------
| CURRENT USER
|--------------------------------------------------------------------------
*/
const me = async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM users WHERE id = $1", [
      req.user.id,
    ]);

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Account not found" });
    }

    const user = result.rows[0];
    const profiles = await loadRoleProfiles(user);
    return res.status(200).json({ ...publicUser(user), ...profiles });
  } catch (error) {
    console.error("Get current user error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/*
|--------------------------------------------------------------------------
| SUPPLIER / CDO PROFILE
|--------------------------------------------------------------------------
*/
const getSupplierProfile = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM fertilizer_suppliers WHERE user_id = $1",
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Supplier profile not found" });
    }
    return res.status(200).json(publicSupplier(result.rows[0]));
  } catch (error) {
    console.error("Get supplier profile error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const updateSupplierProfile = async (req, res) => {
  try {
    if (req.user.role !== "FERTILIZER_SUPPLIER") {
      return res.status(403).json({ message: "Supplier accounts only" });
    }
    const agentName = String(req.body.agent_name || "").trim();
    const phone = req.body.phone != null ? normalisePhone(req.body.phone) : null;
    const willingFar = req.body.willing_far;
    const coverageNote = req.body.coverage_note;

    if (agentName) {
      await pool.query("UPDATE users SET name = $2 WHERE id = $1", [
        req.user.id,
        agentName,
      ]);
    }
    if (phone) {
      if (!/^07\d{8}$/.test(phone)) {
        return res
          .status(400)
          .json({ message: "Enter a valid Sri Lankan mobile number" });
      }
      await pool.query("UPDATE users SET phone = $2 WHERE id = $1", [
        req.user.id,
        phone,
      ]);
    }

    const result = await pool.query(
      `UPDATE fertilizer_suppliers
       SET willing_far = COALESCE($2, willing_far),
           coverage_note = COALESCE($3, coverage_note)
       WHERE user_id = $1
       RETURNING *`,
      [
        req.user.id,
        typeof willingFar === "boolean" ? willingFar : null,
        coverageNote != null ? String(coverageNote).trim() : null,
      ]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Supplier profile not found" });
    }
    const user = (
      await pool.query("SELECT * FROM users WHERE id = $1", [req.user.id])
    ).rows[0];
    return res.status(200).json({
      user: publicUser(user),
      fertilizer_supplier: publicSupplier(result.rows[0]),
    });
  } catch (error) {
    if (error.code === "23505") {
      return res
        .status(409)
        .json({ message: "This phone number is already registered" });
    }
    console.error("Update supplier profile error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const getCdoProfile = async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM cdo_officers WHERE user_id = $1",
      [req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ message: "CDO profile not found" });
    }
    return res.status(200).json(publicCdo(result.rows[0]));
  } catch (error) {
    console.error("Get CDO profile error:", error);
    return res.status(500).json({ message: "Server error" });
  }
};

const listCdoDistrictMeta = (_req, res) => {
  return res.status(200).json({
    districts,
    regional_offices: regionalOffices,
    areas_by_district: Object.fromEntries(
      districts.map((d) => [d, areasForDistrict(d)])
    ),
  });
};

/*
|--------------------------------------------------------------------------
| UPDATE CURRENT USER
|--------------------------------------------------------------------------
| Phone and role are fixed - phone is the login, role decides the screens.
*/
const updateMe = async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const location = String(req.body.location || "").trim();

    if (!name) {
      return res.status(400).json({ message: "Name is required" });
    }

    // Coordinates only change when new ones are sent.
    const coords = parseCoords(req.body.latitude, req.body.longitude);
    if (hasCoords(req.body) && !coords) {
      return res.status(400).json({ message: "Invalid location coordinates" });
    }

    const result = coords
      ? await pool.query(
          `UPDATE users
           SET name = $2, location = $3, latitude = $4, longitude = $5
           WHERE id = $1
           RETURNING *`,
          [req.user.id, name, location || null, coords.lat, coords.lng]
        )
      : await pool.query(
          `UPDATE users SET name = $2, location = $3
           WHERE id = $1
           RETURNING *`,
          [req.user.id, name, location || null]
        );

    if (result.rows.length === 0) {
      return res.status(404).json({ message: "Account not found" });
    }

    return res.status(200).json(publicUser(result.rows[0]));
  } catch (error) {
    console.error("Update current user error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

module.exports = {
  signup,
  login,
  me,
  updateMe,
  getSupplierProfile,
  updateSupplierProfile,
  getCdoProfile,
  listCdoDistrictMeta,
};

const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");
const { parseCoords } = require("../utils/geo");
const { validateProvider, normalizeNic } = require("../utils/providerValidation");
const { storageInfo } = require("./healthController");

const ROLES = ["BUYER", "ESTATE_OWNER", "ESTATE_MANAGER", "SERVICE_PROVIDER"];

// "Estate Owner" (as shown in the app) -> "ESTATE_OWNER"
const normaliseRole = (role) =>
  String(role || "").trim().toUpperCase().replace(/\s+/g, "_");

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
    if (provider) {
      const fieldErrors = validateProvider(req.body, role, phone, coords);
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
         provider.category, provider.machinery_type, provider.district, provider.address.trim(), provider.radius_km]
      );
    }
    const token = createToken(user);
    await client.query("COMMIT");

    return res.status(201).json({
      message: "Account created successfully",
      storage: storageInfo(),
      token,
      user: publicUser(user),
    });
  } catch (error) {
    if (client) await client.query("ROLLBACK");
    if (error.code === "23505") {
      return res.status(409).json({ message: "This phone number is already registered" });
    }
    if (error.code === "42P01" && req.body.service_provider) {
      return res.status(503).json({message: "Provider registration database setup is incomplete. Contact the project administrator."});
    }
    console.error("Signup error:", error);

    return res.status(500).json({
      message: "Server error",
    });
  } finally {
    if (client) client.release();
  }
};

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
      "SELECT * FROM users WHERE phone = $1",
      [phone]
    );
    const user = result.rows[0];

    // Same message for unknown phone and wrong password, so the response
    // does not reveal which phone numbers are registered.
    const ok = user && (await bcrypt.compare(String(password), user.password_hash));
    if (!ok) {
      return res.status(401).json({
        message: "Incorrect phone number or password",
      });
    }

    return res.status(200).json({
      message: "Logged in successfully",
      token: createToken(user),
      user: publicUser(user),
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

    return res.status(200).json(publicUser(result.rows[0]));
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

module.exports = { signup, login, me, updateMe };

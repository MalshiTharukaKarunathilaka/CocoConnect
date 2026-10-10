const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const pool = require("../config/db");

const ROLES = ["BUYER", "ESTATE_OWNER", "ESTATE_MANAGER", "SERVICE_PROVIDER"];

// "Estate Owner" (as shown in the app) -> "ESTATE_OWNER"
const normaliseRole = (role) =>
  String(role || "").trim().toUpperCase().replace(/\s+/g, "_");

const normalisePhone = (phone) => String(phone || "").replace(/[\s-]/g, "");

const publicUser = (user) => ({
  id: user.id,
  name: user.name,
  phone: user.phone,
  role: user.role,
  location: user.location,
});

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
  try {
    const { name, password, location } = req.body;
    const phone = normalisePhone(req.body.phone);
    const role = normaliseRole(req.body.role);

    if (!name || !phone || !password || !role) {
      return res.status(400).json({
        message: "Name, phone, password and role are required",
      });
    }

    if (!ROLES.includes(role)) {
      return res.status(400).json({ message: "Unknown account type" });
    }

    if (String(password).length < 6) {
      return res.status(400).json({
        message: "Password must be at least 6 characters",
      });
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

    const result = await pool.query(
      `INSERT INTO users (name, phone, password_hash, role, location)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [String(name).trim(), phone, passwordHash, role, location || null]
    );

    const user = result.rows[0];

    return res.status(201).json({
      message: "Account created successfully",
      token: createToken(user),
      user: publicUser(user),
    });
  } catch (error) {
    console.error("Signup error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
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

    const result = await pool.query(
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

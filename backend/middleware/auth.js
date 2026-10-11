const jwt = require("jsonwebtoken");
const pool = require("../config/db");

/*
|--------------------------------------------------------------------------
| REQUIRE LOGIN
|--------------------------------------------------------------------------
| Expects "Authorization: Bearer <token>" from /api/auth/login and puts
| { id, name, role } on req.user.
*/
const requireAuth = async (req, res, next) => {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");

  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ message: "Login required" });
  }

  let payload;
  try {
    payload = jwt.verify(token, process.env.JWT_SECRET);
  } catch (error) {
    return res.status(401).json({ message: "Session expired, please log in again" });
  }

  try {
    // Use the account's current role, not the one saved in the token at
    // login - it may have changed since (e.g. made an admin in Supabase).
    const result = await pool.query("SELECT name, role FROM users WHERE id = $1", [
      payload.id,
    ]);
    const user = result.rows[0];
    if (!user) {
      return res.status(401).json({ message: "Account not found, please log in again" });
    }
    req.user = { id: payload.id, name: user.name, role: user.role };
    return next();
  } catch (error) {
    console.error("Auth lookup error:", error);
    return res.status(500).json({ message: "Server error", error: error.message });
  }
};

const requireRole = (role) => (req, res, next) => {
  if (req.user?.role !== role) {
    return res.status(403).json({ message: "Not allowed for this account type" });
  }
  return next();
};

module.exports = { requireAuth, requireRole };

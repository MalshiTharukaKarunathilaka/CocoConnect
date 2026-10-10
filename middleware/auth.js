const jwt = require("jsonwebtoken");

/*
|--------------------------------------------------------------------------
| REQUIRE LOGIN
|--------------------------------------------------------------------------
| Expects "Authorization: Bearer <token>" from /api/auth/login and puts
| { id, name, role } on req.user.
*/
const requireAuth = (req, res, next) => {
  const header = req.headers.authorization || "";
  const [scheme, token] = header.split(" ");

  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({ message: "Login required" });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: payload.id, name: payload.name, role: payload.role };
    return next();
  } catch (error) {
    return res.status(401).json({ message: "Session expired, please log in again" });
  }
};

const requireRole = (role) => (req, res, next) => {
  if (req.user?.role !== role) {
    return res.status(403).json({ message: "Not allowed for this account type" });
  }
  return next();
};

module.exports = { requireAuth, requireRole };

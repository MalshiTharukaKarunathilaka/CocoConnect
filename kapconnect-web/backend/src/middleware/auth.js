const jwt = require('jsonwebtoken');
const config = require('../config');
const { ApiError } = require('../errors');

function signToken(user) {
  return jwt.sign(
    {
      sub: user.id,
      role: user.role,
      phone: user.phone,
      name: user.name,
    },
    config.jwtSecret,
    { expiresIn: config.jwtExpiresIn }
  );
}

function authRequired(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return next(new ApiError(401, 'Unauthorized'));
  try {
    const payload = jwt.verify(token, config.jwtSecret);
    req.user = {
      id: payload.sub,
      role: payload.role,
      phone: payload.phone,
      name: payload.name,
      isAdmin: payload.role === 'ADMIN',
    };
    next();
  } catch {
    next(new ApiError(401, 'Unauthorized'));
  }
}

function requireAdmin(req, res, next) {
  if (!req.user?.isAdmin) return next(new ApiError(403, 'Admin only'));
  next();
}

module.exports = { signToken, authRequired, requireAdmin };

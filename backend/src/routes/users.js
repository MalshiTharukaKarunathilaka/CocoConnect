const { z } = require('zod');
const { prisma } = require('../db');
const { ApiError, asyncHandler } = require('../errors');
const { authRequired } = require('../middleware/auth');
const { toUser } = require('../services/users');

const router = require('express').Router();

router.get(
  '/me',
  authRequired,
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user) throw new ApiError(404, 'User not found');
    res.json(toUser(user));
  })
);

module.exports = router;

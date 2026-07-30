const { z } = require('zod');
const { prisma } = require('../db');
const { ApiError, asyncHandler } = require('../errors');
const { authRequired } = require('../middleware/auth');

const router = require('express').Router();

router.get(
  '/',
  authRequired,
  asyncHandler(async (req, res) => {
    const rows = await prisma.notification.findMany({
      where: { userId: req.user.id },
      orderBy: { createdAt: 'desc' },
    });
    res.json(rows);
  })
);

router.patch(
  '/:id/read',
  authRequired,
  asyncHandler(async (req, res) => {
    const n = await prisma.notification.findUnique({ where: { id: req.params.id } });
    if (!n) throw new ApiError(404, 'Notification not found');
    if (n.userId !== req.user.id) throw new ApiError(403, 'Not your notification');
    res.json(await prisma.notification.update({ where: { id: n.id }, data: { readFlag: true } }));
  })
);

router.put(
  '/fcm-token',
  authRequired,
  asyncHandler(async (req, res) => {
    const token = z.object({ token: z.string().min(1) }).parse(req.body).token;
    await prisma.user.update({ where: { id: req.user.id }, data: { fcmToken: token } });
    res.json({ ok: true, message: 'FCM token saved' });
  })
);

module.exports = router;

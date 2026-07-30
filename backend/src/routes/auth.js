const { z } = require('zod');
const { prisma } = require('../db');
const config = require('../config');
const { ApiError, asyncHandler } = require('../errors');
const { signToken } = require('../middleware/auth');
const { toUser } = require('../services/users');

const router = require('express').Router();

const registerSchema = z.object({
  phone: z.string().min(9).max(15),
  name: z.string().min(2).max(80),
  role: z.enum(['BUYER', 'ESTATE']),
  district: z.string().optional(),
  estateName: z.string().optional(),
});

async function createOtp(phone, userId) {
  const expiresAt = new Date(Date.now() + config.otpExpireMinutes * 60 * 1000);
  await prisma.otpCode.create({
    data: { phone, userId, code: config.otpDemoCode, expiresAt },
  });
  console.log(`[KapConnect OTP] ${phone} => ${config.otpDemoCode}`);
}

router.post(
  '/register',
  asyncHandler(async (req, res) => {
    const body = registerSchema.parse(req.body);
    const exists = await prisma.user.findUnique({ where: { phone: body.phone } });
    if (exists) throw new ApiError(400, 'Phone already registered — request OTP');
    const user = await prisma.user.create({
      data: {
        phone: body.phone,
        name: body.name,
        role: body.role,
        district: body.district,
        estateName: body.estateName,
        status: body.role === 'ESTATE' ? 'PENDING' : 'VERIFIED',
      },
    });
    await createOtp(user.phone, user.id);
    res.json({
      message: 'Registered. Verify OTP to login (demo code in config).',
      userId: user.id,
      phone: user.phone,
      role: user.role,
    });
  })
);

router.post(
  '/otp/send',
  asyncHandler(async (req, res) => {
    const phone = z.object({ phone: z.string().min(1) }).parse(req.body).phone;
    const user = await prisma.user.findUnique({ where: { phone } });
    if (!user) throw new ApiError(400, 'No account — register first');
    if (user.status === 'SUSPENDED') throw new ApiError(401, 'Account suspended');
    await createOtp(user.phone, user.id);
    res.json({ message: 'OTP sent (demo — check server logs / demo-code)', phone });
  })
);

router.post(
  '/otp/verify',
  asyncHandler(async (req, res) => {
    const body = z.object({ phone: z.string().min(1), code: z.string().min(1) }).parse(req.body);
    const latest = await prisma.otpCode.findFirst({
      where: { phone: body.phone, used: false },
      orderBy: { createdAt: 'desc' },
    });
    const ok =
      body.code === config.otpDemoCode ||
      (latest && latest.code === body.code && latest.expiresAt > new Date());
    if (!ok) throw new ApiError(401, 'Invalid OTP');
    if (latest) {
      await prisma.otpCode.update({ where: { id: latest.id }, data: { used: true } });
    }
    const user = await prisma.user.findUnique({ where: { phone: body.phone } });
    if (!user) throw new ApiError(401, 'User not found');
    if (user.status === 'SUSPENDED') throw new ApiError(401, 'Account suspended');
    res.json({ accessToken: signToken(user), user: toUser(user) });
  })
);

module.exports = router;

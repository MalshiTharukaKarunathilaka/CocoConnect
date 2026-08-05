const { z } = require('zod');
const fs = require('fs');
const path = require('path');
const { prisma } = require('../db');
const { ApiError, asyncHandler } = require('../errors');
const { authRequired, requireAdmin } = require('../middleware/auth');
const { toUser, notifyUser } = require('../services/users');

const router = require('express').Router();
const settingsPath = path.join(__dirname, '..', '..', 'data', 'settings.json');

const defaultSettings = {
  fee: 2.5,
  radius: 3,
  language: 'en',
  paymentHold: 4,
  support: 'support@kapconnect.lk',
};

function readSettings() {
  try {
    if (fs.existsSync(settingsPath)) {
      return { ...defaultSettings, ...JSON.parse(fs.readFileSync(settingsPath, 'utf8')) };
    }
  } catch {}
  return { ...defaultSettings };
}

function writeSettings(next) {
  const dir = path.dirname(settingsPath);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(settingsPath, JSON.stringify(next, null, 2));
}

router.use(authRequired, requireAdmin);

router.get(
  '/dashboard',
  asyncHandler(async (_req, res) => {
    const [
      users,
      openBuyRequests,
      activeListings,
      dealsInProgress,
      openDisputes,
      pendingVerify,
      completed,
      recentOrders,
      recentDisputes,
    ] = await Promise.all([
      prisma.user.count({ where: { role: { not: 'ADMIN' } } }),
      prisma.buyRequest.count({ where: { status: 'OPEN' } }),
      prisma.sellListing.count({ where: { status: 'ACTIVE' } }),
      prisma.tradeOrder.count({
        where: { status: { in: ['NEGOTIATING', 'ACCEPTED', 'PAYMENT_PENDING'] } },
      }),
      prisma.dispute.count({ where: { status: 'OPEN' } }),
      prisma.user.count({ where: { status: 'PENDING' } }),
      prisma.tradeOrder.findMany({ where: { status: 'COMPLETED' } }),
      prisma.tradeOrder.findMany({ orderBy: { updatedAt: 'desc' }, take: 5 }),
      prisma.dispute.findMany({ where: { status: 'OPEN' }, orderBy: { createdAt: 'desc' }, take: 5 }),
    ]);
    const completedGmv = completed.reduce((sum, o) => sum + o.quantity * o.unitPrice, 0);
    res.json({
      users,
      openBuyRequests,
      activeListings,
      dealsInProgress,
      openDisputes,
      pendingVerify,
      completedGmv,
      recentOrders,
      recentDisputes,
    });
  })
);

router.get(
  '/users',
  asyncHandler(async (_req, res) => {
    const rows = await prisma.user.findMany({
      where: { role: { not: 'ADMIN' } },
      orderBy: { createdAt: 'desc' },
    });
    res.json(rows.map(toUser));
  })
);

router.patch(
  '/users/:id/status',
  asyncHandler(async (req, res) => {
    const body = z.object({ status: z.enum(['PENDING', 'VERIFIED', 'SUSPENDED']) }).parse(req.body);
    const user = await prisma.user.findUnique({ where: { id: req.params.id } });
    if (!user) throw new ApiError(404, 'User not found');
    const saved = await prisma.user.update({
      where: { id: user.id },
      data: { status: body.status },
    });
    await notifyUser(
      user.id,
      `Account ${body.status.toLowerCase()}`,
      `Admin set your KapConnect status to ${body.status}`
    );
    res.json(toUser(saved));
  })
);

router.get(
  '/orders',
  asyncHandler(async (_req, res) => {
    res.json(await prisma.tradeOrder.findMany({ orderBy: { updatedAt: 'desc' } }));
  })
);

router.get(
  '/buy-requests',
  asyncHandler(async (_req, res) => {
    res.json(await prisma.buyRequest.findMany({ orderBy: { createdAt: 'desc' } }));
  })
);

router.get(
  '/listings',
  asyncHandler(async (_req, res) => {
    res.json(await prisma.sellListing.findMany({ orderBy: { createdAt: 'desc' } }));
  })
);

router.get(
  '/disputes',
  asyncHandler(async (_req, res) => {
    res.json(await prisma.dispute.findMany({ orderBy: { createdAt: 'desc' } }));
  })
);

router.patch(
  '/disputes/:id/resolve',
  asyncHandler(async (req, res) => {
    const body = z
      .object({ action: z.enum(['refund', 'warn', 'close']).optional() })
      .parse(req.body || {});
    const dispute = await prisma.dispute.findUnique({ where: { id: req.params.id } });
    if (!dispute) throw new ApiError(404, 'Dispute not found');
    const saved = await prisma.dispute.update({
      where: { id: dispute.id },
      data: { status: 'RESOLVED' },
    });
    if (body.action === 'refund') {
      await prisma.tradeOrder.update({
        where: { id: dispute.orderId },
        data: { status: 'COMPLETED' },
      });
    }
    res.json(saved);
  })
);

router.patch(
  '/listings/:id/hide',
  asyncHandler(async (req, res) => {
    const listing = await prisma.sellListing.findUnique({ where: { id: req.params.id } });
    if (!listing) throw new ApiError(404, 'Listing not found');
    res.json(
      await prisma.sellListing.update({
        where: { id: listing.id },
        data: { status: 'HIDDEN' },
      })
    );
  })
);

router.patch(
  '/listings/:id/verify',
  asyncHandler(async (req, res) => {
    const body = z.object({ verified: z.boolean() }).parse(req.body);
    const listing = await prisma.sellListing.findUnique({ where: { id: req.params.id } });
    if (!listing) throw new ApiError(404, 'Listing not found');
    const saved = await prisma.sellListing.update({
      where: { id: listing.id },
      data: { verified: body.verified },
    });
    await notifyUser(
      listing.estateId,
      body.verified ? 'Listing verified' : 'Verification removed',
      `Admin ${body.verified ? 'verified' : 'unverified'} your listing`
    );
    res.json(saved);
  })
);

router.patch(
  '/buy-requests/:id/hide',
  asyncHandler(async (req, res) => {
    const request = await prisma.buyRequest.findUnique({ where: { id: req.params.id } });
    if (!request) throw new ApiError(404, 'Request not found');
    res.json(
      await prisma.buyRequest.update({
        where: { id: request.id },
        data: { status: 'HIDDEN' },
      })
    );
  })
);

router.post(
  '/orders/:id/disputes',
  asyncHandler(async (req, res) => {
    const body = z
      .object({
        title: z.string().min(1),
        body: z.string().min(1),
        severity: z.string().optional(),
      })
      .parse(req.body);
    const order = await prisma.tradeOrder.findUnique({ where: { id: req.params.id } });
    if (!order) throw new ApiError(404, 'Order not found');
    const dispute = await prisma.dispute.create({
      data: {
        orderId: order.id,
        title: body.title,
        body: body.body,
        severity: body.severity || 'medium',
      },
    });
    await prisma.tradeOrder.update({
      where: { id: order.id },
      data: { status: 'DISPUTED' },
    });
    await notifyUser(order.buyerId, 'Dispute opened', `Order ${order.code}: ${body.title}`);
    await notifyUser(order.estateId, 'Dispute opened', `Order ${order.code}: ${body.title}`);
    res.json(dispute);
  })
);

router.get(
  '/regions',
  asyncHandler(async (_req, res) => {
    const users = await prisma.user.findMany({ where: { role: { not: 'ADMIN' } } });
    const districts = [...new Set(users.map((u) => u.district).filter(Boolean))];
    if (!districts.length) districts.push('Kurunegala', 'Colombo', 'Gampaha', 'Puttalam');
    const bands = {
      Kurunegala: 'Rs. 110 – 135',
      Colombo: 'Rs. 120 – 145',
      Gampaha: 'Rs. 115 – 140',
      Puttalam: 'Rs. 105 – 130',
    };
    const regions = await Promise.all(
      districts.map(async (name) => ({
        name,
        buyers: users.filter((u) => u.district === name && u.role === 'BUYER').length,
        estates: users.filter((u) => u.district === name && u.role === 'ESTATE').length,
        radius: readSettings().radius,
        band: bands[name] || 'Rs. 110 – 140',
      }))
    );
    res.json(regions);
  })
);

router.get(
  '/reports',
  asyncHandler(async (_req, res) => {
    const [orders, disputes, users] = await Promise.all([
      prisma.tradeOrder.findMany(),
      prisma.dispute.findMany(),
      prisma.user.findMany({ where: { role: { not: 'ADMIN' } } }),
    ]);
    const completed = orders.filter((o) => o.status === 'COMPLETED');
    const avgDealPrice = completed.length
      ? Math.round(completed.reduce((s, o) => s + o.unitPrice, 0) / completed.length)
      : 0;
    const estates = users.filter((u) => u.role === 'ESTATE');
    const verifiedEstates = estates.filter((u) => u.status === 'VERIFIED').length;
    res.json({
      avgDealPrice,
      totalOrders: orders.length,
      completedOrders: completed.length,
      openDisputes: disputes.filter((d) => d.status === 'OPEN').length,
      verifiedEstates,
      totalEstates: estates.length,
      completedGmv: completed.reduce((s, o) => s + o.quantity * o.unitPrice, 0),
    });
  })
);

router.get(
  '/settings',
  asyncHandler(async (_req, res) => {
    res.json(readSettings());
  })
);

router.put(
  '/settings',
  asyncHandler(async (req, res) => {
    const body = z
      .object({
        fee: z.number().min(0).max(100),
        radius: z.number().min(1).max(100),
        language: z.enum(['en', 'si', 'ta']),
        paymentHold: z.number().min(0).max(72),
        support: z.string().min(3),
      })
      .parse(req.body);
    writeSettings(body);
    res.json(body);
  })
);

module.exports = router;

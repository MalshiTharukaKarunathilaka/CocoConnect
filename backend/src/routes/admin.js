const { z } = require('zod');
const { prisma } = require('../db');
const { ApiError, asyncHandler } = require('../errors');
const { authRequired, requireAdmin } = require('../middleware/auth');
const { toUser, notifyUser } = require('../services/users');

const router = require('express').Router();

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
  '/disputes',
  asyncHandler(async (_req, res) => {
    res.json(await prisma.dispute.findMany({ orderBy: { createdAt: 'desc' } }));
  })
);

router.patch(
  '/disputes/:id/resolve',
  asyncHandler(async (req, res) => {
    const dispute = await prisma.dispute.findUnique({ where: { id: req.params.id } });
    if (!dispute) throw new ApiError(404, 'Dispute not found');
    const saved = await prisma.dispute.update({
      where: { id: dispute.id },
      data: { status: 'RESOLVED' },
    });
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

module.exports = router;

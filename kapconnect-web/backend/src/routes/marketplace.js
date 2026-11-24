const { z } = require('zod');
const { prisma } = require('../db');
const { ApiError, asyncHandler } = require('../errors');
const { authRequired } = require('../middleware/auth');

const router = require('express').Router();

const buySchema = z.object({
  category: z.enum(['RAW', 'DEHUSKED', 'HUSKS']).optional(),
  quantity: z.number().int().min(1),
  bidPrice: z.number().min(1),
  needDate: z.string().min(1),
  location: z.string().optional(),
  district: z.string().optional(),
});

const listingSchema = z.object({
  category: z.enum(['RAW', 'DEHUSKED', 'HUSKS']).optional(),
  quantity: z.number().int().min(1),
  offerPrice: z.number().min(1),
  availableAt: z.string().min(1),
  location: z.string().optional(),
  district: z.string().optional(),
});

router.post(
  '/buy-requests',
  authRequired,
  asyncHandler(async (req, res) => {
    if (!['BUYER', 'ADMIN'].includes(req.user.role)) {
      throw new ApiError(403, 'Only buyers can create buy requests');
    }
    const body = buySchema.parse(req.body);
    const needDate = new Date(body.needDate);
    if (Number.isNaN(needDate.getTime())) {
      throw new ApiError(400, 'Please choose a valid needed date');
    }
    if (!body.quantity || body.quantity < 1) {
      throw new ApiError(400, 'Quantity must be at least 1');
    }
    if (!body.bidPrice || body.bidPrice < 1) {
      throw new ApiError(400, 'Bid price must be at least Rs. 1');
    }
    const created = await prisma.buyRequest.create({
      data: {
        buyerId: req.user.id,
        category: body.category || 'RAW',
        quantity: body.quantity,
        bidPrice: body.bidPrice,
        needDate,
        location: body.location || body.district || 'Sri Lanka',
        district: body.district || 'Kurunegala',
      },
    });
    res.json(created);
  })
);

router.get(
  '/buy-requests',
  authRequired,
  asyncHandler(async (req, res) => {
    const district = req.query.district;
    const where = {
      status: { in: ['OPEN', 'MATCHED'] },
      ...(district ? { district: { equals: String(district) } } : {}),
    };
    const rows = await prisma.buyRequest.findMany({ where, orderBy: { createdAt: 'desc' } });
    res.json(rows);
  })
);

router.post(
  '/listings',
  authRequired,
  asyncHandler(async (req, res) => {
    if (!['ESTATE', 'ADMIN'].includes(req.user.role)) {
      throw new ApiError(403, 'Only estate owners can create listings');
    }
    const body = listingSchema.parse(req.body);
    const availableAt = new Date(body.availableAt);
    if (Number.isNaN(availableAt.getTime())) {
      throw new ApiError(400, 'Please choose a valid available date');
    }
    const created = await prisma.sellListing.create({
      data: {
        estateId: req.user.id,
        category: body.category || 'RAW',
        quantity: body.quantity,
        offerPrice: body.offerPrice,
        availableAt,
        location: body.location || body.district || 'Sri Lanka',
        district: body.district || 'Kurunegala',
      },
    });
    res.json(created);
  })
);

router.get(
  '/listings',
  authRequired,
  asyncHandler(async (req, res) => {
    const district = req.query.district;
    const where = {
      status: 'ACTIVE',
      ...(district ? { district: { equals: String(district) } } : {}),
    };
    const rows = await prisma.sellListing.findMany({ where, orderBy: { createdAt: 'desc' } });
    res.json(rows);
  })
);

module.exports = router;

const { randomUUID } = require('crypto');
const { z } = require('zod');
const { prisma } = require('../db');
const { ApiError, asyncHandler } = require('../errors');
const { authRequired } = require('../middleware/auth');
const { notifyUser } = require('../services/users');

const router = require('express').Router();

async function requireMember(user, orderId) {
  const order = await prisma.tradeOrder.findUnique({ where: { id: orderId } });
  if (!order) throw new ApiError(404, 'Order not found');
  if (!user.isAdmin && order.buyerId !== user.id && order.estateId !== user.id) {
    throw new ApiError(403, 'Not a party on this order');
  }
  return order;
}

router.post(
  '/',
  authRequired,
  asyncHandler(async (req, res) => {
    const body = z
      .object({
        listingId: z.string().nullable().optional(),
        requestId: z.string().nullable().optional(),
        category: z.enum(['RAW', 'DEHUSKED', 'HUSKS']).optional(),
        quantity: z.number().int().min(1),
        unitPrice: z.number().min(1),
        counterpartyId: z.string().min(1),
        firstMessage: z.string().optional(),
      })
      .parse(req.body);

    let buyerId = req.user.id;
    let estateId = body.counterpartyId;
    if (req.user.role === 'ESTATE') {
      buyerId = body.counterpartyId;
      estateId = req.user.id;
    } else if (!['BUYER', 'ADMIN'].includes(req.user.role)) {
      throw new ApiError(403, 'Only buyer or estate can start negotiation');
    }

    const order = await prisma.tradeOrder.create({
      data: {
        code: `CR-${randomUUID().slice(0, 4).toUpperCase()}`,
        buyerId,
        estateId,
        listingId: body.listingId || null,
        requestId: body.requestId || null,
        category: body.category || 'RAW',
        quantity: body.quantity,
        unitPrice: body.unitPrice,
      },
    });

    if (body.firstMessage?.trim()) {
      await prisma.message.create({
        data: {
          orderId: order.id,
          senderId: req.user.id,
          type: 'TEXT',
          text: body.firstMessage,
        },
      });
    }

    await notifyUser(buyerId, 'Negotiation started', `Order ${order.code} opened`);
    await notifyUser(estateId, 'Negotiation started', `Order ${order.code} opened`);
    const messages = await prisma.message.findMany({
      where: { orderId: order.id },
      orderBy: { createdAt: 'asc' },
    });
    res.json({ order, messages });
  })
);

router.get(
  '/',
  authRequired,
  asyncHandler(async (req, res) => {
    let where = {};
    if (req.user.role === 'BUYER') where = { buyerId: req.user.id };
    else if (req.user.role === 'ESTATE') where = { estateId: req.user.id };
    const rows = await prisma.tradeOrder.findMany({
      where,
      orderBy: { updatedAt: 'desc' },
    });
    res.json(rows);
  })
);

router.get(
  '/:id',
  authRequired,
  asyncHandler(async (req, res) => {
    const order = await requireMember(req.user, req.params.id);
    const messages = await prisma.message.findMany({
      where: { orderId: order.id },
      orderBy: { createdAt: 'asc' },
    });
    res.json({ order, messages });
  })
);

router.post(
  '/:id/messages',
  authRequired,
  asyncHandler(async (req, res) => {
    const order = await requireMember(req.user, req.params.id);
    if (order.status !== 'NEGOTIATING') {
      throw new ApiError(400, 'Chat locked — order not negotiating');
    }
    const body = z
      .object({
        type: z.enum(['TEXT', 'OFFER']).optional(),
        text: z.string().optional(),
        offerPrice: z.number().optional(),
      })
      .parse(req.body);
    const type = body.type || (body.offerPrice != null ? 'OFFER' : 'TEXT');
    if (type === 'TEXT' && !body.text?.trim()) throw new ApiError(400, 'text required');
    if (type === 'OFFER' && body.offerPrice == null) throw new ApiError(400, 'offerPrice required');

    const msg = await prisma.message.create({
      data: {
        orderId: order.id,
        senderId: req.user.id,
        type,
        text: body.text,
        offerPrice: body.offerPrice,
      },
    });
    if (type === 'OFFER') {
      await prisma.tradeOrder.update({
        where: { id: order.id },
        data: { unitPrice: body.offerPrice },
      });
    }
    res.json(msg);
  })
);

router.patch(
  '/:id/status',
  authRequired,
  asyncHandler(async (req, res) => {
    const order = await requireMember(req.user, req.params.id);
    const body = z
      .object({
        status: z.enum([
          'NEGOTIATING',
          'ACCEPTED',
          'PAYMENT_PENDING',
          'COMPLETED',
          'REJECTED',
          'DISPUTED',
        ]),
      })
      .parse(req.body);
    const saved = await prisma.tradeOrder.update({
      where: { id: order.id },
      data: { status: body.status },
    });
    await notifyUser(order.buyerId, 'Order updated', `${order.code} is now ${body.status}`);
    await notifyUser(order.estateId, 'Order updated', `${order.code} is now ${body.status}`);
    res.json(saved);
  })
);

router.post(
  '/:id/disputes',
  authRequired,
  asyncHandler(async (req, res) => {
    const order = await requireMember(req.user, req.params.id);
    const body = z
      .object({
        title: z.string().min(1),
        body: z.string().min(1),
        severity: z.string().optional(),
      })
      .parse(req.body);
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

module.exports = router;

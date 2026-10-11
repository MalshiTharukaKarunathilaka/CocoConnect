const express = require("express");

const {
  getChats,
  getChat,
  sendChatMessage,
  acceptOffer,
  rejectOffer,
  acceptListing,
  closeChat,
} = require("../controllers/chatController");
const { getNotifications } = require("../controllers/notificationController");
const { getActivity } = require("../controllers/activityController");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

router.use(requireAuth);

/**
 * @swagger
 * /api/chats:
 *   get:
 *     summary: My negotiation chats (buyer or estate owner), newest activity first
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Chats with counterpart, last message, unread_count and offer_waiting
 */
router.get("/chats", getChats);

/**
 * @swagger
 * /api/chats/{id}:
 *   get:
 *     summary: One chat with its messages and offer statuses; marks it read
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: The chat
 *       404:
 *         description: Not found, or not my chat
 */
router.get("/chats/:id", getChat);

/**
 * @swagger
 * /api/chats/{id}/messages:
 *   post:
 *     summary: Send a message and/or a price offer (replaces any pending offer)
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               message: { type: string, example: "Can you do 128 for the lot?" }
 *               offerPricePerUnit: { type: number, example: 128 }
 *     responses:
 *       201:
 *         description: Sent
 */
router.post("/chats/:id/messages", sendChatMessage);

/**
 * @swagger
 * /api/chats/{id}/offers/{messageId}/accept:
 *   post:
 *     summary: Accept the other side's pending offer - creates the order
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: messageId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       201:
 *         description: Deal accepted
 *       403:
 *         description: It is your own offer
 *       409:
 *         description: Already answered, replaced, or chat closed
 */
router.post("/chats/:id/offers/:messageId/accept", acceptOffer);

/**
 * @swagger
 * /api/chats/{id}/offers/{messageId}/reject:
 *   post:
 *     summary: Reject the other side's pending offer (the chat stays open)
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *       - in: path
 *         name: messageId
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Offer rejected
 */
router.post("/chats/:id/offers/:messageId/reject", rejectOffer);

/**
 * @swagger
 * /api/chats/{id}/accept-listing:
 *   post:
 *     summary: Buyer accepts the listed price (only before any price was offered)
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       201:
 *         description: Deal accepted at the listed price
 */
router.post("/chats/:id/accept-listing", acceptListing);

/**
 * @swagger
 * /api/chats/{id}/close:
 *   post:
 *     summary: End the negotiation without a deal
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Closed
 */
router.post("/chats/:id/close", closeChat);

/**
 * @swagger
 * /api/notifications:
 *   get:
 *     summary: Offers waiting for me and upcoming deliveries (buyer or estate owner)
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Items with key, type (OFFER / SELL_OFFER / DELIVERY), title, body, at
 */
router.get("/notifications", getNotifications);

/**
 * @swagger
 * /api/activity:
 *   get:
 *     summary: Orders tab - pending offers, open negotiations, deals and transactions
 *     tags: [Chats]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: "{ pending, negotiations, deals, transactions } for the logged-in user"
 */
router.get("/activity", getActivity);

module.exports = router;

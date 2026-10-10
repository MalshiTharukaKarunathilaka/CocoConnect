const express = require("express");

const {
  getEstate,
  updateEstate,
  getSummary,
  getMyListings,
  createListing,
  getBuyerRequests,
  createSellRequest,
  getMySellRequests,
  getMyNegotiations,
  getNegotiation,
  sendMessage,
  declineNegotiation,
  getMyOrders,
} = require("../controllers/ownerController");
const { requireAuth, requireRole } = require("../middleware/auth");

const router = express.Router();

// Every route here needs a logged-in estate owner.
router.use(requireAuth, requireRole("ESTATE_OWNER"));

/**
 * @swagger
 * /api/owner/estate:
 *   get:
 *     summary: My estate (created on first use)
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: The estate linked to this login
 *   patch:
 *     summary: Rename my estate or change its location
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [estateName]
 *             properties:
 *               estateName: { type: string, example: "Green Valley Estate" }
 *               location: { type: string, example: "Kurunegala" }
 *               totalLandArea: { type: string, example: "25 acres" }
 *               primaryCrop: { type: string, example: "Coconut" }
 *               yearEstablished: { type: integer, example: 2015 }
 *     responses:
 *       200:
 *         description: Updated estate
 */
router.get("/estate", getEstate);
router.patch("/estate", updateEstate);

/**
 * @swagger
 * /api/owner/summary:
 *   get:
 *     summary: Estate details and profile counts
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Estate plus active listings, open chats, offers waiting and orders
 */
router.get("/summary", getSummary);

/**
 * @swagger
 * /api/owner/listings:
 *   get:
 *     summary: My listings
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Listings for my estate
 *   post:
 *     summary: List a harvest for sale
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [productType, quantity, availableDate, offerPricePerUnit]
 *             properties:
 *               productType: { type: string, example: "RAW_COCONUT" }
 *               quantity: { type: integer, example: 1200 }
 *               availableDate: { type: string, format: date, example: "2026-12-01" }
 *               offerPricePerUnit: { type: number, example: 130 }
 *     responses:
 *       201:
 *         description: Listing created
 */
router.get("/listings", getMyListings);
router.post("/listings", createListing);

/**
 * @swagger
 * /api/owner/buyer-requests:
 *   get:
 *     summary: Open buyer requests, with my offer on each if I sent one
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [RAW_COCONUT, HUSKED_COCONUT, DEHUSKED_COCONUT]
 *     responses:
 *       200:
 *         description: Pending buyer requests, highest bid first
 */
router.get("/buyer-requests", getBuyerRequests);

/**
 * @swagger
 * /api/owner/sell-requests:
 *   get:
 *     summary: Offers I have sent to buyers
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: My offers with the buyer request they answer
 *   post:
 *     summary: Send an offer for a buyer request
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [buyerRequestId, quantity, sellerPricePerUnit]
 *             properties:
 *               buyerRequestId: { type: integer, example: 1 }
 *               quantity: { type: integer, example: 1200 }
 *               sellerPricePerUnit: { type: number, example: 128 }
 *               availableDate: { type: string, format: date, example: "2026-12-01" }
 *     responses:
 *       201:
 *         description: Offer sent
 *       409:
 *         description: Already offered, or request closed
 */
router.get("/sell-requests", getMySellRequests);
router.post("/sell-requests", createSellRequest);

/**
 * @swagger
 * /api/owner/negotiations:
 *   get:
 *     summary: Buyer chats on my listings
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Negotiations, newest first
 */
router.get("/negotiations", getMyNegotiations);

/**
 * @swagger
 * /api/owner/negotiations/{id}:
 *   get:
 *     summary: One chat with its listing, buyer and messages
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Negotiation details
 */
router.get("/negotiations/:id", getNegotiation);

/**
 * @swagger
 * /api/owner/negotiations/{id}/messages:
 *   post:
 *     summary: Reply to a buyer and/or send a counter-offer
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               message: { type: string, example: "Best I can do is Rs. 125" }
 *               offerPricePerUnit: { type: number, example: 125 }
 *     responses:
 *       201:
 *         description: Message saved
 */
router.post("/negotiations/:id/messages", sendMessage);

/**
 * @swagger
 * /api/owner/negotiations/{id}/decline:
 *   post:
 *     summary: Decline and close a negotiation
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Negotiation declined
 */
router.post("/negotiations/:id/decline", declineNegotiation);

/**
 * @swagger
 * /api/owner/orders:
 *   get:
 *     summary: Orders for my estate
 *     tags: [Estate Owner]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Orders from chats and from accepted offers
 */
router.get("/orders", getMyOrders);

module.exports = router;

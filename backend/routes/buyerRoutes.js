const express = require("express");

const {
  getListings,
  getListing,
  createRequest,
  getMyRequests,
  getRequestResponses,
  acceptResponse,
  updateRequest,
  deleteRequest,
  getMyNegotiations,
  startNegotiation,
  getNegotiation,
  sendMessage,
  acceptNegotiation,
  rejectNegotiation,
  getMyOrders,
  completeOrder,
} = require("../controllers/buyerController");
const { requireAuth, requireRole } = require("../middleware/auth");

const router = express.Router();

/**
 * @swagger
 * /api/buyer/listings:
 *   get:
 *     summary: Active estate owner listings for the marketplace
 *     tags: [Buyer]
 *     parameters:
 *       - in: query
 *         name: type
 *         schema:
 *           type: string
 *           enum: [RAW_COCONUT, HUSKED_COCONUT, DEHUSKED_COCONUT]
 *       - in: query
 *         name: sort
 *         schema:
 *           type: string
 *           enum: [newest, price_asc, price_desc, trust]
 *     responses:
 *       200:
 *         description: Listings with estate name, owner, location and trust score
 */
router.get("/listings", getListings);

/**
 * @swagger
 * /api/buyer/listings/{id}:
 *   get:
 *     summary: One listing with its estate owner details
 *     tags: [Buyer]
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: The listing
 *       404:
 *         description: Listing not found
 */
router.get("/listings/:id", getListing);

// Everything below needs a logged-in buyer.
router.use(requireAuth, requireRole("BUYER"));

/**
 * @swagger
 * /api/buyer/requests:
 *   post:
 *     summary: Submit a buyer request as the logged-in buyer
 *     tags: [Buyer]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/MyBuyerRequestInput'
 *     responses:
 *       201:
 *         description: Request saved
 *       400:
 *         description: Missing fields
 *   get:
 *     summary: The logged-in buyer's own requests
 *     tags: [Buyer]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of requests
 */
router.post("/requests", createRequest);
router.get("/requests", getMyRequests);

/**
 * @swagger
 * /api/buyer/requests/{id}:
 *   put:
 *     summary: Edit one of my pending requests
 *     tags: [Buyer]
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
 *             required: [requestedQuantity, requiredDate, biddingPricePerUnit]
 *             properties:
 *               requestedQuantity: { type: integer, example: 1500 }
 *               requiredDate: { type: string, format: date, example: "2026-12-20" }
 *               biddingPricePerUnit: { type: number, example: 118 }
 *     responses:
 *       200:
 *         description: Request updated
 *       404:
 *         description: No pending request of yours with that id
 *   delete:
 *     summary: Delete one of my requests (not once estate owners responded)
 *     tags: [Buyer]
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
 *         description: Request deleted
 *       409:
 *         description: Estate owners already responded
 */
router.put("/requests/:id", updateRequest);
router.delete("/requests/:id", deleteRequest);

/**
 * @swagger
 * /api/buyer/requests/{id}/responses:
 *   get:
 *     summary: Estate owners' offers on one of my requests, cheapest first
 *     tags: [Buyer]
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
 *         description: Offers with estate details
 */
router.get("/requests/:id/responses", getRequestResponses);

/**
 * @swagger
 * /api/buyer/responses/{id}/accept:
 *   post:
 *     summary: Accept an estate owner's offer - creates an order
 *     tags: [Buyer]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: The offer (sell request) id
 *         schema:
 *           type: integer
 *     responses:
 *       201:
 *         description: Order created; other offers declined
 *       409:
 *         description: Request already closed
 */
router.post("/responses/:id/accept", acceptResponse);

/**
 * @swagger
 * /api/buyer/negotiations:
 *   post:
 *     summary: Start (or reopen) a negotiation on a listing
 *     tags: [Buyer]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [listingId]
 *             properties:
 *               listingId: { type: integer, example: 1 }
 *     responses:
 *       201:
 *         description: New negotiation
 *       200:
 *         description: Existing open negotiation
 */
router.post("/negotiations", startNegotiation);

/**
 * @swagger
 * /api/buyer/negotiations:
 *   get:
 *     summary: My negotiations, newest first
 *     tags: [Buyer]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of negotiations with estate and order status
 */
router.get("/negotiations", getMyNegotiations);

/**
 * @swagger
 * /api/buyer/negotiations/{id}:
 *   get:
 *     summary: A negotiation with its listing, messages and order status
 *     tags: [Buyer]
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
 *       404:
 *         description: Not found
 */
router.get("/negotiations/:id", getNegotiation);

/**
 * @swagger
 * /api/buyer/negotiations/{id}/messages:
 *   post:
 *     summary: Send a message and/or a counter-offer
 *     tags: [Buyer]
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
 *               message: { type: string, example: "Can you do Rs. 118?" }
 *               offerPricePerUnit: { type: number, example: 118 }
 *     responses:
 *       201:
 *         description: Message saved
 *       409:
 *         description: Negotiation is closed
 */
router.post("/negotiations/:id/messages", sendMessage);

/**
 * @swagger
 * /api/buyer/negotiations/{id}/accept:
 *   post:
 *     summary: Accept the deal - creates an order
 *     tags: [Buyer]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       201:
 *         description: Order created
 *       409:
 *         description: Negotiation is closed
 */
router.post("/negotiations/:id/accept", acceptNegotiation);

/**
 * @swagger
 * /api/buyer/negotiations/{id}/reject:
 *   post:
 *     summary: Reject the offer and close the negotiation
 *     tags: [Buyer]
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
 *         description: Negotiation rejected
 */
router.post("/negotiations/:id/reject", rejectNegotiation);

/**
 * @swagger
 * /api/buyer/orders:
 *   get:
 *     summary: The logged-in buyer's orders
 *     tags: [Buyer]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: List of orders
 */
router.get("/orders", getMyOrders);

/**
 * @swagger
 * /api/buyer/orders/{id}/complete:
 *   patch:
 *     summary: Mark an accepted order as completed
 *     tags: [Buyer]
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
 *         description: Order completed
 *       404:
 *         description: No accepted order with that id
 */
router.patch("/orders/:id/complete", completeOrder);

module.exports = router;

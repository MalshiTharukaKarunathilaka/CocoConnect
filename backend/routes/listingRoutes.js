const express = require("express");

  
const {
  createListing,
  getBuyerRequests,
  createBuyerRequest,
  createSellRequest,
} = require("../controllers/listingController");
const router = express.Router();

/**
 * @swagger
 * /api/listings:
 *   post:
 *     summary: Create a product listing
 *     tags: [Listings]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/ListingInput'
 *     responses:
 *       201:
 *         description: Listing created successfully
 *       400:
 *         description: Missing required fields
 *       500:
 *         description: Server error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post("/", createListing);

/**
 * @swagger
 * /api/listings/buyer-requests:
 *   get:
 *     summary: Get buyer requests
 *     tags: [Listings]
 *     responses:
 *       200:
 *         description: Buyer requests ordered by bidding price
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *       500:
 *         description: Server error
 */
router.get("/buyer-requests", getBuyerRequests);

/**
 * @swagger
 * /api/listings/buyer-requests:
 *   post:
 *     summary: Create a buyer request
 *     tags: [Listings]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/BuyerRequestInput'
 *     responses:
 *       201:
 *         description: Buyer request created successfully
 *       400:
 *         description: Missing required fields
 *       500:
 *         description: Server error
 */
router.post("/buyer-requests", createBuyerRequest);

/**
 * @swagger
 * /api/listings/sell-requests:
 *   post:
 *     summary: Create a sell request
 *     tags: [Listings]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/SellRequestInput'
 *     responses:
 *       201:
 *         description: Sell request created successfully
 *       400:
 *         description: Missing required fields
 *       500:
 *         description: Server error
 */
router.post("/sell-requests", createSellRequest);

module.exports = router;
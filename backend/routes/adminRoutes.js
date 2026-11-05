const express = require("express");

const {
  getDashboard,
  getUsers,
  setUserStatus,
  getBuyRequests,
  hideBuyRequest,
  getListings,
  hideListing,
  verifyListing,
  getDeals,
  getDealDetail,
  getTransactions,
  getDisputes,
  setDisputeSeverity,
  approveDispute,
  rejectDispute,
  resolveDisputeAction,
  createDisputeOnDeal,
  getRegions,
  putRegionBand,
  getReports,
  getSettings,
  putSettings,
} = require("../controllers/adminController");
const { requireAuth, requireRole } = require("../middleware/auth");

const router = express.Router();

router.use(requireAuth, requireRole("ADMIN"));

router.get("/dashboard", getDashboard);

router.get("/users", getUsers);
router.patch("/users/:id/status", setUserStatus);

router.get("/buy-requests", getBuyRequests);
router.patch("/buy-requests/:id/hide", hideBuyRequest);

router.get("/listings", getListings);
router.patch("/listings/:id/hide", hideListing);
router.patch("/listings/:id/verify", verifyListing);

router.get("/deals", getDeals);
router.get("/deals/:id", getDealDetail);
router.post("/deals/:id/disputes", createDisputeOnDeal);

router.get("/transactions", getTransactions);

/**
 * @swagger
 * /api/admin/disputes:
 *   get:
 *     summary: Price disputes raised when completing deals (waiting ones first)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 */
router.get("/disputes", getDisputes);
router.patch("/disputes/:id/severity", setDisputeSeverity);
router.patch("/disputes/:id/resolve", resolveDisputeAction);

/**
 * @swagger
 * /api/admin/disputes/{id}/approve:
 *   post:
 *     summary: Approve the requested price - it becomes the settled price
 *     tags: [Admin]
 */
router.post("/disputes/:id/approve", approveDispute);

/**
 * @swagger
 * /api/admin/disputes/{id}/reject:
 *   post:
 *     summary: Reject the requested price - the agreed price stays
 *     tags: [Admin]
 */
router.post("/disputes/:id/reject", rejectDispute);

router.get("/regions", getRegions);
router.put("/regions/band", putRegionBand);

router.get("/reports", getReports);
router.get("/settings", getSettings);
router.put("/settings", putSettings);

module.exports = router;

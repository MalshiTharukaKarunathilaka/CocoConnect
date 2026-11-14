const express = require("express");

const {
  getDisputes,
  approveDispute,
  rejectDispute,
} = require("../controllers/adminController");
const { requireAuth, requireRole } = require("../middleware/auth");

const router = express.Router();

router.use(requireAuth, requireRole("ADMIN"));

/**
 * @swagger
 * /api/admin/disputes:
 *   get:
 *     summary: Price disputes raised when completing deals (waiting ones first)
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Orders with agreed, requested and current prices
 *       403:
 *         description: Not an admin account
 */
router.get("/disputes", getDisputes);

/**
 * @swagger
 * /api/admin/disputes/{id}/approve:
 *   post:
 *     summary: Approve the requested price - it becomes the settled price
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: Order id
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Approved
 */
router.post("/disputes/:id/approve", approveDispute);

/**
 * @swagger
 * /api/admin/disputes/{id}/reject:
 *   post:
 *     summary: Reject the requested price - the agreed price stays
 *     tags: [Admin]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         description: Order id
 *         schema: { type: integer }
 *     responses:
 *       200:
 *         description: Rejected
 */
router.post("/disputes/:id/reject", rejectDispute);

module.exports = router;

const express = require("express");
const { getHolidays } = require("../utils/holidays");
const { requireAuth } = require("../middleware/auth");

const router = express.Router();

/**
 * @swagger
 * /api/holidays:
 *   get:
 *     summary: Approved Sri Lankan public holidays for the app calendars
 *     tags: [Calendar]
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: year
 *         schema: { type: integer }
 *         description: Only holidays in this year
 *     responses:
 *       200:
 *         description: "{ holidays: [{ date, name, type }], stale, fetched_at }."
 */
router.get("/", requireAuth, async (req, res) => {
  const year = Number(req.query.year);
  const valid = Number.isInteger(year) && year >= 2000 && year <= 2100;
  if (req.query.year !== undefined && !valid) {
    return res.status(400).json({ message: "Year must be between 2000 and 2100" });
  }
  return res.status(200).json(await getHolidays({ year: valid ? year : undefined }));
});

module.exports = router;

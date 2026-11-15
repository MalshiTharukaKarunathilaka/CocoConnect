const express = require("express");
const { requireAuth, requireRole } = require("../middleware/auth");
const {
  getAvailableJobs,
  getEstates,
  getNearbyEstates,
  applyForJob,
  declineJob,
} = require("../controllers/workerController");

const router = express.Router();

router.use(requireAuth, requireRole("WORKER"));
router.get("/jobs", getAvailableJobs);
router.get("/estates", getEstates);
router.get("/nearby-estates", getNearbyEstates);
router.post("/jobs/:id/apply", applyForJob);
router.post("/jobs/:id/decline", declineJob);

module.exports = router;

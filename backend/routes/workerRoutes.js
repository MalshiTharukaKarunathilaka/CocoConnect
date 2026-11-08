const express = require("express");
const { requireAuth, requireRole } = require("../middleware/auth");
const {
  getAvailableJobs,
  applyForJob,
} = require("../controllers/workerController");

const router = express.Router();

router.use(requireAuth, requireRole("WORKER"));
router.get("/jobs", getAvailableJobs);
router.post("/jobs/:id/apply", applyForJob);

module.exports = router;

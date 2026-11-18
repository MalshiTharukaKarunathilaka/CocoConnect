const express = require("express");
const { requireAuth, requireRole } = require("../middleware/auth");
const {
  getAvailableJobs,
  getProfile,
  getEstates,
  getEstateLocation,
  getNearbyEstates,
  getEstateOwnerProfile,
  rateEstateOwner,
  applyForJob,
  declineJob,
  initiateJobCompletion,
  acknowledgeJobCompletion,
} = require("../controllers/workerController");

const router = express.Router();

router.use(requireAuth, requireRole("WORKER"));
router.get("/profile", getProfile);
router.get("/jobs", getAvailableJobs);
router.get("/estates", getEstates);
router.get("/estates/:id/location", getEstateLocation);
router.get("/nearby-estates", getNearbyEstates);
router.get("/jobs/:id/estate-owner", getEstateOwnerProfile);
router.put("/jobs/:id/estate-owner/rating", rateEstateOwner);
router.post("/jobs/:id/apply", applyForJob);
router.post("/jobs/:id/decline", declineJob);
router.post("/jobs/:id/initiate-complete", initiateJobCompletion);
router.patch("/jobs/:id/complete", acknowledgeJobCompletion);

module.exports = router;

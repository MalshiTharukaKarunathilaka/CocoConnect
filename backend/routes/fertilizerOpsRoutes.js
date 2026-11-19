const express = require("express");
const { requireAuth } = require("../middleware/auth");
const {
  bootstrap,
  upsertOrder,
  upsertGov,
  upsertShopTalk,
  upsertComplaint,
  upsertAlert,
  markAlertRead,
} = require("../controllers/fertilizerOpsController");

const router = express.Router();

router.use(requireAuth);

router.get("/bootstrap", bootstrap);
router.put("/orders", upsertOrder);
router.put("/gov-requests", upsertGov);
router.put("/shop-talks/:placeId", upsertShopTalk);
router.put("/complaints", upsertComplaint);
router.put("/alerts", upsertAlert);
router.post("/alerts/:id/read", markAlertRead);

module.exports = router;

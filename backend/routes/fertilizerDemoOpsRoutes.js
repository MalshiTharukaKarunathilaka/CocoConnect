const express = require("express");
const { requireAuth } = require("../middleware/auth");
const {
  requireFertilizerDemoAccount,
  bootstrap,
  upsertOrder,
  upsertGov,
  upsertShopTalk,
  upsertComplaint,
  upsertAlert,
  markAlertRead,
} = require("../controllers/fertilizerDemoOpsController");

const router = express.Router();



router.get("/bootstrap", requireAuth, requireFertilizerDemoAccount, bootstrap);
router.put("/orders", requireAuth, requireFertilizerDemoAccount, upsertOrder);
router.put("/gov-requests", requireAuth, requireFertilizerDemoAccount, upsertGov);
router.put("/shop-talks/:placeId", requireAuth, requireFertilizerDemoAccount, upsertShopTalk);
router.put("/complaints", requireAuth, requireFertilizerDemoAccount, upsertComplaint);
router.put("/alerts", requireAuth, requireFertilizerDemoAccount, upsertAlert);
router.post("/alerts/:id/read", requireAuth, requireFertilizerDemoAccount, markAlertRead);

module.exports = router;

const express = require("express");
const cors = require("cors");
const swaggerUi = require("swagger-ui-express");
require("dotenv").config({path: require("path").join(__dirname, ".env")});

const listingRoutes = require("./routes/listingRoutes");
const authRoutes = require("./routes/authRoutes");
const buyerRoutes = require("./routes/buyerRoutes");
const ownerRoutes = require("./routes/ownerRoutes");
const chatRoutes = require("./routes/chatRoutes");
const adminRoutes = require("./routes/adminRoutes");
const workerRoutes = require("./routes/workerRoutes");
const dayJobChatRoutes = require("./routes/dayJobChatRoutes");
const swaggerDocument = require("./config/swagger");

const { getHealth } = require("./controllers/healthController");
const app = express();

app.use(cors());
// Log each client request so phone connectivity can be checked from the
// backend terminal. HTTP only shows a device when it makes a request; it
// cannot detect when the device joins or leaves the Wi-Fi hotspot.
app.use((req, res, next) => {
  const startedAt = Date.now();
  const clientIp = req.ip || req.socket.remoteAddress || "unknown";
  const deviceId = req.get("x-device-id") || "unknown-client";
  const devicePlatform = req.get("x-device-platform") || "unknown";
  const userAgent = req.get("user-agent") || "unknown";

  res.on("finish", () => {
    console.log(
      `[${new Date().toISOString()}] CLIENT REQUEST IP=${clientIp} ` +
      `DEVICE_ID=${deviceId} PLATFORM=${devicePlatform} ${req.method} ${req.path} ` +
      `STATUS=${res.statusCode} DURATION=${Date.now() - startedAt}ms UA="${userAgent}"`
    );
  });
  next();
});
app.use('/api/fertilizer', express.json({limit: '16mb'}));
app.use(express.json());
app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));
app.get("/api-docs.json", (req, res) => {
  res.json(swaggerDocument);
});

app.get("/", (req, res) => {
  res.json({
    message: "KapConnect backend is running",
  });
});

app.get("/api/health", getHealth);

app.use("/api/fertilizer", require("./routes/fertilizerRoutes"));
app.use("/api/machinery", require("./routes/machineryRoutes"));
app.use("/api/holidays", require("./routes/holidayRoutes"));
app.use("/api/listings", listingRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/buyer", buyerRoutes);
app.use("/api/owner", ownerRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/worker", workerRoutes);
app.use("/api", dayJobChatRoutes);
app.use("/api", chatRoutes);

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

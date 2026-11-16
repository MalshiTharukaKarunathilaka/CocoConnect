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

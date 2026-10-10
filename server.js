const express = require("express");
const cors = require("cors");
const swaggerUi = require("swagger-ui-express");
require("dotenv").config();

const listingRoutes = require("./routes/listingRoutes");
const authRoutes = require("./routes/authRoutes");
const buyerRoutes = require("./routes/buyerRoutes");
const swaggerDocument = require("./config/swagger");

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

app.use("/api/listings", listingRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/buyer", buyerRoutes);

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
const swaggerJSDoc = require("swagger-jsdoc");

const options = {
  definition: {
    openapi: "3.0.3",
    info: {
      title: "KapConnect API",
      version: "1.0.0",
      description: "API documentation for the KapConnect backend.",
    },
    servers: [
      {
        url: "http://localhost:5000",
        description: "Local development server",
      },
    ],
    tags: [
      {
        name: "Listings",
        description: "Product listing and buyer/sell request operations",
      },
    ],
    components: {
      schemas: {
        ListingInput: {
          type: "object",
          required: [
            "estateOwnerId",
            "productType",
            "quantity",
            "availableDate",
            "offerPricePerUnit",
          ],
          properties: {
            estateOwnerId: { type: "integer", example: 1 },
            productType: { type: "string", example: "Wheat" },
            quantity: { type: "number", example: 100 },
            availableDate: {
              type: "string",
              format: "date",
              example: "2026-12-01",
            },
            offerPricePerUnit: { type: "number", example: 25.5 },
          },
        },
        BuyerRequestInput: {
          type: "object",
          required: [
            "buyerName",
            "location",
            "productType",
            "requestedQuantity",
            "requiredDate",
            "biddingPricePerUnit",
          ],
          properties: {
            buyerName: { type: "string", example: "Green Farms" },
            location: { type: "string", example: "Nagpur" },
            productType: { type: "string", example: "Wheat" },
            requestedQuantity: { type: "number", example: 50 },
            requiredDate: {
              type: "string",
              format: "date",
              example: "2026-12-15",
            },
            biddingPricePerUnit: { type: "number", example: 24 },
            trustScore: { type: "number", example: 4.5 },
          },
        },
        SellRequestInput: {
          type: "object",
          required: [
            "estateOwnerId",
            "buyerRequestId",
            "productType",
            "quantity",
            "sellerPricePerUnit",
          ],
          properties: {
            estateOwnerId: { type: "integer", example: 1 },
            buyerRequestId: { type: "integer", example: 10 },
            productType: { type: "string", example: "Wheat" },
            quantity: { type: "number", example: 50 },
            sellerPricePerUnit: { type: "number", example: 23.5 },
            availableDate: {
              type: "string",
              format: "date",
              example: "2026-12-01",
            },
          },
        },
        Error: {
          type: "object",
          properties: {
            message: { type: "string", example: "Server error" },
          },
        },
      },
    },
  },
  apis: ["./routes/*.js"],
};

module.exports = swaggerJSDoc(options);

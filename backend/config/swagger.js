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
      {
        name: "Auth",
        description: "Sign up and log in (all roles)",
      },
      {
        name: "Buyer",
        description: "Marketplace, buyer requests, negotiation and orders",
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: "http",
          scheme: "bearer",
          bearerFormat: "JWT",
        },
      },
      schemas: {
        SignupInput: {
          type: "object",
          required: ["name", "phone", "password", "role"],
          properties: {
            name: { type: "string", example: "Senuji Test" },
            phone: { type: "string", example: "0771234567" },
            password: { type: "string", example: "secret123" },
            role: {
              type: "string",
              enum: ["BUYER", "ESTATE_OWNER", "ESTATE_MANAGER", "SERVICE_PROVIDER"],
              example: "BUYER",
            },
            location: { type: "string", example: "Colombo" },
          },
        },
        LoginInput: {
          type: "object",
          required: ["phone", "password"],
          properties: {
            phone: { type: "string", example: "0771234567" },
            password: { type: "string", example: "secret123" },
          },
        },
        MyBuyerRequestInput: {
          type: "object",
          required: [
            "productType",
            "requestedQuantity",
            "requiredDate",
            "biddingPricePerUnit",
          ],
          properties: {
            productType: { type: "string", example: "RAW_COCONUT" },
            requestedQuantity: { type: "integer", example: 1200 },
            requiredDate: {
              type: "string",
              format: "date",
              example: "2026-12-15",
            },
            biddingPricePerUnit: { type: "number", example: 115 },
            location: { type: "string", example: "Colombo" },
          },
        },
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

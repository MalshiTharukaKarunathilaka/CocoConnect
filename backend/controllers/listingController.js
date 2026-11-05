const pool = require("../config/db");

/*
|--------------------------------------------------------------------------
| CREATE BUYER REQUEST
|--------------------------------------------------------------------------
*/
const createBuyerRequest = async (req, res) => {
  try {
    const {
      buyerName,
      location,
      productType,
      requestedQuantity,
      requiredDate,
      biddingPricePerUnit,
      trustScore,
    } = req.body;

    if (
      !buyerName ||
      !location ||
      !productType ||
      !requestedQuantity ||
      !requiredDate ||
      !biddingPricePerUnit
    ) {
      return res.status(400).json({
        message: "All required fields must be filled",
      });
    }

    const result = await pool.query(
      `INSERT INTO buyer_requests
      (
        buyer_name,
        location,
        product_type,
        requested_quantity,
        required_date,
        bidding_price_per_unit,
        trust_score
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *`,
      [
        buyerName,
        location,
        productType,
        requestedQuantity,
        requiredDate,
        biddingPricePerUnit,
        trustScore || 0,
      ]
    );

    return res.status(201).json({
      message: "Buyer request created successfully",
      buyerRequest: result.rows[0],
    });

  } catch (error) {
    console.error("Create buyer request error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};


/*
|--------------------------------------------------------------------------
| CREATE PRODUCT LISTING
|--------------------------------------------------------------------------
*/
const createListing = async (req, res) => {
  try {
    const {
      estateOwnerId,
      productType,
      quantity,
      availableDate,
      offerPricePerUnit,
    } = req.body;

    if (
      !estateOwnerId ||
      !productType ||
      !quantity ||
      !availableDate ||
      !offerPricePerUnit
    ) {
      return res.status(400).json({
        message: "All fields are required",
      });
    }

    const result = await pool.query(
      `INSERT INTO product_listings
      (
        estate_owner_id,
        product_type,
        quantity,
        available_date,
        offer_price_per_unit
      )
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *`,
      [
        estateOwnerId,
        productType,
        quantity,
        availableDate,
        offerPricePerUnit,
      ]
    );

    return res.status(201).json({
      message: "Listing created successfully",
      listing: result.rows[0],
    });

  } catch (error) {
    console.error("Create listing error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};


/*
|--------------------------------------------------------------------------
| GET BUYER REQUESTS
|--------------------------------------------------------------------------
*/
const getBuyerRequests = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        id,
        buyer_name,
        location,
        product_type,
        requested_quantity,
        required_date,
        bidding_price_per_unit,
        trust_score
      FROM buyer_requests
      ORDER BY bidding_price_per_unit DESC`
    );

    console.log("Buyer requests:", result.rows);

    return res.status(200).json(result.rows);

  } catch (error) {
    console.error("Get buyer requests error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};


/*
|--------------------------------------------------------------------------
| GET PRODUCT LISTINGS
|--------------------------------------------------------------------------
*/
const getListings = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT *
       FROM product_listings
       ORDER BY id DESC`
    );

    return res.status(200).json(result.rows);

  } catch (error) {
    console.error("Get listings error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};

/*
|--------------------------------------------------------------------------
| SELL REQUEST CREATION
|--------------------------------------------------------------------------
*/
const createSellRequest = async (req, res) => {
  try {
    const {
      estateOwnerId,
      buyerRequestId,
      productType,
      quantity,
      sellerPricePerUnit,
      availableDate,
    } = req.body;

    if (
      !estateOwnerId ||
      !buyerRequestId ||
      !productType ||
      !quantity ||
      !sellerPricePerUnit
    ) {
      return res.status(400).json({
        message: "All required fields must be filled",
      });
    }

    const result = await pool.query(
      `INSERT INTO sell_requests
      (
        estate_owner_id,
        buyer_request_id,
        product_type,
        quantity,
        seller_price_per_unit,
        available_date,
        status
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *`,
      [
        estateOwnerId,
        buyerRequestId,
        productType,
        quantity,
        sellerPricePerUnit,
        availableDate,
        "pending",
      ]
    );

    return res.status(201).json({
      message: "Sell request created successfully",
      sellRequest: result.rows[0],
    });

  } catch (error) {
    console.error("Create sell request error:", error);

    return res.status(500).json({
      message: "Server error",
      error: error.message,
    });
  }
};
/*
|--------------------------------------------------------------------------
| EXPORT FUNCTIONS
|--------------------------------------------------------------------------
*/
module.exports = {
  createBuyerRequest,
  createListing,
  getBuyerRequests,
  getListings,
  createSellRequest,
};
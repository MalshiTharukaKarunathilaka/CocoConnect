const pool = require("../config/db");

/*
|--------------------------------------------------------------------------
| ADMIN - price disputes
|--------------------------------------------------------------------------
| An estate owner who completes a deal at a different price than agreed
| flags it for review. The agreed price stays in force until an admin
| approves the new one.
*/

const serverError = (res, label, error) => {
  console.error(`${label} error:`, error);
  return res.status(500).json({ message: "Server error", error: error.message });
};

const getDisputes = async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        o.id, o.final_price_per_unit, o.total_value, o.delivered_quantity,
        o.delivered_price_per_unit, o.dispute_price_per_unit, o.dispute_status,
        o.dispute_note, o.completed_at, o.dispute_resolved_at,
        COALESCE(pl.product_type, sr.product_type) AS product_type,
        eo1.estate_name AS listing_estate,
        eo2.estate_name AS offer_estate,
        u.name AS buyer_name
       FROM orders o
       LEFT JOIN product_listings pl ON pl.id = o.listing_id
       LEFT JOIN sell_requests sr
         ON sr.buyer_request_id = o.buyer_request_id AND sr.status = 'accepted'
       LEFT JOIN estate_owners eo1 ON eo1.id = pl.estate_owner_id
       LEFT JOIN estate_owners eo2 ON eo2.id = sr.estate_owner_id
       LEFT JOIN users u ON u.id = o.buyer_id
       WHERE o.dispute_status IS NOT NULL
       ORDER BY o.completed_at DESC, o.id DESC`
    );

    const rows = result.rows.map(({ listing_estate, offer_estate, ...row }) => ({
      ...row,
      estate_name: listing_estate || offer_estate || "Estate",
    }));
    // Waiting ones first.
    rows.sort(
      (a, b) =>
        Number(b.dispute_status === "PENDING") - Number(a.dispute_status === "PENDING")
    );
    return res.status(200).json(rows);
  } catch (error) {
    return serverError(res, "Get disputes", error);
  }
};

const resolve = (approve) => async (req, res) => {
  try {
    const found = await pool.query(
      "SELECT id, dispute_status, dispute_price_per_unit FROM orders WHERE id = $1",
      [req.params.id]
    );
    const order = found.rows[0];
    if (!order || !order.dispute_status) {
      return res.status(404).json({ message: "Dispute not found" });
    }
    if (order.dispute_status !== "PENDING") {
      return res.status(409).json({ message: "This dispute was already resolved" });
    }

    const result = approve
      ? await pool.query(
          `UPDATE orders
           SET dispute_status = 'APPROVED',
               delivered_price_per_unit = dispute_price_per_unit,
               dispute_resolved_at = $2
           WHERE id = $1
           RETURNING *`,
          [order.id, new Date()]
        )
      : await pool.query(
          `UPDATE orders
           SET dispute_status = 'REJECTED', dispute_resolved_at = $2
           WHERE id = $1
           RETURNING *`,
          [order.id, new Date()]
        );

    return res.status(200).json({
      message: approve ? "New price approved" : "Dispute rejected - agreed price stays",
      order: result.rows[0],
    });
  } catch (error) {
    return serverError(res, "Resolve dispute", error);
  }
};

module.exports = {
  getDisputes,
  approveDispute: resolve(true),
  rejectDispute: resolve(false),
};

const pool = require('../config/db');
const {myOrders} = require('./activityController');

const rateOrder = async (req, res) => {
  try {
    const rating = req.body.rating;
    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      return res.status(400).json({message: 'Choose a rating from 1 to 5 stars'});
    }
    const order = (await myOrders(req.user.id)).find(o => String(o.id) === String(req.params.id));
    if (!order) return res.status(404).json({message: 'Order not found'});
    if (order.status !== 'COMPLETED') {
      return res.status(409).json({message: 'Ratings are available after the buyer confirms collection'});
    }
    const column = order.my_role === 'BUYER' ? 'buyer_rating' : 'owner_rating';
    const timestamp = order.my_role === 'BUYER' ? 'buyer_rated_at' : 'owner_rated_at';
    const result = await pool.query(
      `UPDATE orders SET ${column} = $2, ${timestamp} = $3
       WHERE id = $1 AND status = 'COMPLETED' AND ${column} IS NULL RETURNING id`,
      [order.id, rating, new Date()]);
    if (!result.rows.length) return res.status(409).json({message: 'You have already rated this deal'});
    return res.json({message: 'Rating saved', rating});
  } catch (error) {
    console.error('Rate order error:', error);
    return res.status(500).json({message: 'Could not save rating'});
  }
};
module.exports = {rateOrder};

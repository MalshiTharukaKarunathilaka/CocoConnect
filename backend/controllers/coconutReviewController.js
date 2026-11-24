const pool = require('../config/db');

function receivedRatingsSource(role) {
  const isBuyer = role === 'BUYER';
  return {
    author: isBuyer ? 'owner' : 'buyer',
    recipient: isBuyer
      ? 'COALESCE(o.buyer_id, br.buyer_id)'
      : 'COALESCE(listing_owner.user_id, offer_owner.user_id)',
    joins: isBuyer
      ? 'LEFT JOIN buyer_requests br ON br.id = o.buyer_request_id'
      : `
      LEFT JOIN product_listings pl ON pl.id = o.listing_id
      LEFT JOIN estate_owners listing_owner ON listing_owner.id = pl.estate_owner_id
      LEFT JOIN sell_requests sr ON sr.buyer_request_id = o.buyer_request_id
        AND sr.status = 'accepted' AND listing_owner.user_id IS NULL
      LEFT JOIN estate_owners offer_owner ON offer_owner.id = sr.estate_owner_id`,
  };
}

async function receivedCoconutReviews(userId, role) {
  if (userId == null) return {average_rating: null, rating_count: 0, comments: []};
  const {author, recipient, joins} = receivedRatingsSource(role);
  const {rows} = await pool.query(
    `SELECT o.${author}_rating AS rating, o.${author}_rating_note AS comment,
            o.${author}_rated_at AS rated_at
     FROM orders o ${joins} WHERE o.status = 'COMPLETED'
       AND o.${author}_rating BETWEEN 1 AND 5 AND ${recipient} = $1
     ORDER BY o.${author}_rated_at DESC NULLS LAST, o.id DESC`,
    [userId],
  );
  const total = rows.reduce((sum, row) => sum + Number(row.rating), 0);
  return {
    average_rating: rows.length ? total / rows.length : null,
    rating_count: rows.length,
    comments: rows.filter(row => row.comment?.trim()),
  };
}

async function coconutTrustScores(userIds, role) {
  if (!userIds.length) return new Map();
  const {author, recipient, joins} = receivedRatingsSource(role);
  const recipients = userIds.map((_, index) => `$${index + 1}`).join(', ');
  const {rows} = await pool.query(
    `SELECT ${recipient} AS user_id, AVG(o.${author}_rating) AS average_rating
     FROM orders o ${joins}
     WHERE o.status = 'COMPLETED' AND o.${author}_rating BETWEEN 1 AND 5
       AND ${recipient} IN (${recipients})
     GROUP BY ${recipient}`,
    userIds,
  );
  return new Map(rows.map(row => [row.user_id, Number(row.average_rating)]));
}

async function coconutCounterpartProfile(userId, role, fallbackName) {
  const {rows} = userId == null ? {rows: []} : await pool.query(
    `SELECT u.name, u.location, eo.estate_name, eo.location AS estate_location
     FROM users u
     LEFT JOIN estate_owners eo ON eo.user_id = u.id AND $2 = 'ESTATE_OWNER'
     WHERE u.id = $1 ORDER BY eo.id LIMIT 1`,
    [userId, role],
  );
  const person = rows[0];
  return {
    name: person?.name || fallbackName,
    estate_name: person?.estate_name,
    location: person?.estate_location || person?.location,
    role,
    ...await receivedCoconutReviews(userId, role),
  };
}

async function getMyCoconutReviews(req, res) {
  if (!['BUYER', 'ESTATE_OWNER'].includes(req.user.role)) {
    return res.status(403).json({message: 'Coconut reviews are available to buyers and landowners'});
  }
  try {
    return res.json(await receivedCoconutReviews(req.user.id, req.user.role));
  } catch (error) {
    console.error('Load coconut reviews:', error);
    return res.status(500).json({message: 'Could not load coconut reviews'});
  }
}

module.exports = {
  receivedCoconutReviews,
  getMyCoconutReviews,
  coconutTrustScores,
  coconutCounterpartProfile,
};

// Orders tab overview for both sides, completing deals with a price
// dispute, and admin review. Run with: npm test
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");

process.env.DB_MODE = "memory";
process.env.PORT = "5095";
process.env.JWT_SECRET = process.env.JWT_SECRET || "test-secret";

let server;
const base = "http://localhost:5095";

const call = async (method, path, { token, body } = {}) => {
  const response = await fetch(base + path, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  return { status: response.status, data: text ? JSON.parse(text) : null };
};

const signup = async (name, phone, role) =>
  (await call("POST", "/api/auth/signup", {
    body: { name, phone, password: "secret123", role, location: "Colombo" },
  })).data;

before(async () => {
  const http = require("http");
  const originalListen = http.Server.prototype.listen;
  http.Server.prototype.listen = function (...args) {
    server = this;
    return originalListen.apply(this, args);
  };
  require("../server");
  http.Server.prototype.listen = originalListen;
  await new Promise((resolve) => setTimeout(resolve, 200));
});

after(() => server.close());

let owner;
let buyer;
let admin;
let orderId;
let openChat;

test("activity: pending offers, negotiations, deals on both sides", async () => {
  owner = await signup("Nimal Owner", "0710000021", "ESTATE_OWNER");
  buyer = await signup("Lanka Mills", "0770000021", "BUYER");
  await call("PATCH", "/api/owner/estate", {
    token: owner.token,
    body: { estateName: "Kelani Palms" },
  });

  const list = async (quantity, price) =>
    (await call("POST", "/api/owner/listings", {
      token: owner.token,
      body: {
        productType: "RAW_COCONUT",
        quantity,
        availableDate: "2026-11-20",
        offerPricePerUnit: price,
      },
    })).data.listing.id;
  const open = async (listingId) =>
    (await call("POST", "/api/buyer/negotiations", {
      token: buyer.token,
      body: { listingId },
    })).data.id;

  // A deal at the listed price.
  const dealChat = await open(await list(2000, 130));
  const accepted = await call("POST", `/api/chats/${dealChat}/accept-listing`, {
    token: buyer.token,
  });
  orderId = accepted.data.order.id;

  // An open chat where the buyer's offer waits for the owner.
  openChat = await open(await list(1000, 135));
  await call("POST", `/api/chats/${openChat}/messages`, {
    token: buyer.token,
    body: { offerPricePerUnit: 128 },
  });

  // The owner's offer on a buyer request.
  const request = (await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "RAW_COCONUT",
      requestedQuantity: 500,
      requiredDate: "2026-11-25",
      biddingPricePerUnit: 125,
    },
  })).data.buyerRequest;
  await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: { buyerRequestId: request.id, quantity: 500, sellerPricePerUnit: 127 },
  });

  const mine = (await call("GET", "/api/activity", { token: buyer.token })).data;
  assert.deepEqual(
    mine.pending.map((p) => [p.kind, Number(p.price)]),
    [["CHAT_OFFER", 128]],
    "the buyer's own waiting offer"
  );
  // The open listing chat, plus the chat the estate's offer on the
  // request started.
  assert.equal(mine.negotiations.length, 2);
  assert.ok(mine.negotiations.some((c) => c.id === openChat));
  assert.ok(mine.negotiations.some((c) => c.sell_request_id));
  assert.equal(mine.deals.length, 1);
  assert.equal(mine.deals[0].counterpart_name, "Kelani Palms");
  assert.equal(mine.deals[0].my_role, "BUYER");
  assert.equal(mine.deals[0].due_date, "2026-11-20");
  assert.equal(mine.deals[0].negotiation_id, dealChat);
  assert.equal(mine.transactions.length, 0);

  const theirs = (await call("GET", "/api/activity", { token: owner.token })).data;
  assert.deepEqual(
    theirs.pending.map((p) => [p.kind, Number(p.price)]),
    [["SELL_OFFER", 127]],
    "the buyer's chat offer waits for the owner, so it isn't the owner's pending"
  );
  assert.equal(theirs.pending[0].counterpart_name, "Lanka Mills");
  assert.equal(theirs.pending[0].counterpart_trust_score, null);
  const pendingProfile = `/api/sell-offers/${theirs.pending[0].id}/counterpart-profile`;
  const pendingBuyer = await call("GET", pendingProfile, {token: owner.token});
  assert.equal(pendingBuyer.status, 200);
  assert.equal(pendingBuyer.data.name, "Lanka Mills");
  assert.equal(pendingBuyer.data.average_rating, null);
  const pendingSeller = await call("GET", pendingProfile, {token: buyer.token});
  assert.equal(pendingSeller.status, 200);
  assert.equal(pendingSeller.data.estate_name, "Kelani Palms");
  assert.equal(theirs.deals[0].counterpart_name, "Lanka Mills");
  assert.equal(theirs.deals[0].my_role, "ESTATE_OWNER");
});

test("completing at a different price needs a flagged dispute", async () => {
  const unflagged = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token,
    body: { deliveredQuantity: 2000, finalPricePerUnit: 135 },
  });
  assert.equal(unflagged.status, 409);
  assert.equal(unflagged.data.code, "PRICE_REVIEW_REQUIRED");

  const flagged = await call("POST", `/api/owner/orders/${orderId}/complete`, {
    token: owner.token,
    body: {
      deliveredQuantity: 2000,
      finalPricePerUnit: 135,
      requestPriceReview: true,
      disputeNote: "Graded A by the buyer",
    },
  });
  assert.equal(flagged.status, 200);
  const order = flagged.data.order;
  assert.equal(order.status, "AWAITING_RECEIPT");
  assert.equal(order.completed_at, null);
  assert.ok(order.seller_completed_at);
  assert.equal(Number(order.delivered_price_per_unit), 130, "agreed price protected");
  assert.equal(Number(order.dispute_price_per_unit), 135);
  assert.equal(order.dispute_status, "PENDING");

  const awaiting = (await call('GET', '/api/activity', {token: buyer.token})).data;
  assert.ok(awaiting.deals.some(d => d.id === orderId && d.status === 'AWAITING_RECEIPT'));
  assert.ok(!awaiting.transactions.some(d => d.id === orderId));
  const receipt = await call('PATCH', `/api/buyer/orders/${orderId}/confirm-receipt`, {token: buyer.token});
  assert.equal(receipt.status, 200);
  assert.ok(receipt.data.order.buyer_confirmed_at);
  const buyerView = (await call("GET", "/api/activity", { token: buyer.token })).data;
  assert.equal(buyerView.deals.length, 0);
  assert.equal(buyerView.transactions[0].id, orderId);
  assert.equal(buyerView.transactions[0].dispute_status, "PENDING");
});

test("only admins review disputes; approving applies the new price", async () => {
  const notAdmin = await call("GET", "/api/admin/disputes", { token: owner.token });
  assert.equal(notAdmin.status, 403);

  admin = (await call("POST", "/api/auth/login", {
    body: { phone: "0700000000", password: "admin123" },
  })).data;
  assert.equal(admin.user.role, "ADMIN");

  const disputes = (await call("GET", "/api/admin/disputes", { token: admin.token })).data;
  const dispute = disputes.find((d) => d.id === orderId);
  assert.equal(dispute.estate_name, "Kelani Palms");
  assert.equal(dispute.buyer_name, "Lanka Mills");
  assert.equal(dispute.dispute_note, "Graded A by the buyer");

  const approved = await call("POST", `/api/admin/disputes/${orderId}/approve`, {
    token: admin.token,
  });
  assert.equal(approved.status, 200);
  assert.equal(Number(approved.data.order.delivered_price_per_unit), 135);
  assert.equal(approved.data.order.dispute_status, "APPROVED");

  const again = await call("POST", `/api/admin/disputes/${orderId}/reject`, {
    token: admin.token,
  });
  assert.equal(again.status, 409);
});

test("completing at the agreed price needs no review", async () => {
  // Owner accepts the buyer's 128 offer, then completes at 128.
  const chat = (await call("GET", `/api/chats/${openChat}`, { token: owner.token })).data;
  const offer = chat.messages.find((m) => m.offer_status === "PENDING");
  const accepted = await call(
    "POST",
    `/api/chats/${openChat}/offers/${offer.id}/accept`,
    { token: owner.token }
  );
  const done = await call(
    "POST",
    `/api/owner/orders/${accepted.data.order.id}/complete`,
    { token: owner.token, body: { deliveredQuantity: 990, finalPricePerUnit: 128 } }
  );
  assert.equal(done.status, 200);
  assert.equal(done.data.order.dispute_status, null);
});

test("an offer on a buyer request starts a chat; accepting it there closes the request", async () => {
  const rival = await call("POST", "/api/auth/signup", {
    body: { name: "Rival Owner", phone: "0710000022", password: "secret123", role: "ESTATE_OWNER", location: "Kandy" },
  });
  const request = (await call("POST", "/api/buyer/requests", {
    token: buyer.token,
    body: {
      productType: "RAW_COCONUT",
      requestedQuantity: 700,
      requiredDate: "2026-12-01",
      biddingPricePerUnit: 120,
    },
  })).data.buyerRequest;

  const sent = await call("POST", "/api/owner/sell-requests", {
    token: owner.token,
    body: { buyerRequestId: request.id, quantity: 700, sellerPricePerUnit: 126 },
  });
  assert.equal(sent.status, 201);
  const chatId = sent.data.negotiationId;
  assert.ok(chatId, "a chat was opened");
  const rivalSent = await call("POST", "/api/owner/sell-requests", {
    token: rival.data.token,
    body: { buyerRequestId: request.id, quantity: 700, sellerPricePerUnit: 125 },
  });

  // The buyer sees the chat, starting with the estate's offer to answer.
  const chat = (await call("GET", `/api/chats/${chatId}`, { token: buyer.token })).data;
  assert.equal(chat.counterpart_name, "Kelani Palms");
  assert.equal(chat.can_accept_listing, false);
  const offer = chat.messages[0];
  assert.equal(Number(offer.offer_price_per_unit), 126);
  assert.equal(offer.offer_status, "PENDING");
  assert.match(offer.message, /700 nuts needed by 2026-12-01/);

  // The private chat listing never reaches the marketplace or My Listings.
  const market = (await call("GET", "/api/buyer/listings?type=RAW_COCONUT")).data;
  assert.ok(market.every((l) => Number(l.quantity) !== 700));
  const mine = (await call("GET", "/api/owner/listings", { token: owner.token })).data;
  assert.ok(mine.every((l) => l.status !== "OFFER"));

  // Listed once under the owner's pending orders, with its chat.
  const pending = (await call("GET", "/api/activity", { token: owner.token })).data.pending;
  const listed = pending.filter((p) => p.request_id === request.id);
  assert.equal(listed.length, 1);
  assert.equal(listed[0].negotiation_id, chatId);

  const accepted = await call("POST", `/api/chats/${chatId}/offers/${offer.id}/accept`, {
    token: buyer.token,
  });
  assert.equal(accepted.status, 201);
  assert.equal(accepted.data.order.buyer_request_id, request.id);
  const alerts = (await call('GET', '/api/notifications', {token: owner.token})).data;
  assert.ok(alerts.some(n => n.negotiation_id === chatId && n.title.includes('accepted your deal')));


  const requests = (await call("GET", "/api/buyer/requests", { token: buyer.token })).data;
  assert.equal(requests.find((r) => r.id === request.id).status, "ACCEPTED");
  const rivalChat = await call("GET", `/api/chats/${rivalSent.data.negotiationId}`, {
    token: buyer.token,
  });
  assert.equal(rivalChat.data.status, "REJECTED", "the other estate's chat closes");

  const deal = (await call("GET", "/api/activity", { token: buyer.token })).data.deals.find(
    (d) => d.id === accepted.data.order.id
  );
  assert.equal(deal.due_date, "2026-12-01", "due on the buyer's required date");
  assert.equal(deal.counterpart_name, "Kelani Palms");
  const cancelled = await call('POST', `/api/chats/${chatId}/cancel-deal`, {token: owner.token, body: {reason: "Schedule changed"}});
  assert.equal(cancelled.status, 200);
  const afterCancel = (await call('GET', '/api/buyer/requests', {token: buyer.token})).data;
  assert.equal(afterCancel.find(r => r.id === request.id).status, 'CANCELLED');
  const ownerActivity = (await call('GET', '/api/activity', {token: owner.token})).data;
  assert.ok(!ownerActivity.deals.some(o => o.id === accepted.data.order.id));

});

test("interested buyers can be matched to the estate's harvest", async () => {
  const requestDates = [
    [400, "2026-12-14"],
    [400, "2026-12-03"],
    [5000, "2026-12-12"],
  ];
  for (const productType of ["COCONUT_HUSK", "DEHUSKED_COCONUT"]) {
    for (const [quantity, date] of requestDates) {
      await call("POST", "/api/buyer/requests", {
        token: buyer.token,
        body: {
          productType,
          requestedQuantity: quantity,
          requiredDate: date,
          biddingPricePerUnit: 160,
        },
      });
    }
  }

  // Harvest of 1,000 nuts available 15 Dec: buyers needing 8-15 Dec, up to 1,000.
  for (const productType of ["COCONUT_HUSK", "DEHUSKED_COCONUT"]) {
    const matched = (await call(
      "GET",
      `/api/owner/buyer-requests?type=${productType}&availableDate=2026-12-15&maxQuantity=1000`,
      { token: owner.token }
    )).data;
    assert.deepEqual(
      matched.map((r) => String(r.required_date).slice(0, 10)),
      ["2026-12-14"],
      `${productType} requests match independently`
    );
    assert.ok(matched.every((r) => r.product_type === productType));
  }
});


test('receipt confirmation is buyer-only, follows seller completion, and enables mutual ratings', async () => {
  const outsider = await signup('Unrelated buyer', '0770000088', 'BUYER');
  const listing = (await call('POST', '/api/owner/listings', {token: owner.token, body: {
    productType: 'RAW_COCONUT', quantity: 400, availableDate: '2026-12-10', offerPricePerUnit: 125
  }})).data.listing;
  const chat = (await call('POST', '/api/buyer/negotiations', {token: buyer.token, body: {listingId: listing.id}})).data;
  const accepted = (await call('POST', `/api/chats/${chat.id}/accept-listing`, {token: buyer.token})).data;
  const id = accepted.order.id;
  assert.equal((await call('PATCH', `/api/buyer/orders/${id}/confirm-receipt`, {token: buyer.token})).status, 409);
  assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: buyer.token, body: {rating: 5}})).status, 409);
  const delivered = await call('POST', `/api/owner/orders/${id}/complete`, {token: owner.token, body: {deliveredQuantity: 390, finalPricePerUnit: 125}});
  assert.equal(delivered.status, 200);
  assert.equal(delivered.data.order.status, 'AWAITING_RECEIPT');
  assert.equal(delivered.data.order.completed_at, null);
  assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: owner.token, body: {rating: 4}})).status, 409);
  assert.equal((await call('PATCH', `/api/buyer/orders/${id}/confirm-receipt`, {token: owner.token})).status, 403);
  assert.equal((await call('PATCH', `/api/buyer/orders/${id}/confirm-receipt`, {token: outsider.token})).status, 404);
  const alerts = (await call('GET', '/api/notifications', {token: buyer.token})).data;
  assert.ok(alerts.some(n => n.negotiation_id === chat.id && n.title.includes('mark nuts received')));
  const confirmed = await call('PATCH', `/api/buyer/orders/${id}/confirm-receipt`, {token: buyer.token});
  assert.equal(confirmed.status, 200);
  assert.equal(confirmed.data.order.status, 'COMPLETED');
  assert.ok(confirmed.data.order.buyer_confirmed_at);
  assert.ok(confirmed.data.order.completed_at);
  assert.equal((await call('PATCH', `/api/buyer/orders/${id}/confirm-receipt`, {token: buyer.token})).status, 409);
  const ownerAlerts = (await call('GET', '/api/notifications', {token: owner.token})).data;
  assert.ok(ownerAlerts.some(n => n.negotiation_id === chat.id && n.title.includes('confirmed collection')));
  const history = (await call('GET', `/api/chats/${chat.id}`, {token: buyer.token})).data;
  assert.ok(history.messages.some(m => m.message?.startsWith('Transaction marked complete by ')));
  assert.ok(history.messages.some(m => m.message?.startsWith('Nuts marked as received by ')));
  for (const rating of [0, 6, 2.5, '5', null]) {
    assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: buyer.token, body: {rating}})).status, 400);
  }
  assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: outsider.token, body: {rating: 5}})).status, 404);
  const beforeRating = (await call('GET', '/api/owner/summary', {token: owner.token})).data;
  assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: buyer.token, body: {rating: 5, note: 'x'.repeat(501)}})).status, 400);
  assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: buyer.token, body: {rating: 5, note: '  Easy collection  '}})).status, 200);
  assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: owner.token, body: {rating: 4, note: 'Arrived on time'}})).status, 200);
  assert.equal((await call('PUT', `/api/orders/${id}/rating`, {token: buyer.token, body: {rating: 3}})).status, 409);
  const mine = (await call('GET', '/api/activity', {token: buyer.token})).data.transactions.find(o => o.id === id);
  const theirs = (await call('GET', '/api/activity', {token: owner.token})).data.transactions.find(o => o.id === id);
  assert.equal(mine.my_rating, 5);
  assert.equal(mine.counterpart_rating, 4);
  assert.equal(theirs.my_rating, 4);
  assert.equal(theirs.counterpart_rating, 5);
  assert.equal(mine.my_rating_note, 'Easy collection');
  assert.equal(mine.counterpart_rating_note, 'Arrived on time');
  assert.equal(theirs.my_rating_note, 'Arrived on time');
  assert.equal(theirs.counterpart_rating_note, 'Easy collection');
  assert.equal(mine.counterpart_trust_score, 5);
  assert.equal(theirs.counterpart_trust_score, 4);
  const reviewPath = '/api/coconut-reviews/me';
  const buyerReviews = (await call('GET', reviewPath, {token: buyer.token})).data;
  const ownerReviews = (await call('GET', reviewPath, {token: owner.token})).data;
  assert.ok(buyerReviews.comments.some(review => review.comment === 'Arrived on time' && review.rating === 4));
  assert.ok(ownerReviews.comments.some(review => review.comment === 'Easy collection' && review.rating === 5));
  const profilePath = `/api/chats/${chat.id}/counterpart-profile`;
  const buyerView = await call('GET', profilePath, {token: buyer.token});
  const ownerView = await call('GET', profilePath, {token: owner.token});
  assert.equal(buyerView.data.role, 'ESTATE_OWNER');
  assert.equal(ownerView.data.role, 'BUYER');
  assert.deepEqual(buyerView.data.comments, ownerReviews.comments);
  assert.deepEqual(ownerView.data.comments, buyerReviews.comments);
  assert.equal((await call('GET', profilePath, {token: outsider.token})).status, 404);
  const orderProfile = `/api/orders/${id}/counterpart-profile`;
  const buyerOrderView = await call('GET', orderProfile, {token: buyer.token});
  const ownerOrderView = await call('GET', orderProfile, {token: owner.token});
  assert.equal(buyerOrderView.status, 200);
  assert.equal(ownerOrderView.status, 200);
  assert.deepEqual(buyerOrderView.data.comments, ownerReviews.comments);
  assert.deepEqual(ownerOrderView.data.comments, buyerReviews.comments);
  assert.equal((await call('GET', orderProfile, {token: outsider.token})).status, 404);
  const activeListing = (await call('POST', '/api/owner/listings', {token: owner.token, body: {
    productType: 'RAW_COCONUT', quantity: 200, availableDate: '2026-12-12', offerPricePerUnit: 125,
  }})).data.listing;
  const newSeller = await signup('New Estate', '0710000054', 'ESTATE_OWNER');
  const unratedListing = (await call('POST', '/api/owner/listings', {token: newSeller.token, body: {
    productType: 'RAW_COCONUT', quantity: 200, availableDate: '2026-12-12', offerPricePerUnit: 100,
  }})).data.listing;
  const market = (await call('GET', '/api/buyer/listings?sort=trust', {token: buyer.token})).data;
  assert.equal(market.find(item => item.id === activeListing.id).trust_score, 5);
  assert.ok(market.findIndex(item => item.id === activeListing.id) <
    market.findIndex(item => item.id === unratedListing.id));
  const listingProfile = `/api/buyer/listings/${activeListing.id}/counterpart-profile`;
  assert.deepEqual((await call('GET', listingProfile, {token: buyer.token})).data.comments, ownerReviews.comments);
  assert.equal((await call('GET', listingProfile, {token: owner.token})).status, 403);
  const unratedRequest = (await call('POST', '/api/buyer/requests', {token: outsider.token, body: {
    productType: 'COCONUT_HUSK', requestedQuantity: 100,
    requiredDate: '2026-12-12', biddingPricePerUnit: 999,
  }})).data.buyerRequest;
  const requests = (await call('GET', '/api/owner/buyer-requests?type=COCONUT_HUSK&sort=trust', {token: owner.token})).data;
  assert.ok(requests.length);
  assert.equal(requests[0].trust_score, 4);
  assert.equal(requests.at(-1).id, unratedRequest.id);
  const requestProfile = `/api/owner/buyer-requests/${requests[0].id}/counterpart-profile`;
  assert.deepEqual((await call('GET', requestProfile, {token: owner.token})).data.comments, buyerReviews.comments);
  assert.equal((await call('GET', requestProfile, {token: buyer.token})).status, 403);
  const afterRating = (await call('GET', '/api/owner/summary', {token: owner.token})).data;
  assert.equal(afterRating.rating_count, beforeRating.rating_count + 1);
  assert.equal(afterRating.average_rating, 5);
});


test('cancelling while awaiting receipt prevents confirmation and ratings', async () => {
  const listing = (await call('POST', '/api/owner/listings', {token: owner.token, body: {
    productType: 'RAW_COCONUT', quantity: 100, availableDate: '2026-12-10', offerPricePerUnit: 120
  }})).data.listing;
  const chat = (await call('POST', '/api/buyer/negotiations', {token: buyer.token, body: {listingId: listing.id}})).data;
  const order = (await call('POST', `/api/chats/${chat.id}/accept-listing`, {token: buyer.token})).data.order;
  assert.equal((await call('POST', `/api/owner/orders/${order.id}/complete`, {token: owner.token, body: {deliveredQuantity: 100, finalPricePerUnit: 120}})).status, 200);
  assert.equal((await call('POST', `/api/chats/${chat.id}/cancel-deal`, {token: buyer.token, body: {reason: "Schedule changed"}})).status, 200);
  assert.equal((await call('PATCH', `/api/buyer/orders/${order.id}/confirm-receipt`, {token: buyer.token})).status, 409);
  assert.equal((await call('PUT', `/api/orders/${order.id}/rating`, {token: buyer.token, body: {rating: 5}})).status, 409);
});


test('profile averages only received buyer ratings on completed orders across both sales flows', async () => {
  const ratedOwner = await signup('Rated land owner', '0770000091', 'ESTATE_OWNER');
  const summary = async () => {
    const result = await call('GET', '/api/owner/summary', {token: ratedOwner.token});
    assert.equal(result.status, 200);
    return result.data;
  };
  const empty = await summary();
  assert.equal(empty.average_rating, null);
  assert.equal(empty.rating_count, 0);
  const pool = require('../config/db');
  const estateId = empty.estate.id;
  const listing = (await call('POST', '/api/owner/listings', {token: ratedOwner.token, body: {
    productType: 'RAW_COCONUT', quantity: 100, availableDate: '2026-12-10', offerPricePerUnit: 120
  }})).data.listing;
  const request = (await call('POST', '/api/buyer/requests', {token: buyer.token, body: {
    productType: 'RAW_COCONUT', requestedQuantity: 100, requiredDate: '2026-12-10', biddingPricePerUnit: 120
  }})).data.buyerRequest;
  await pool.query(`INSERT INTO sell_requests
    (estate_owner_id, buyer_request_id, product_type, quantity, seller_price_per_unit, status)
    VALUES ($1, $2, 'RAW_COCONUT', 100, 120, 'accepted')`, [estateId, request.id]);
  await pool.query(`INSERT INTO orders (listing_id, buyer_request_id, status, buyer_rating, owner_rating)
    VALUES ($1, $2, 'COMPLETED', 5, 1)`, [listing.id, request.id]);
  await pool.query(`INSERT INTO orders (buyer_request_id, status, buyer_rating)
    VALUES ($1, 'COMPLETED', 3)`, [request.id]);
  for (const [status, rating] of [['COMPLETED', null], ['CANCELLED', 1], ['AWAITING_RECEIPT', 1]]) {
    await pool.query('INSERT INTO orders (listing_id, status, buyer_rating) VALUES ($1, $2, $3)',
      [listing.id, status, rating]);
  }
  const result = await summary();
  assert.equal(result.average_rating, 4);
  assert.equal(result.rating_count, 2, 'each rated order counts once; owner-given ratings do not count');
  assert.notEqual(result.estate.id, (await call('GET', '/api/owner/summary', {token: owner.token})).data.estate.id);
});

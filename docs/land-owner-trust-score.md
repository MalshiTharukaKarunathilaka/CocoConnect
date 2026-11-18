# Land owner Trust Score

The profile uses `GET /api/owner/summary`. The server reads received ratings from persisted completed work, returning `average_rating`, `rating_count`, and `rating_sources`.

Score = sum of every eligible received star rating / number of eligible ratings.
Every individual rating has equal weight. Do not average the four workflow averages. An unrated workflow is excluded rather than counted as zero. The score is null when there are no ratings; the UI shows "Not rated yet". Display rounding is one decimal place only.

| Workflow | Who rates the land owner | Eligibility |
| --- | --- | --- |
| Coconut sales, including raw, dehusked, and husks | Buyer | Completed order after collection confirmation; `orders.buyer_rating` |
| Day jobs | Accepted worker | Completed day job; `day_job_applications.estate_owner_rating` |
| Machinery | Booked provider | Confirmed booking after its scheduled end; provider explicitly completes and rates it once |
| Fertilizer | Assigned supplier or CDO | Backend order marked delivered; one land owner rating per order |

The land owner's ratings of other people are excluded. Accounts cannot submit machinery or fertilizer feedback on another provider's orders, or rate themselves. Cancelled work and unrated work do not count. Both listing sales and accepted offers on buyer requests count, without duplicating an order.

## Fertilizer persistence

New orders select a registered supplier/CDO and are saved to PostgreSQL. Owners see their orders under My fertilizer orders. Suppliers see assigned orders under Pending & jobs; CDOs see them under Pending requests / Distribution. Suppliers accept, mark delivered, then rate the land owner. Refresh retrieves the persisted state. Government applications store the attached identity and land title images with the order, visible only to its participants through the API.

Old in-memory demo orders are not migrated or counted because they do not establish real account ownership. The catalogue, demo stock/calendar and regional oversight remain separate from persistent order feedback.

## Database setup

Run `node backend/scripts/apply-land-owner-rating-schema.js` from the repository root to apply the two additive, repeatable migrations (015 and 016). Existing orders and day jobs use their previously installed rating columns. The script wraps the new schema changes in one transaction.

## Refresh

Opening the land owner profile fetches current totals. Pull down on the profile to refresh after a counterpart submits a rating. A new rating never requires a manual score recalculation or backfill.

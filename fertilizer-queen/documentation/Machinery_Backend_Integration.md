# Machinery backend integration — review and activation

## Authentication

The project keeps its existing real phone/password authentication: bcrypt hashes in `public.users`, JWT sign-in sessions, `/api/auth/me` restoration, and role/ownership checks in Express. Supabase continues to host PostgreSQL. Supabase Auth is a separate optional managed authentication product; migrating would change the shared Buyer/Estate Owner authentication and identifiers and is not required for this work.

Normal provider home now uses `LiveProviderCalendarRepository`. `preview_provider.dart` explicitly opts into the isolated preview repository. There is no fallback from a failed live API call to invented bookings or prices.

## Database migrations approved and applied ? 2026-11-12

Applied to hosted Supabase in this order after explicit approval:

1. `backend/sql/009_machinery_workflow.sql`
2. `backend/sql/010_machinery_overlap_constraint.sql`

009 adds machines, service rates, availability, booking headers, immutable service/price snapshots, and negotiation messages. It links machines to the existing provider profile and bookings to the authenticated Estate Owner. It creates the first inventory record from each existing profile's valid machinery type; it does not invent prices, bookings, ratings or messages. Existing users, marketplace tables and day jobs are preserved. RLS keeps the new tables out of anonymous Supabase Data API access; the existing Node database connection enforces participant authorization.

010 enables btree_gist and adds a partial GiST exclusion constraint for CONFIRMED bookings using half-open `[start,end)` time ranges. Adjacent jobs are allowed; concurrent overlapping confirmations for the same physical machine are not. The API also locks the machine row before availability changes and confirmation, so maintenance and booking actions serialize.

Both approved migrations committed together in one hosted transaction on 2026-11-12. An initial file-encoding attempt rolled back fully; the SQL files were normalized to UTF-8 without BOM before the successful retry. The memory test loader skips 010 because pg-mem cannot implement PostgreSQL exclusion constraints. Passing memory tests does not constitute a real PostgreSQL concurrency stress test.

## Real workflow

1. Start the persistent backend with `npm.cmd run dev:supabase` from `backend` after applying the approved schema.
2. Start the normal Flutter app (`flutter run`), not the preview entry point.
3. Register or sign in as a Service Provider.
4. Calendar -> select/add machinery -> add service rates. Prices are explicitly entered by the provider, not seeded by the app.
5. Save available/unavailable dates or block/reopen a maintenance date. Confirmed bookings cannot be invalidated by blocking their date.
6. Sign in as an Estate Owner in another device/browser session.
7. Open the existing Machinery map. It loads registered machines with real services/rates. Unknown locations are not fabricated, and the map does not invent travel times or ratings.
8. Select a machine and its existing schedule screen, choose services/quantities/date, then request a booking with explicit start and end times and estate/address. An optional offer applies to the entire multi-service booking.
9. The provider calendar polls every 20 seconds while visible and also has manual refresh. Select the request date to open inquiry and negotiation.
10. Messages and structured counteroffers are saved through JWT-protected APIs. The proposal is not treated as agreed until the other party accepts it. Mixed-service offers use a booking total; single-service rates display in the appropriate unit.
11. Only the assigned provider can confirm/decline. Confirmation validates version, current availability and interval conflicts, and stores the agreed total.
12. The owner's existing My Bookings screen reads the same records. Cancellation by the requesting owner releases a future confirmed interval. Past requests are not falsely labeled completed just because their date passed.

The request page polls every 15 seconds, preserves typed text, rejects stale mutation versions and refreshes after conflicts. Preview-only simulated-customer controls never appear in the live route.

## API contracts

All `/api/machinery` routes require the existing Bearer JWT.

- GET `/catalog`
- GET/POST `/provider/machines` (provider)
- PUT `/provider/machines/:id/rates` (owner of machine)
- GET `/provider/machines/:id/calendar?month=YYYY-MM` (owner of machine)
- PUT `/provider/machines/:id/availability` (owner of machine)
- GET `/machines` (Estate Owner)
- GET `/machines/:id/calendar?month=YYYY-MM` (Estate Owner; reserved intervals only, no other customer identity)
- POST `/machines/:id/bookings` (Estate Owner)
- GET `/bookings` (requesting Estate Owner)
- GET `/bookings/:id` (assigned provider or requesting owner)
- POST `/bookings/:id/messages`, `/agree` (participants)
- POST `/bookings/:id/accept`, `/decline` (assigned provider)
- POST `/bookings/:id/cancel` (requesting owner)

Mutations of existing bookings require `expected_version`. Message counteroffers use `offer_total`. Booking creation accepts a stable machine ID and service IDs; client-supplied rates/owner IDs are not trusted. Snapshot prices remain unchanged when catalogue rates are edited.

## Files and suggested commit groups

- Backend/database: `backend/controllers/machineryController.js`, `backend/routes/machineryRoutes.js`, `backend/server.js`, SQL 009/010, `backend/test/memoryDb.js`, `backend/test/machinery.test.js`.
  Suggested commit: `feat(machinery): persist authenticated bookings and negotiations`
- Provider rates/availability/live API: `lib/services/machinery_api.dart`, `lib/services/provider_calendar_repository.dart`, `lib/models/provider_calendar.dart`, `lib/models/provider_booking_request.dart`, `lib/screens/provider/`, `preview_provider.dart`.
  Suggested commit: `feat(provider): connect calendar rates and bookings to backend`
- Minimal Estate Owner adapters: `lib/widgets/machinery_widgets.dart`, `lib/screens/machinery_map_page.dart`, `lib/screens/service_schedule_page.dart`, `lib/screens/live_machinery_booking.dart`, `lib/screens/my_bookings_page.dart`, numeric-price compatibility in `lib/screens/machinery_negotiation_page.dart`.
  Suggested commit: `feat(machinery): connect existing owner screens to shared requests`
- `test/live_machinery_test.dart` and this documentation.
  Suggested commit: `test(machinery): verify authenticated live UI and API workflow`

These changes remain uncommitted on `machinery-service-provider-malshi`. Earlier registration changes and original working edits are preserved.

## Executed validation and hosted status

- Full backend suite: 46 passed, including seven authenticated machinery integration scenarios against the disposable test database.
- Full Flutter suite: 35 passed, including live API adapter, expired-session cleanup, real-page absence of simulated customer controls, owner price agreement, rate saving and availability saving.
- Analysis of affected Dart files: no issues. Repository-wide analysis still reports the pre-existing unused import in coconuts_page.dart and print warning in api_service.dart.
- The pre-activation read-only review found no conflicting machinery tables. btree_gist is now installed by the approved migration.
- Hosted SQL 009/010 committed successfully. All six workflow tables have RLS enabled, and PostgreSQL reports the overlap exclusion constraint as validated. A production concurrency stress test was not performed; no live test accounts or bookings were inserted.
- No commits, pushes, merges or rebases were performed.

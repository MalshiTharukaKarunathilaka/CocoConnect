> Historical UI milestone. The normal app now has a live backend adapter; see Machinery_Backend_Integration.md for activation and current behavior. The explicit preview entry point still follows the preview flow described below.

﻿# Machinery provider — Features 2 and 3

All work remains on `machinery-service-provider-malshi`. These are interactive UI previews; no backend booking APIs or Supabase migrations were changed.

## Try the complete preview

```powershell
flutter run -t preview_provider.dart
```

Choose day **6** or **16** in any displayed month. Day 6 has two sample requests: use Previous/Next Request in the Date Inquiry sheet to inspect each. Select **Review & Respond to Request** to open negotiation.

- Read customer, machinery/service, quantity, unit, schedule, offer and total.
- Send messages and update a counteroffer without deleting earlier messages.
- After a counteroffer, locking is disabled until the customer agrees. The explicit **Preview: customer accepts offer** control simulates that event locally; there are no automatic fake replies.
- Accept & Lock Booking asks for preview confirmation, reserves that request's interval in the preview, returns to the calendar, and updates counts.
- A second overlapping booking for the same preview machine is rejected. Adjacent bookings remain possible. This is client-side preview behavior, not production concurrency protection.
- Decline asks for confirmation and updates incoming counts without blocking the date.
- Tap a confirmed request date to reopen the booking/history.
- State survives month navigation within the calendar visit. Reloading/restarting discards it.
- Customer contact opens a number dialog with Copy Number; it does not place a call. All fixture contact details and locations are labeled as sample data.
- The map uses the existing OpenStreetMap stack. Distance is calculated from the supplied coordinates and labeled straight-line distance. No routing ETA, request-expiration timer, invented rating, or advance-payment guarantee is shown.

Live shared owner/provider requests, backend validation, database-level locking, and production persistence remain Feature 6. No owner is contacted or notified by this preview.

## Feature 2: Date inquiry

- `lib/models/provider_booking_request.dart` — request data and local preview transitions shared with Feature 3.
- `lib/models/provider_calendar.dart` — request-aware day counts and date keys.
- `lib/services/provider_calendar_repository.dart` — isolated sample requests.
- `lib/screens/provider/provider_booking_inquiry.dart` — scrollable inquiry sheet with multiple-request navigation.
- `lib/screens/provider/provider_request_widgets.dart` — customer/contact/date/quantity display shared with Feature 3.
- `lib/screens/provider/provider_calendar_page.dart` — date and Requests-tab entry points, month cache, refreshed counts.
- `test/provider_calendar_test.dart` — existing tests now dismiss inquiry before checking calendar panels.

Suggested commit: `feat(provider): add calendar booking inquiry`

## Feature 3: Request and negotiation

- `lib/screens/provider/provider_request_page.dart` — map, request details, conversation, counteroffer form, preview agreement and accept/decline actions.
- Shared request model/widgets and calendar navigation listed above.
- `test/provider_requests_test.dart` — model and widget workflow checks.

Suggested commit: `feat(provider): add service request negotiation preview`

Both features are provided together as requested. Their shared model, calendar route changes and tests need staged review when splitting commits; nothing has been staged or committed automatically. A combined commit alternative is `feat(provider): add booking inquiry and negotiation preview`.

This documentation file and `documentation/Machinery_Provider_Run_Guide.md` also describe the current preview.

## Executed validation

- 20 provider workflow, calendar and registration tests passed together.
- Tests include multiple requests per date, inquiry-to-detail navigation, counteroffer agreement, message history, preview slot conflicts, adjacent intervals, acceptance/calendar refresh, decline/calendar refresh, and mobile layouts.
- Dart analysis of affected provider source and tests: no issues.
- No backend code, hosted database, commit or push was changed during Features 2 and 3.

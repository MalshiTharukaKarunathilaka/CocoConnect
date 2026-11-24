# Machinery provider — Feature 1

Branch: `machinery-service-provider-malshi`, based on Senuji's integration commit `e41b694`.

## Review this feature

```powershell
flutter run -t preview_provider.dart
```

This entry point opens the mobile calendar without logging in or connecting to Supabase. Normal Service Provider login also opens the calendar. Buyer and Estate Owner routing is preserved.

The preview includes month navigation, day selection, booking/availability indicators, rates, a selected-day panel, and provider bottom navigation. Dashboard summarizes the displayed month; Requests lists incoming dates and returns to the chosen calendar date; Profile shows the logged-in account and logout.

All sample bookings and prices are confined to `PreviewProviderCalendarRepository`. The persistent banner identifies this data as sample data. Availability toggles create drafts only for the current visit. Save, Edit Rate, Add Service, and Maintenance actions are disabled until their later feature implementations. No success message claims a database save. Past dates, maintenance dates, and fully booked dates cannot be toggled. Inquiry sheets and negotiations are Feature 2 and Feature 3.

## Feature 1 files

- `lib/screens/auth_gate.dart` — provider home routing.
- `lib/screens/provider/provider_calendar_page.dart` — calendar and mobile provider shell.
- `lib/models/provider_calendar.dart` — calendar view data and Sri Lanka date helpers.
- `lib/services/provider_calendar_repository.dart` — injectable read interface and isolated preview data.
- `preview_provider.dart` — development preview entry point.
- `test/provider_calendar_test.dart` — widget and routing checks.
- `documentation/Machinery_Provider_Feature_1.md` — feature scope and review commands.

Suggested commit message: `feat(provider): add machinery availability calendar`

These paths form the Feature 1 commit boundary. Existing registration, backend, platform, main.dart, and other uncommitted work were present before this feature and should be reviewed separately. No commit or push has been made.

## Validation commands

```powershell
flutter test --no-pub test/provider_calendar_test.dart
npm.cmd test --prefix backend
dart analyze lib/models/provider_calendar.dart lib/services/provider_calendar_repository.dart lib/screens/provider/provider_calendar_page.dart lib/screens/auth_gate.dart preview_provider.dart test/provider_calendar_test.dart
```

Tests cover leap years and year rollover, selected-date booking counts, draft/reset behavior, disabled saving, past/fully-booked protection, loading/error/retry/empty states, tabs, and layouts at 320 and 360 px with 130% text scaling.

Set `PROVIDER_SCREENSHOT=1` while running widget tests to write `build/provider_calendar_preview.png`. This generated preview is not part of the commit.

## Preservation

Original working changes were backed up to:
`C:\Users\User\AppData\Local\Temp\kapconnect-before-provider-20261112-152543.zip`

The stash named `Preserve working changes before machinery provider branch` is also retained. Senuji's local integration branch remains at its original commit; only the remote-tracking ref was fetched. No production database connection or migration was executed.

## Executed results

- Calendar/routing widget suite: 10 passed.
- Existing backend suite (in-memory database): 35 passed.
- Dart analysis of Feature 1 files: no issues.
- Repository-wide analysis: two pre-existing findings remain: an unused import in `lib/screens/coconuts_page.dart` and `avoid_print` in `lib/services/api_service.dart`.
- Original working files: all 17 verified byte-for-byte against the backup after restoration.
- No production SQL or database operation was performed.

# Run machinery provider registration with Supabase

## Persistent registration (recommended)

The backend writes custom login accounts to **Table Editor -> public.users** and machinery profiles to **public.service_providers**. The profile's `user_id` references the account's `id`. This project uses Node/JWT authentication, so these accounts do **not** appear in Supabase's **Authentication -> Users** screen.

From the project root, start the backend in PowerShell:

```powershell
cd backend
npm.cmd run dev:supabase
```

For running without the file watcher:

```powershell
npm.cmd run start:supabase
```

These commands explicitly select the persistent database configured in `backend/.env`, even if a shell has DB_MODE=memory set. They fail if DATABASE_URL or JWT_SECRET is missing. Never share or commit that file.

Both required hosted tables were verified to exist with read-only checks. No hosted migration or test account was created during the persistence fix.

Check http://localhost:5000/api/health. Persistent mode should report:

```json
{"storage":{"mode":"postgres","persistent":true},"provider_registration_ready":true}
```

The registration page now shows **Connected to shared database. Your account will be saved.** when the backend and registration tables are ready. An unavailable connection or missing registration setup is reported before signup.

## Flutter

Use a second terminal at the project root:

```powershell
flutter run
```

For Chrome on this computer:

```powershell
flutter run -d chrome
```

For Windows desktop:

```powershell
flutter run -d windows --dart-define=API_URL=http://localhost:5000
```

Android emulators use `http://10.0.2.2:5000` by default. A physical phone needs the computer's reachable LAN address via `--dart-define=API_URL=http://YOUR_PC_LAN_IP:5000`.

Open Sign Up -> Service Provider, fill Machinery registration, choose Tractor/Backhoe/Hand Tractor, pick a district and map/GPS base, accept the agreement, and register. Then inspect both public tables in the correct Supabase project. Phone numbers are stored in local format, e.g. 0771234567.

Map tiles and place search require internet. GPS requires location permission; the map picker is an alternative.

## Optional disposable preview backend

```powershell
cd backend
npm.cmd run dev:memory
```

This command creates **temporary in-memory accounts only**. It never saves accounts to Supabase; all accounts disappear when this backend restarts. Its registration page displays a warning and labels the submit button **Create Temporary Account**.

Previously created temporary accounts cannot be moved automatically after their process ends. Register again with the persistent backend. A saved browser token from a discarded preview account may require logging out and registering again.

The normal signed-in provider calendar, rates, availability and request pages now use authenticated backend APIs. The existing Estate Owner machinery screens use the same booking records. SQL migrations 009 and 010 were approved and applied to hosted Supabase on 2026-11-12; see Machinery_Backend_Integration.md. Only preview_provider.dart continues to use sample data.

To open only those calendar screens without a backend:

```powershell
flutter run -t preview_provider.dart
```

Choose day 6 or 16 and select Review & Respond to Request. See `Machinery_Provider_Features_2_3.md` for details.

## Registration validation

The long form keeps off-screen sections mounted, validates all fields, reveals the first error, and displays server field errors inline. Identity/email length constraints match the backend; phone numbers accept normal Sri Lankan local/international formats.

## Persistence fix files

- `backend/config/usePersistentDb.js`: explicit persistent-mode startup.
- `backend/config/db.js`: stable .env path and storage mode metadata.
- `backend/controllers/healthController.js`: credential-free storage/readiness endpoint.
- `backend/controllers/authController.js`: signup storage metadata and clear missing-table failure.
- `backend/server.js`: health route and stable .env loading.
- `backend/package.json`: dev:supabase/start:supabase scripts.
- `lib/services/auth_service.dart`: registration storage response model/client.
- `lib/screens/service_provider_registration_page.dart`: persistent/temporary notices and readiness check.
- Backend and registration tests plus this guide.

Suggested commit: `fix(provider): distinguish temporary accounts and enable explicit Supabase registration`

No production migration, automatic commit or push was performed.


## Hosted machinery activation ? 2026-11-12

SQL 009 and 010 are now applied. `/api/health` reports `machinery_workflow_ready` as well as registration readiness and persistence. The backend was restarted with the real machinery routes. Use the normal Flutter entry point (`flutter run`), sign in as a provider, add/select machinery and save service rates. Owners can then request it from the existing machinery map/schedule. No sample bookings, accounts or prices were inserted into the hosted database. The PostgreSQL exclusion constraint was verified as validated; no live concurrency stress test was performed.

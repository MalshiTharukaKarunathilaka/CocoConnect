# CocoConnect Admin Web

React admin dashboard for CocoConnect. Talks to the shared Node backend on port **5000** (same API the Flutter app uses).

## Run

1. Start the backend (from repo root):

```bash
cd backend
npm install
# create .env from .env.example (never commit secrets)
npm run dev
```

2. Start admin web:

```bash
cd admin-web
npm install
npm run dev
```

Open http://127.0.0.1:5174

## Admin login

Use a user with `role = 'ADMIN'`. Signup from the Flutter app cannot create admins — promote in Supabase:

```sql
update public.users
set role = 'ADMIN', status = 'ACTIVE'
where phone = '07XXXXXXXX';
```

Then sign in on the admin web with that phone and password.

## First-time DB columns

If admin screens error on missing columns, run (once) in Supabase SQL editor:

`backend/sql/008_admin_extensions.sql`

## What this covers

- Dashboard, Users, Verification
- Orders (buy requests + listings)
- **Deal** (negotiations + chat)
- Transactions, Disputes (Low / Medium / High)
- Regions & prices (editable band + publish)
- Reports & settings

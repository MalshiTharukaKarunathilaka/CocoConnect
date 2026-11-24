# How to get `admin-ibrahim` onto the team repo

Your machine has branch **admin-ibrahim** ready (commit includes admin-web + expanded admin API).

GitHub returned **403** for push to `MalshiTharukaKarunathilaka/CocoConnect` because your account `ibrahim794` is not a collaborator yet.

## Option A (best) — ask Malshi for write access

1. Ask Malshi to add **ibrahim794** as a collaborator on CocoConnect.
2. Then run:

```bash
cd CocoConnect
git checkout admin-ibrahim
git push -u origin admin-ibrahim
```

3. Open a Pull Request: **base** `integration-senuji` ← **compare** `admin-ibrahim`

## Option B — fork + PR

1. Open https://github.com/MalshiTharukaKarunathilaka/CocoConnect and click **Fork**.
2. Then:

```bash
cd CocoConnect
git remote add fork https://github.com/ibrahim794/CocoConnect.git
git push -u fork admin-ibrahim
```

3. Open a PR from `ibrahim794:admin-ibrahim` into `MalshiTharukaKarunathilaka:integration-senuji`.

## After merge — teammates use admin

```bash
cd backend && npm run dev
cd admin-web && npm install && npm run dev
```

Admin login (already created on shared DB for local testing):

- Phone: `0700000001`
- Password: `admin123`

Or promote any phone:

```sql
update public.users set role = 'ADMIN', status = 'ACTIVE' where phone = '07XXXXXXXX';
```

Run once if needed: `backend/sql/008_admin_extensions.sql` in Supabase SQL editor.

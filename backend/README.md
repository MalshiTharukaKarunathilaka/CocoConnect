# KapConnect API (Node.js + Express)

REST backend for Flutter mobile + React admin (matches the written proposal stack).

Base URL: `http://localhost:8080/api/v1`

## Stack

| Layer | Tech |
|-------|------|
| API | Node.js + Express |
| ORM | Prisma |
| DB (local) | SQLite file (easy start) |
| DB (proposal / prod) | PostgreSQL via Docker |
| Auth | JWT + OTP (`123456`) |
| Push | Firebase stub (ready for real keys) |

## Run (Windows)

Double-click **`start-api.bat`**

Or:

```bash
npm install
npm run setup
npm run dev
```

Health: http://localhost:8080/api/v1/health

### Demo phones (OTP = `123456`)

| Role | Phone |
|------|-------|
| Admin | `0700000000` |
| Buyer | `0771234567` |
| Estate | `0715550199` |

## Switch to PostgreSQL

1. `docker compose up -d` (from repo root)
2. In `.env` set:
   `DATABASE_URL="postgresql://kapconnect:kapconnect@localhost:5432/kapconnect"`
3. In `prisma/schema.prisma` change `provider = "postgresql"`
4. Run `npx prisma db push && npm run db:seed`

## Old Spring Boot API

The previous Java API is still in `../kapconnect-api/` for reference.
This Express folder is now the main backend.

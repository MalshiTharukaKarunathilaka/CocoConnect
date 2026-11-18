# KapConnect

Simple coconut marketplace demo.

## Folder guide (only these matter)

| Folder / file | What it is |
|---|---|
| `backend/` | Node.js + Express API |
| `kapconnect-web/` | React website (Buyer / Estate / Admin) |
| `client-docs/` | Client PDF + wireframes (reference only) |
| `start-kapconnect-system.bat` | Starts API + website together |
| `docker-compose.yml` | Optional PostgreSQL |
| `SHARE-WITH-FRIENDS.md` | How to share on GitHub |

## Run

Double-click `start-kapconnect-system.bat`

- Website: http://127.0.0.1:5173
- API: http://localhost:8080/api/v1/health
- Demo OTP: `123456`

| Role | Phone |
|------|-------|
| Buyer | 0771234567 |
| Estate | 0715550199 |
| Admin | 0700000000 |

## Stack

- Mobile/admin UI (for now): React
- API: Node.js + Express
- DB: SQLite locally (PostgreSQL ready)
- Push: Firebase stub
- Final mobile app later: Flutter

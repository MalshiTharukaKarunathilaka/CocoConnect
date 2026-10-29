# Running CocoConnect

The app has two parts, both in this repository on branch `integration-senuji`:

- **Mobile app** (Flutter) — the project root (`lib/`, `pubspec.yaml`)
- **Backend** (Node.js + Express) — the `backend/` folder, connected to the team's Supabase database

The backend must be running for the app to log in or load any data.

---

## 1. Install once

| Tool | Version | Check with |
|---|---|---|
| Flutter | **3.44 or newer** (Dart 3.12+) | `flutter --version` |
| Node.js | 18 or newer | `node -v` |
| Android Studio | any recent version, with an Android emulator | — |
| Git | any | `git --version` |

> Older Flutter versions fail with "The current Dart SDK version is ... because kapconnect_mobile requires SDK version ^3.12.2". Run `flutter upgrade`.

## 2. Get the code

```bash
git clone https://github.com/MalshiTharukaKarunathilaka/CocoConnect.git
cd CocoConnect
git checkout integration-senuji
```

Already cloned? Instead run:

```bash
git fetch
git checkout integration-senuji
git pull
```

## 3. Set up the backend (once)

```bash
cd backend
npm install
```

Create a file named **`.env`** inside `backend/` (copy `.env.example`) and fill it in:

```
PORT=5000
DATABASE_URL=<ask the team for the Supabase connection string>
DATABASE_SSL=true
JWT_SECRET=<any long random text, e.g. 40 random letters and numbers>
```

- The `DATABASE_URL` contains the database password. **Get it privately from the team** — never put it in GitHub, screenshots or group chats.
- `.env` is ignored by Git, so it stays on your computer only.

## 4. Run it (every time)

**Terminal 1 — backend**

```bash
cd backend
npm run dev
```

Wait for `Server running on port 5000`. Check it in a browser: <http://localhost:5000/api-docs> lists every API route.

**Terminal 2 — app**

Start the Android emulator first (Android Studio → Device Manager → ▶), then:

```bash
flutter pub get
flutter run
```

## 5. Log in

The app opens on **Login**. Tap **Sign Up** to create an account and pick your role:

| Role | Opens |
|---|---|
| **Buyer** | Buying Categories → marketplace, requests, negotiations, orders |
| **Estate Owner** | Estate owner dashboard → listings, buyer requests, chats, orders |
| Estate Manager / Service Provider | Not built yet (login works, no screens) |

Use your own phone number — everyone shares one database, so each account must be unique.

Estate owners: open **Profile → Edit Estate** to set your estate name, location, land area and crop. Buyers see the estate name and location.

---

## Trying things without touching the shared database

To test freely (sign-ups, orders, chats) without adding rows to Supabase, use the built-in test database. It starts with sample estates and listings and is wiped when the server stops.

```bash
# Terminal 1
cd backend
npm run dev:memory

# Terminal 2
flutter run --dart-define=API_URL=http://10.0.2.2:5000
```

Sign up again each time — the test database starts with no accounts.

Backend automated tests (also use the test database):

```bash
cd backend
npm test
```

## Running on a real phone

`10.0.2.2` only works on the emulator. On a phone connected to the same Wi‑Fi as your computer, use the computer's IP address (find it with `ipconfig`):

```bash
flutter run --dart-define=API_URL=http://192.168.1.25:5000
```

## Common problems

| Problem | Fix |
|---|---|
| App says "Can't reach the server. Is the backend running?" | Start the backend (step 4, Terminal 1) and pull down to refresh |
| Backend says `password authentication failed` or `ENOTFOUND` | `DATABASE_URL` in `backend/.env` is wrong — ask the team again |
| `flutter run` says "No supported devices" | Start the emulator first and wait for its home screen |
| Windows: `flutter` prints nothing and exits | Run `flutter.bat` instead, or add Flutter's `bin` folder to PATH |
| Android build fails with "different roots" | Already fixed in `android/gradle.properties` — make sure you pulled the latest code |
| Can't type in the emulator | Click inside the emulator window first; or enable "hardware keyboard" in the emulator's AVD settings |
| After `flutter pub get`, Git shows changed files under `linux/`, `macos/`, `windows/` | Only commit them if you added a package |

## Database changes (already done — for reference)

The SQL scripts in `backend/sql/` have already been run on the shared Supabase database. Don't run them again unless setting up a **new** database. They only add tables and columns; they never remove anything.

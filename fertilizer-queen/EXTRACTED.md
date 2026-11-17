# fertilizer-queen (extracted)

This folder was copied from the CocoConnect GitHub branch
[`fertilizer_queen`](https://github.com/MalshiTharukaKarunathilaka/CocoConnect/tree/fertilizer_queen).

## Why this exists

So you can open the fertilizer feature in a browser without checking out that whole remote branch yourself.

## Run in the browser

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd fertilizer-queen
flutter pub get
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=8080 -t lib/demo_combo_app.dart
```

Then open: http://localhost:8080

### Demo logins

Password for all roles: **demo123**

Pick a role on the first screen (Estate Owner, Supplier, CDO, etc.).

### Other entry points

- `lib/demo_combo_app.dart` — fertilizer role login (recommended)
- `lib/demo_fertilizer.dart` — skips login, opens fertilizer map
- `lib/main.dart` — full KapConnect app

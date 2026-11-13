# KapConnect (worker app) - Flutter

## Run

This folder contains `lib/`, `pubspec.yaml` and a test. Generate the platform
folders (android/, ios/ ...) once, then run:

```
flutter create --project-name kapconnect --org lk.kapconnect .
flutter pub get
flutter run
```

`flutter create .` keeps the existing `lib/`, `pubspec.yaml` and `test/` files.
If it asks or overwrites `lib/main.dart`, restore it from this archive.

Requires Flutter 3.22+ (Dart 3.3+). Check your setup with `flutter doctor`.

## Flow

1. **Dashboard** - tap a day on the calendar (green dot = jobs available, orange = you have a booked job, red = holiday).
2. **Jobs for the Day** - estates that published jobs for that day (filter by category).
3. **Job details** - jobs of the estate. Accept / Decline / Negotiate.
4. **Negotiation** - chat with the estate owner (owner replies are simulated).
5. **Job accepted!** - confirmation; "Okay" returns to the dashboard.

## Rules (lib/state/jobs_state.dart)

- Only one accepted job per day. Trying to accept another shows the "Already accepted another job" pop-up.
- Only a job you accepted can be declined; only jobs you have not accepted can be accepted.
- Negotiate is available before and after accepting.
- Full jobs cannot be accepted.

## Structure

```
lib/
  main.dart            app entry, providers
  theme.dart           colours, shadows, money()
  models.dart          Estate, Job, Worker, chat models
  data/mock_data.dart  estates, jobs, holidays, date helpers
  state/jobs_state.dart  JobsState (rules) + AppNav (tabs)
  screens/             dashboard, day estates, job details,
                       negotiation, confirmation, my jobs, shell
  widgets/             calendar, job card, dialog, shared UI
```

Mock data lives in `lib/data/mock_data.dart`. The map is a placeholder card;
swap it for `google_maps_flutter` or `flutter_map` when ready.

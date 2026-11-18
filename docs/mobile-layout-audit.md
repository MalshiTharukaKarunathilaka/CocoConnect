# Mobile layout audit

## Scope

The completion/cancellation/rating workflow proposals remain pending client confirmation. This change concerns layout and keyboard behaviour.

The regression suite exercises 67 page/view configurations at 320, 360 and 412 logical pixels wide, with 640-pixel height, top/bottom safe-area padding and 1.3x text. Ten chat/form configurations are also exercised with a 260-pixel keyboard at each width. Eleven popup types are tested across three viewport/keyboard configurations. Worker, fertilizer supplier/CDO and administrator navigation adds 44 checks. Six Orders-tab checks verify tap targets and visibility at normal and 1.5x text without horizontal scrolling.

These are 314 targeted layout checks using representative account data and mocked HTTP responses. They check rendered overflow and constrained layout; they do not constitute a physical-device test or exhaustive verification of every possible record, translation, image or accessibility setting.

## Changes

- Orders and other shared tabs, distance filters, sort controls, machine selectors and quick actions wrap within available width instead of requiring horizontal swiping.
- Shared headers, buttons, labels and currency totals use flexible width; summary cards and calendar indicators allow larger text.
- All app AlertDialogs allow vertical scrolling for lengthy content. Bottom sheets use safe areas, usable viewport height and a shared keyboard-inset wrapper without applying keyboard padding twice.
- Fertilizer filters, cart/edit forms and applications scroll vertically on short screens. Calendar/map controls and attribution stay within phone width.
- Machinery and fertilizer chat quick replies collapse while the keyboard is open; composers remain available. Long machinery summaries scroll with the conversation.
- Buyer coconut-category cards use a vertical list on short screens. Administrative request and distribution tables become labelled cards below 700 pixels.

## Validation

All 421 Flutter tests passed, including the 314 targeted layout checks. Static analysis found no errors; existing application lint notices remain. The new layout test files have no analysis issues.

## Android demo

Flutter sizes these widgets using logical pixels and available constraints. The main shared phone frames shrink for narrower screens and cap their width on wider displays. The Android manifest already includes Internet permission and `adjustResize` for the keyboard.

Test both actual phones before the demonstration. When the backend runs on the computer, both physical phones must reach that computer. For a native Android demo on the same Wi-Fi, build/run with:

```text
flutter run -d <device-id> --dart-define=API_URL=http://<computer-LAN-IP>:5000
```

Use the same backend for both accounts. The default `10.0.2.2` address is intended for an Android emulator. A browser demo likewise needs a LAN-accessible web server and backend URL; `127.0.0.1` on a phone refers to the phone itself.

## Reminder

A Windows task named `CocoConnect-Client-Workflows-20261118-0900` is scheduled for 18 November 2026 at 9:00 AM Sri Lanka time. It displays the workflow follow-up message on the signed-in computer, with StartWhenAvailable enabled. Keep the computer on and signed in for the scheduled time.

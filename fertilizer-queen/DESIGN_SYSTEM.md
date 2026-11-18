# CocoConnect Design System

One look for every part of CocoConnect: the admin web app, the buyer app, the estate-owner app and the service-provider screens. If you build a screen, take its colours, type, shapes and components from this file instead of picking your own. That is what keeps the app feeling like one product.

- **Source of truth for the web:** `admin-web/src/analysis/analysis.css` (tokens at the top) and `admin-web/src/AdminApp.css`.
- **Source of truth for Flutter:** the `AppColors` / `AppTheme` code in section 11. Put it in `lib/theme/app_theme.dart` and import it everywhere.
- **Brand feel:** natural, calm and agricultural. Deep coconut-leaf green on warm cream, with coconut-husk brown and a sunny gold accent. Rounded, soft, never harsh.

---

## 1. Colour

### 1.1 Brand colours

| Token | Hex | Use |
|---|---|---|
| `green` (primary) | `#256B45` | Primary buttons, active tabs and nav, links, key numbers, selected map areas |
| `greenSoft` | `#E3F0E6` | Tonal buttons, selected-row tint, icon backgrounds, "good" banners |
| `greenMid` | `#5FA47B` | Secondary data colour, progress fills, second chart series |
| `greenLight` | `#9FD0B0` | Third tint, lowest chart bands |
| `brown` | `#8B4A1C` | Secondary brand colour: icons, machinery, headings of "earth" sections |
| `gold` | `#D9A441` | Accent only: count badges, highlights, "today" style callouts, the gold end of gradients |

### 1.2 Neutrals

| Token | Hex | Use |
|---|---|---|
| `ink` | `#1E2A22` | Main text (never pure black) |
| `muted` | `#6B7280` | Secondary text, captions, axis labels |
| `line` | `#E5E7EB` | Borders, dividers, input outlines |
| `page` | `#F1EFEA` | App / page background (warm cream) |
| `cream` | `#FCF8EF` | Soft panels and form backgrounds on mobile |
| `surface` | `#FFFFFF` | Cards, sheets, dialogs |

### 1.3 Status colours

| Meaning | Text / icon | Background | Examples |
|---|---|---|---|
| Success | `#256B45` | `#E3F0E6` | Verified, Completed, Accepted, Resolved |
| Warning | `#9A6B12` | `#F7EFDF` | Pending, Negotiating, Payment pending, Open |
| Danger | `#A32820` (text) / `#C62828` (solid) | `#F8EAEA` | Suspended, Rejected, Disputed, Hidden, errors |
| Info | `#2F7396` | `#E4EFF5` | Neutral information, "Western" province |

Use the soft background with coloured text for **status pills**. Use solid `#C62828` only for destructive buttons and error snackbars.

### 1.4 Glass (cards on the cream background)

| Token | Value |
|---|---|
| `glass` | `rgba(255,255,255,0.66)` |
| `glassEdge` | `rgba(255,255,255,0.95)` (1 px border) |
| `shadow` | `0 10px 30px rgba(52,70,56,0.08)` |

On mobile, where blur is expensive, use plain `#FFFFFF` with the same border and shadow. Do not stack glass on glass.

### 1.5 Page background

The web app uses `#F1EFEA` with three soft radial glows: green top-left (`rgba(37,107,69,0.16)`), brown top-right (`rgba(139,74,28,0.11)`) and gold bottom (`rgba(217,164,65,0.16)`). On mobile a flat `#F1EFEA` is fine.

### 1.6 Province colours

Each province has one colour, used on maps, tiles and charts. Always use the same colour for the same province.

| Province | Hex |
|---|---|
| North Western | `#256B45` |
| Western | `#2F7396` |
| Central | `#7A4FB0` |
| Southern | `#D08A1F` |
| Northern | `#C0562B` |
| Eastern | `#1F9E8F` |
| North Central | `#9AA02A` |
| Uva | `#B8467A` |
| Sabaragamuwa | `#5A6B7C` |

Shade inside a province from light to dark to show a value (darker = more). The lightest tint means "no data yet".

### 1.7 Chart palette

Use in this order for categorical series:

`#256B45` · `#5FA47B` · `#D9A441` · `#8B4A1C` · `#3D85A8` · `#7A5C9E` · `#C0562B` · `#8A948E`

Sequential map and heat scales (light → dark):

| Scale | Colours |
|---|---|
| Green (default) | `#E3F0E6` `#BCDCC6` `#86BE9C` `#4F9A6F` `#256B45` |
| Blue | `#E4EFF5` `#BAD7E6` `#86B6CF` `#4F8FB0` `#25607F` |
| Amber | `#FBF0D9` `#F3D9A0` `#E8BB5E` `#CF9526` `#8F610D` |
| Terracotta | `#F6E8DF` `#E8C5AD` `#D49A73` `#B46A3F` `#7D3F1C` |

Rules: never encode meaning by colour alone (add a label or icon), keep at most 6 series on one chart, and keep male = green `#256B45`, female = orange `#D9741A` wherever gender is compared.

### 1.8 Contrast (checked)

| Pair | Ratio | Verdict |
|---|---|---|
| White on green `#256B45` | 6.4 : 1 | Pass |
| Ink on white | 14.9 : 1 | Pass |
| White on brown `#8B4A1C` | 6.8 : 1 | Pass |
| White on red `#C62828` | 5.6 : 1 | Pass |
| Red text on soft red | 6.2 : 1 | Pass |
| Green text on soft green | 5.5 : 1 | Pass |
| Dark brown `#3D2A05` on gold | 6.1 : 1 | Pass |
| Muted `#6B7280` on white | 4.8 : 1 | Pass (small text) |
| Muted on cream page | 4.2 : 1 | Large or medium-weight text only |
| Amber text on soft amber | 4.1 : 1 | Use semi-bold, 12 px or larger |

---

## 2. Typography

**Font family: Sora** (weights 400, 500, 600, 700), with `Segoe UI` / system sans-serif as the fallback.
Web loads it from Google Fonts. On Flutter, add the `google_fonts` package (`GoogleFonts.soraTextTheme()`) or bundle the font files in `assets/fonts`. The mobile app currently uses Arial, so switching to Sora is part of making it consistent.

| Style | Size | Weight | Letter-spacing | Use |
|---|---|---|---|---|
| Page title | 27 px | 700 | -0.03 em | Screen title ("Sales") |
| Section / card title | 16 px | 650 (use 600) | -0.015 em | Card headings |
| Big number (KPI) | 24 px | 650 (use 600) | -0.03 em | Stat values |
| Stat label | 18 px | 700 | -0.02 em | Tile name next to the photo |
| Body | 14 px | 400 | 0 | Paragraphs, table cells, form text |
| Small / helper | 12.5 px | 400 | 0 | Sub-text under titles, captions |
| Micro label | 11 px | 600 | +0.08 em, UPPERCASE | Section labels ("ANALYSIS DASHBOARD") |
| Button | 13–14 px | 600 | 0 | All buttons |

Rules: line height about 1.5 for body and 1.2 for titles; sentence case everywhere except micro labels; numbers use thousands separators (`95,008`), money is `Rs. 1,250.00`, large amounts compact (`Rs. 74.8M`), weights `2398.6 t` or `kg`.

---

## 3. Shape, spacing and depth

### Radius

| Use | Radius |
|---|---|
| Large cards, panels, map cards | 26 px |
| KPI tiles | 24 px |
| Callouts, nested cards | 20 px |
| Inputs, small cards, list items | 12–14 px |
| Buttons, chips, pills, tabs, badges | Fully rounded (999 px / `StadiumBorder`) |
| Photo thumbnails | 18 px |

### Spacing

Use a 4-pt scale: **4 · 8 · 12 · 16 · 20 · 24 · 32**.

- Screen padding: 16 px on mobile (14 px on the web shell).
- Card padding: 20 × 22 px (web) / 16 px (mobile).
- Gap between cards: 12–14 px.
- Gap between a title and its content: 12 px.

### Elevation

| Level | Where | Value |
|---|---|---|
| Card | Cards, tiles | `0 10px 30px rgba(52,70,56,0.08)` |
| Raised / hover | Hovered cards | `0 10px 20px rgba(52,70,56,0.12)` + move up 2 px |
| Primary glow | Active tab, nav item, primary button | `0 8px 18px rgba(37,107,69,0.28)` |
| Photo | Thumbnails | `0 8px 18px rgba(52,70,56,0.22)` |

---

## 4. Buttons

All buttons are **pill-shaped**, 13–14 px, weight 600, with at least a 44 px touch target on mobile.

| Type | Background | Text | Border | Use |
|---|---|---|---|---|
| **Primary** | `#256B45` | White | none | The one main action on a screen (Save, Confirm, Download report) |
| **Tonal** | `#E3F0E6` | `#256B45` | none | Secondary actions ("Open details", "View all") |
| **Outline** | White | `#1E2A22` (or green) | 1 px `#E5E7EB` | Neutral actions (Refresh, Print, Sign out) |
| **Warning** | `#F7EFDF` | `#9A6B12` | none | Risky but reversible (Hide, Flag) |
| **Destructive soft** | `#F8EAEA` | `#A32820` | none | Reject, Suspend |
| **Destructive solid** | `#C62828` | White | none | Final, irreversible confirmations only |

States: hover or pressed brightens or lifts 2 px (`0.15 s`); disabled is 45% opacity with no shadow; loading replaces the label with a small spinner and keeps the width.
Only **one primary button per screen section**. Primary buttons carry the green glow shadow.

---

## 5. Components

### Card
White or glass surface, 1 px `glassEdge` border, 26 px radius, 20 × 22 px padding, card shadow. Header = title (16 px, 600) with an optional 12.5 px muted subtitle underneath and an optional action on the right.

### KPI tile
24 px radius. Top row: a 54 px rounded photo (18 px radius, white 2 px border) with a small 26 px white circular icon overlapping its bottom-right corner, then the label beside it. Below: the big number, then a 12.5 px muted sub-line. The icon colour follows the tone: green (default), amber `#9A6B12`, blue `#2F7396`, brown `#8B4A1C`, purple `#6D4F93`. Clickable tiles lift on hover and show a green outline when selected.

### Chips and segmented control
Pills, 12.5 px. Off: white (`glass`) with a faint shadow. **On: green `#256B45`, white text, green glow.** A segmented control is a row of chips inside one rounded track.

### Tabs
Same as the segmented control, inside a rounded glass bar. Count badges inside a tab use gold.

### Status pill / badge
Rounded, 11–12 px, weight 600, soft background with coloured text (see 1.3). A **count badge** is gold `#D9A441` with dark brown `#3D2A05` text, minimum 18 px wide, fully rounded.

### Navigation
- **Sidebar (web):** floating frosted panel, 26 px radius, 252 px wide. Section labels are micro labels in `#98A29B`. Items are pills; the active one is solid green with white text and the primary glow.
- **Bottom bar (mobile):** white, active item green with a soft green pill behind the icon, inactive `#6B7280`.

### Inputs
White fill (`#F8F6F1` on cream forms), 1 px `#E5E7EB` border, 12 px radius, 14 px text. Focus: 1.5 px green border. Error: red border and a 12 px red message below. Labels sit above the field in 12.5 px, weight 600.

### Insight callout
White glass, 20 px radius, with a 4 px vertical bar on the left that fades from green to gold. Used for the plain-language sentence under a page's key numbers. Bold the key figures.

### Toast / snackbar
Dark ink background, white text, pill or 12 px radius, bottom centre, 2–3 s. Errors use `#C62828`, success uses `#256B45`.

### Tables
No heavy grid. Header row in muted micro-label style, 1 px `#E5E7EB` row dividers, 12 px cell padding, numbers right-aligned.

### Empty and loading
Empty: a small illustration or palm icon, one line of muted text and, if useful, one tonal button. Loading: a green circular spinner (`#256B45`) or soft grey skeleton blocks. Never show a blank screen.

---

## 6. Maps and data visualisation

- Sri Lanka maps use district shapes coloured by province (1.6), with white 1 px borders. Selected area: 3 px `#15201A` outline.
- Pins: a coconut palm for estates, a sack for fertilizer deliveries, tractor / backhoe / hand-tractor badges for machines. A bigger pin means a bigger value.
- Map controls: floating white pill (breadcrumb at top-left, "Street map" at top-right), legend card at bottom-left. Always keep the © OpenStreetMap credit when street tiles are on.
- Drill-down order: **Sri Lanka › Province › District › Region** (regions currently exist for Kurunegala).
- Charts: soft rounded bars with a light drop shadow, no heavy gridlines, labels in muted 11 px, values formatted with the helpers above.
- Always show the **unit** (`Rs.`, `kg`, `t`, `%`) and the **time period** ("2026, Jan–Oct") near the title.
- Sample / demo data must be labelled "Sample data" on the screen.

---

## 7. Imagery, icons and logo

- **Logo:** `admin-web/public/logo.png` (coconut half with leaf and the "KAPCONNECT" wordmark). Keep clear space equal to the coconut's height around it. Do not recolour or stretch it. Minimum width 80 px.
- **Photography:** real, warm, outdoor farm photos (estates, tractors, husking, copra). Crop with rounded corners, never full-bleed grey stock images.
- **Icons:** simple outline icons, 18–24 px, 1.8 px stroke, round caps. Colour = ink or the tone colour. Use the same icon for the same idea everywhere.
- **Coconut price visual:** the coconut-with-leaves image (`admin-web/public/photos/coconut.png`) with a slow bob and sway, shown on a soft green gradient.

---

## 8. Motion

- Hover / press: `0.15 s`, lift 2 px.
- Content appearing: fade and rise 14–26 px over `0.5–0.7 s`, ease `cubic-bezier(0.2, 0.9, 0.25, 1.15)` (a gentle bounce).
- Numbers count up to their value over about `0.8 s`.
- Keep loops (the bobbing coconut) slow, 4–9 s, and switch them off when the device asks for reduced motion.

---

## 9. Voice and content

- Plain and friendly, like talking to an estate owner or a buyer. Short sentences, no jargon.
- Say what the number means: "North Western leads with 32 estates", not just "32".
- Buttons are verbs: **Save**, **Send offer**, **Accept**, **Download report**.
- Dates: `7 Nov 2026`. Currency: `Rs.`. Support Sinhala and Tamil: leave room, since those strings can be 30% longer.
- Error text says what happened and what to do next ("Could not load prices. Check your connection and try again").

---

## 10. Accessibility checklist

1. Text contrast 4.5 : 1 or better (see 1.8).
2. Touch targets at least 44 × 44 px.
3. Never use colour alone for status. Pair it with a word or icon.
4. Every icon button has a label (`Semantics` / `aria-label`).
5. Respect the system text-size setting. Do not clip text, let it wrap.
6. Respect reduced motion.

---

## 11. Flutter starter code

Create `lib/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();
  // Brand
  static const green = Color(0xFF256B45);
  static const greenSoft = Color(0xFFE3F0E6);
  static const greenMid = Color(0xFF5FA47B);
  static const greenLight = Color(0xFF9FD0B0);
  static const brown = Color(0xFF8B4A1C);
  static const gold = Color(0xFFD9A441);
  // Neutrals
  static const ink = Color(0xFF1E2A22);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const page = Color(0xFFF1EFEA);
  static const cream = Color(0xFFFCF8EF);
  static const surface = Color(0xFFFFFFFF);
  // Status
  static const danger = Color(0xFFC62828);
  static const dangerText = Color(0xFFA32820);
  static const dangerSoft = Color(0xFFF8EAEA);
  static const warning = Color(0xFF9A6B12);
  static const warningSoft = Color(0xFFF7EFDF);
  static const info = Color(0xFF2F7396);
  static const infoSoft = Color(0xFFE4EFF5);
}

class AppRadius {
  AppRadius._();
  static const card = 26.0;
  static const tile = 24.0;
  static const callout = 20.0;
  static const field = 12.0;
  static const pill = 999.0;
}

class AppSpace {
  AppSpace._();
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, huge = 32.0;
}

class AppShadows {
  AppShadows._();
  static const card = [
    BoxShadow(color: Color(0x14344638), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const glow = [
    BoxShadow(color: Color(0x47256B45), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.green,
        primary: AppColors.green,
        secondary: AppColors.brown,
        tertiary: AppColors.gold,
        error: AppColors.danger,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.page,
    );
    return base.copyWith(
      textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: Colors.white),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: const StadiumBorder(),
          side: const BorderSide(color: AppColors.line),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F6F1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.green,
        labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.ink),
        secondaryLabelStyle: const TextStyle(fontSize: 12.5, color: Colors.white),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.line)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.green),
    );
  }
}
```

Use it in `main.dart`:

```dart
MaterialApp(theme: AppTheme.light(), /* ... */)
```

Example status pill and card:

```dart
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.fg = AppColors.green, this.bg = AppColors.greenSoft});
  final String text;
  final Color fg, bg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: Colors.white),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}
```

---

## 12. Mapping the old mobile colours to this system

The mobile app currently has three separate palettes. Move everything to the tokens above.

| Old constant (where) | Old value | Use instead |
|---|---|---|
| `kOwnerGreen` (owner widgets) | `#256B45` | `AppColors.green` (already the same) |
| `kOwnerGreenSoft` | `#E3F0E6` | `AppColors.greenSoft` |
| `kOwnerBrown` | `#8B4A1C` | `AppColors.brown` |
| `kOwnerInk` / `kOwnerMuted` / `kOwnerBorder` | `#1E2A22` / `#6B7280` / `#E5E7EB` | `ink` / `muted` / `line` |
| `kOwnerPanel` | `#F1EFEA` | `AppColors.page` |
| `kOwnerCream` | `#FCF8EF` | `AppColors.cream` |
| `kOwnerRed` | `#C62828` | `AppColors.danger` |
| `kBuyerGreen`, `kAuthGreen` | `#2E7D32` | `AppColors.green` (`#256B45`) |
| `kBuyerBrown`, `kAuthBrown` | `#B26A2C` | `AppColors.brown` (`#8B4A1C`) |
| `kBuyerGreenDark` | `#14432A` | `AppColors.green` (or a darker shade of it for pressed states) |
| `kBuyerCream` | `#FDF9F1` | `AppColors.cream` |
| `kBuyerBorder` | `#EDE6DA` | `AppColors.line` |
| `kBuyerGrey`, `kAuthGrey` | `#777777` | `AppColors.muted` |
| Font `Arial` | | Sora |

Migrate screen by screen. Do not mix old and new colours on the same screen.

---

## 13. Before you merge a screen

- [ ] Colours come from `AppColors`, with no raw `Color(0x...)` in screens.
- [ ] Text uses the theme styles (or the sizes in section 2), in Sora.
- [ ] Buttons follow section 4, with one primary action per section.
- [ ] Cards, inputs and chips use the radii and spacing here.
- [ ] Status is shown with the soft pill colours plus a word.
- [ ] Empty, loading and error states are handled.
- [ ] Demo data is labelled.
- [ ] Checked at a small phone width and with larger text.

*If you need a colour or component that is not here, add it to this file in the same pull request as the screen that needs it, so the next developer can reuse it.*

import 'package:flutter/material.dart';

/// KapConnect design system tokens. See DESIGN_SYSTEM.md in the repository.
/// Colours here are the same values as the owner screens' kOwner* constants,
/// so screens built with either look the same.
class AppColors {
  AppColors._();

  // Brand
  static const Color green = Color(0xFF256B45);
  static const Color greenSoft = Color(0xFFE3F0E6);
  static const Color greenMid = Color(0xFF5FA47B);
  static const Color greenLight = Color(0xFF9FD0B0);
  static const Color brown = Color(0xFF8B4A1C);
  static const Color gold = Color(0xFFD9A441);

  // Neutrals
  static const Color ink = Color(0xFF1E2A22);
  static const Color muted = Color(0xFF6B7280);
  static const Color line = Color(0xFFE5E7EB);
  static const Color page = Color(0xFFF1EFEA);
  static const Color cream = Color(0xFFFCF8EF);
  static const Color surface = Color(0xFFFFFFFF);

  // Status
  static const Color danger = Color(0xFFC62828);
  static const Color dangerText = Color(0xFFA32820);
  static const Color dangerSoft = Color(0xFFF8EAEA);
  static const Color warning = Color(0xFF9A6B12);
  static const Color warningSoft = Color(0xFFF7EFDF);
  static const Color info = Color(0xFF2F7396);
  static const Color infoSoft = Color(0xFFE4EFF5);
}

class AppRadius {
  AppRadius._();

  static const double card = 26;
  static const double tile = 24;
  static const double callout = 20;
  static const double field = 12;
  static const double pill = 999;
}

class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;
}

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14344638), blurRadius: 30, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x47256B45), blurRadius: 18, offset: Offset(0, 8)),
  ];
}

/// Gives a screen the design system's buttons, dialogs, inputs, chips and
/// switches, so its default Material widgets are green and rounded instead of
/// Flutter's default purple. The font stays whatever the app already uses.
class AppThemeScope extends StatelessWidget {
  final Widget child;

  const AppThemeScope({super.key, required this.child});

  static ThemeData of(ThemeData base) {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.green,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.green,
          onPrimary: Colors.white,
          primaryContainer: AppColors.greenSoft,
          onPrimaryContainer: AppColors.green,
          secondary: AppColors.brown,
          tertiary: AppColors.gold,
          error: AppColors.danger,
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.muted,
          outline: AppColors.line,
          outlineVariant: AppColors.line,
          surfaceTint: Colors.transparent,
        );

    const StadiumBorder pill = StadiumBorder();
    const TextStyle buttonText = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final OutlineInputBorder fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.field),
      borderSide: const BorderSide(color: AppColors.line),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.page,
      dividerColor: AppColors.line,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.line,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: pill,
          side: const BorderSide(color: AppColors.line),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.callout),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.callout),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F6F1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.green, width: 1.5),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.greenSoft,
        side: const BorderSide(color: AppColors.line),
        shape: pill,
        labelStyle: const TextStyle(fontSize: 12.5, color: AppColors.ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFFB4B8BC);
          }
          return states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.line;
          return states.contains(WidgetState.selected)
              ? AppColors.green
              : AppColors.line;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.greenSoft,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.callout),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.callout),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: of(Theme.of(context)), child: child);
}

/// showDialog with the design system's theme, so a dialog opened from a
/// screen's State context is not Flutter's default purple.
Future<T?> showThemedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (ctx) => AppThemeScope(child: Builder(builder: builder)),
);

/// showModalBottomSheet with the design system's theme.
Future<T?> showThemedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = false,
  Color? backgroundColor,
  BoxConstraints? constraints,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  showDragHandle: showDragHandle,
  backgroundColor: backgroundColor,
  constraints: constraints,
  builder: (ctx) => AppThemeScope(child: Builder(builder: builder)),
);

/// The pickers take their theme from here.
Widget themedPicker(BuildContext context, Widget? child) =>
    AppThemeScope(child: child ?? const SizedBox.shrink());

/// The app-wide theme, the same look as before (Material 3 with Arial).
class AppTheme {
  AppTheme._();

  static ThemeData light() => ThemeData(useMaterial3: true, fontFamily: 'Arial');
}

/// A small coloured label for a status such as "Accepted" or "Pending Ack".
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.fg = AppColors.green,
    this.bg = AppColors.greenSoft,
  });

  final String text;
  final Color fg, bg;

  factory StatusPill.forStatus(String status) {
    switch (status) {
      case 'Pending Ack':
      case 'Negotiating':
      case 'Negotiation':
      case 'Submitted':
        return StatusPill(
          status,
          fg: AppColors.warning,
          bg: AppColors.warningSoft,
        );
      case 'Cancelled':
      case 'Rejected':
        return StatusPill(
          status,
          fg: AppColors.dangerText,
          bg: AppColors.dangerSoft,
        );
      case 'Accepted':
      case 'Receipt Confirmed':
      case 'Distributed':
        return const StatusPill('Accepted');
      default:
        return StatusPill(
          status,
          fg: AppColors.info,
          bg: AppColors.infoSoft,
        );
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

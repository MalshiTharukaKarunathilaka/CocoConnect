import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CocoConnect shared tokens — from DESIGN_SYSTEM.md.
/// Why: one palette/font so fertilizer matches the rest of the app.
class AppColors {
  AppColors._();
  static const green = Color(0xFF256B45);
  static const greenSoft = Color(0xFFE3F0E6);
  static const greenMid = Color(0xFF5FA47B);
  static const greenLight = Color(0xFF9FD0B0);
  static const brown = Color(0xFF8B4A1C);
  static const gold = Color(0xFFD9A441);
  static const ink = Color(0xFF1E2A22);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const page = Color(0xFFF1EFEA);
  static const cream = Color(0xFFFCF8EF);
  static const surface = Color(0xFFFFFFFF);
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
  static const xs = 4.0,
      sm = 8.0,
      md = 12.0,
      lg = 16.0,
      xl = 20.0,
      xxl = 24.0,
      huge = 32.0;
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
    // Use Sora family only — avoids material_ui TextTheme clash from google_fonts 9.
    final soraFamily = GoogleFonts.sora().fontFamily;
    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: soraFamily,
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: soraFamily),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.green,
      ),
    );
  }
}

/// Soft status pill (Pending Ack, Cancelled, …).
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

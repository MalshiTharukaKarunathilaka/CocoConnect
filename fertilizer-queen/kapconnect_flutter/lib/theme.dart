import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFFDF8F2);
  static const card = Colors.white;
  static const primary = Color(0xFF256445);
  static const primarySoft = Color(0xFFE8F0E9);
  static const mint = Color(0xFFB8F0CD);
  static const mintSoft = Color(0xFFDDF5E3);
  static const text = Color(0xFF1B1B1B);
  static const muted = Color(0xFF5A5A5A);
  static const faint = Color(0xFFC9C9C9);
  static const border = Color(0xFFE8E4DE);
  static const holiday = Color(0xFFE59A9A);
  static const booked = Color(0xFFF5B183);
  static const warn = Color(0xFFD97706);
  static const warnSoft = Color(0xFFFFF1C2);
  static const sand = Color(0xFFF1ECE4);
}

const cardShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
];

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.bg,
    ),
    fontFamily: null,
    splashFactory: InkRipple.splashFactory,
  );
}

/// 2200 -> "2,200"
String money(int v) => v
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

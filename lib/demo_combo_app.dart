import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'screens/fertilizer/fertilizer_login_page.dart';
import 'theme/app_theme.dart';

/// Fertilizer combo: phone login → shared store (orders sync across roles).
void main() {
  fertilizerComboMode = true;
  runApp(const ComboApp());
}

class ComboApp extends StatelessWidget {
  const ComboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KapConnect Fertilizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Why: skip the role-card list — go straight to phone + password login.
      home: const FertilizerLoginPage(),
    );
  }
}

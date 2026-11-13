import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'screens/fertilizer/fertilizer_role_gate.dart';
import 'theme/app_theme.dart';

/// Fertilizer combo: role logins → shared store (orders sync across roles).
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
      home: const FertilizerRoleGate(),
    );
  }
}

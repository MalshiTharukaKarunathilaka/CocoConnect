import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'screens/estate_owner_profile_page.dart';
import 'screens/orders/orders_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const KapConnectApp());
}

class KapConnectApp extends StatelessWidget {
  const KapConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kapconnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),

      // First screen
      // Restores a saved login, otherwise shows Login; then sends each
      // account type to its own home screen.
      home: const AuthGate(),

      // App routes
      routes: {
        '/profile': (context) => const EstateOwnerProfilePage(),
        '/owner-activity': (context) => const OrdersPage(initialTab: 1),
      },
    );
  }
}

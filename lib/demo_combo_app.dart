import 'package:flutter/material.dart';
import 'screens/estate_owner_dashboard.dart';

/// Combined test entry: Senuji estate-owner home first.
/// Tap Fertilizer to open Ibrahim's fertilizer map / order flow.
void main() {
  runApp(const ComboApp());
}

class ComboApp extends StatelessWidget {
  const ComboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KapConnect Combined',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: const EstateOwnerDashboard(),
    );
  }
}

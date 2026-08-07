import 'package:flutter/material.dart';
import 'screens/estate_owner_dashboard.dart';

void main() {
  runApp(const KapConnectApp());
}

class KapConnectApp extends StatelessWidget {
  const KapConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KapConnect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const EstateOwnerDashboard(),
    );
  }
}
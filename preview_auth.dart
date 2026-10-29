// Dev-only entry point for the login flow without touching main.dart.
// Run with:  flutter run -t preview_auth.dart
// Needs the backend running (npm run dev in the backend folder).
import 'package:flutter/material.dart';
import 'package:kapconnect_mobile/screens/auth_gate.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: const AuthGate(),
    ),
  );
}

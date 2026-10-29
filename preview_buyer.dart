// Dev-only entry point for previewing the buyer screens without touching
// main.dart. Run with:  flutter run -t preview_buyer.dart
// Opens Login first unless a buyer is already logged in, since the buyer
// screens load their data from the backend (npm run dev in the backend
// folder).
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

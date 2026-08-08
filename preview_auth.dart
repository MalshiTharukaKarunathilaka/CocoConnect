// Dev-only entry point for previewing the auth screens without touching
// main.dart. Run with:  flutter run -t preview_auth.dart
import 'package:flutter/material.dart';
import 'package:kapconnect_mobile/screens/login_page.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: const LoginPage(),
    ),
  );
}

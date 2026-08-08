// Demo entry point - opens a menu of every screen on this branch.
// Run with:  flutter run -t preview_demo.dart
import 'package:flutter/material.dart';
import 'package:kapconnect_mobile/screens/demo_home_page.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'CocoConnect Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: const DemoHomePage(),
    ),
  );
}

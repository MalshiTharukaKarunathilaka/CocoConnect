import 'package:flutter/material.dart';
import 'screens/fertilizer/fertilizer_map_page.dart';

/// Local preview entry — skips login and opens the fertilizer map.
void main() {
  runApp(const FertilizerDemoApp());
}

class FertilizerDemoApp extends StatelessWidget {
  const FertilizerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KapConnect Fertilizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: const FertilizerMapPage(),
    );
  }
}

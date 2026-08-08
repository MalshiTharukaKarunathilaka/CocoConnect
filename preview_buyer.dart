// Dev-only entry point for previewing the buyer screens without touching
// main.dart. Run with:  flutter run -t preview_buyer.dart
import 'package:flutter/material.dart';
import 'package:kapconnect_mobile/screens/buyer/buyer_categories_page.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'Arial'),
      home: const BuyerCategoriesPage(),
    ),
  );
}

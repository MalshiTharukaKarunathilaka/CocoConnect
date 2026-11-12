// Dev-only provider UI preview; never connects to the project database.
// flutter run -t preview_provider.dart
import 'package:flutter/material.dart';
import 'package:kapconnect_mobile/screens/provider/provider_calendar_page.dart';
import 'package:kapconnect_mobile/services/provider_calendar_repository.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005331)),
      ),
      home: const ProviderCalendarPage(
        repository: PreviewProviderCalendarRepository(),
      ),
    ),
  );
}

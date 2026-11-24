import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/screens/worker_dashboard.dart';
import 'package:kapconnect_mobile/screens/fertilizer/provider_hub.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_hub.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_data.dart';
import 'package:kapconnect_mobile/screens/fertilizer/fertilizer_oversight_page.dart';
import 'mobile_layout_audit_test.dart' as fixtures;

void main() {
  final cases = <(String, String, Widget Function(), bool)>[
    for (final tab in ['Jobs', 'Chats', 'Alerts', 'Profile'])
      (tab, 'WORKER', () => const WorkerDashboard(), false),
    for (final tab in ['Orders', 'Stock', 'Profile'])
      (
        tab,
        'FERTILIZER_SUPPLIER',
        () => const ProviderHub(mode: FertHomeMode.supplier),
        false,
      ),
    for (final tab in ['Orders', 'Area', 'Stock', 'Messages'])
      (tab, 'CDO', () => const ProviderHub(mode: FertHomeMode.cdo), false),
    for (final tab in ['Suppliers', 'Government', 'My orders', 'Complaints'])
      (tab, 'ESTATE_OWNER', () => const FertilizerHub(), false),
    for (final tab in [
      'Island map',
      'All requests',
      'Quality complaints',
      'Reports & audit',
    ])
      (tab, 'CHAIRMAN', () => const FertilizerOversightPage(), true),
    for (final tab in [
      'Request monitoring',
      'Distribution monitoring',
      'Quality complaints',
    ])
      (tab, 'REGIONAL_MANAGER', () => const FertilizerOversightPage(), true),
  ];
  for (final width in [320.0, 412.0]) {
    for (final item in cases) {
      testWidgets('${item.$2} ${item.$1} navigation at $width', (tester) async {
        SharedPreferences.setMockInitialValues({});
        AuthService.currentUser = AppUser(
          id: 1,
          name: 'Person with a long registered name',
          phone: '0771234567',
          role: item.$2,
          location: 'Kurunegala',
        );
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          final message = details.toString();
          if (RegExp(
            r'overflowed|RenderFlex|RenderBox was not laid|BoxConstraints|infinite size|hasSize|Vertical viewport|Incorrect use of ParentDataWidget',
          ).hasMatch(message)) {
            errors.add(message);
          }
        };
        try {
          await http.runWithClient(() async {
            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.3)),
                  child: child!,
                ),
                home: item.$3(),
              ),
            );
            await tester.pump(const Duration(milliseconds: 300));
            await tester.pump(const Duration(milliseconds: 300));
            if (item.$4) {
              await tester.tap(find.byIcon(Icons.menu).first);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
            final target = find.text(item.$1).hitTestable();
            expect(target, findsWidgets);
            await tester.tap(target.last);
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(milliseconds: 300));
            final scrolls = find.byType(Scrollable).hitTestable();
            if (scrolls.evaluate().isNotEmpty) {
              await tester.drag(scrolls.first, const Offset(0, -500));
              await tester.pump(const Duration(milliseconds: 400));
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
          }, () => fixtures.client);
        } finally {
          FlutterError.onError = previous;
          AuthService.currentUser = null;
        }
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  }
}

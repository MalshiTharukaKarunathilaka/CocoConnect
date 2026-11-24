import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/screens/fertilizer/live_fertilizer_orders_page.dart';

void main() {
  testWidgets(
    'supplier submits one delivered-order rating and sees it after refresh',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      AuthService.currentUser = AppUser(
        id: 2,
        name: 'Supplier',
        phone: '0771234567',
        role: 'FERTILIZER_SUPPLIER',
      );
      addTearDown(() => AuthService.currentUser = null);
      int? saved;
      final client = MockClient((request) async {
        if (request.method == 'PUT') {
          expect(request.url.path, '/api/fertilizer/orders/7/rating');
          saved = (jsonDecode(request.body) as Map)['rating'] as int;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'owner_user_id': 1,
              'supplier_user_id': 2,
              'owner_name': 'Land Owner',
              'supplier_name': 'Supplier',
              'status': 'DELIVERED',
              'product': 'APM',
              'quantity': 3,
              'proposed_total': '15000',
              'preferred_date': '2030-01-01',
              'time_slot': 'Morning',
              'land_owner_rating': saved,
            },
          ]),
          200,
        );
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: LiveFertilizerOrdersPage()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rate land owner'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Submit rating'),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('4 stars'));
        await tester.pump();
        await tester.tap(find.text('Submit rating'));
        await tester.pumpAndSettle();
        expect(saved, 4);
        expect(find.text('Land owner rating: 4 / 5'), findsOneWidget);
        expect(find.text('Rate land owner'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/screens/estate_owner_profile_page.dart';

void main() {
  for (final rated in [false, true]) {
    testWidgets(
      'owner profile shows ${rated ? "received ratings" : "unrated state"}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({
              'estate': {
                'id': 1,
                'estate_name': 'Test land',
                'name': 'Owner',
                'trust_score': 4.8,
              },
              'active_listings': 0,
              'open_chats': 0,
              'offers_waiting': 0,
              'orders_active': 0,
              'orders_completed': 3,
              'average_rating': rated ? '4.5' : null,
              'rating_count': rated ? 2 : 0,
              'rating_sources': [
                {
                  'label': 'Coconut sales',
                  'average_rating': rated ? 5 : null,
                  'rating_count': rated ? 1 : 0,
                },
                {
                  'label': 'Day jobs',
                  'average_rating': rated ? 4 : null,
                  'rating_count': rated ? 1 : 0,
                },
                {
                  'label': 'Machinery bookings',
                  'average_rating': null,
                  'rating_count': 0,
                },
                {
                  'label': 'Fertilizer orders',
                  'average_rating': null,
                  'rating_count': 0,
                },
              ],
            }),
            200,
          ),
        );
        await http.runWithClient(() async {
          await tester.pumpWidget(
            const MaterialApp(home: EstateOwnerProfilePage()),
          );
          await tester.pumpAndSettle();
          expect(find.text('Trust Score'), findsOneWidget);
          for (final label in [
            'Coconut sales',
            'Day jobs',
            'Machinery bookings',
            'Fertilizer orders',
          ]) {
            expect(find.text(label), findsOneWidget);
          }
          expect(
            find.text('4.8'),
            findsNothing,
            reason: 'legacy trust score is not buyer feedback',
          );
          if (rated) {
            expect(find.text('4.5 / 5.0'), findsOneWidget);
            expect(
              find.text('2 received ratings across completed workflows'),
              findsOneWidget,
            );
          } else {
            expect(find.text('Not rated yet'), findsWidgets);
            expect(find.text('/ 5.0'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/screens/live_machinery_booking.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/theme/app_theme.dart';

void main() {
  for (final offer in [null, '25000']) {
    testWidgets(
      'request uses land profile, ash locked fields and ${offer ?? "listed price"}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        AuthService.currentUser = AppUser(
          id: 1,
          name: 'Owner',
          phone: '0771234567',
          role: 'ESTATE_OWNER',
          location: 'Account address is different',
        );
        addTearDown(() => AuthService.currentUser = null);
        tester.view.physicalSize = const Size(390, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? submitted;
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            submitted = Map<String, dynamic>.from(
              jsonDecode(request.body) as Map,
            );
            return http.Response(
              jsonEncode({'message': 'Captured request for validation'}),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': 'Owner',
              'estate_name': 'Malmi Land',
              'location': 'Ibbagamuwa, Kurunegala District',
            }),
            200,
          );
        });
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => requestLiveMachinery(
                      context,
                      machineId: 1,
                      date: DateTime(2030, 3, 4),
                      listedTotal: 24750,
                      items: const [
                        {'service_id': 1, 'quantity': 4.5},
                      ],
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.text('Malmi Land'), findsOneWidget);
          expect(find.text('Ibbagamuwa, Kurunegala District'), findsOneWidget);
          expect(find.text('Account address is different'), findsNothing);
          for (final key in [
            'machinery-land-name',
            'machinery-land-location',
          ]) {
            final decorator = find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(InputDecorator),
            );
            expect(
              tester.widget<InputDecorator>(decorator).decoration.fillColor,
              AppColors.autoFilledBackground,
            );
          }
          expect(
            find.byType(TextFormField),
            findsOneWidget,
            reason: 'Only the optional offer is editable',
          );
          if (offer != null) {
            await tester.enterText(find.byType(TextFormField), offer);
          }
          await tester.tap(find.text('Send Booking Request'));
          await tester.pumpAndSettle();
          expect(submitted!['estate_name'], 'Malmi Land');
          expect(submitted!['address'], 'Ibbagamuwa, Kurunegala District');
          if (offer == null) {
            expect(submitted!.containsKey('offered_total'), isFalse);
          } else {
            expect(submitted!['offered_total'], 25000);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      },
    );
  }
  testWidgets(
    'missing saved land location blocks booking instead of using account address',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient(
        (_) async => http.Response(
          '{"id":1,"estate_name":"Malmi Land","location":null}',
          200,
        ),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => requestLiveMachinery(
                    context,
                    machineId: 1,
                    date: DateTime(2030, 3, 4),
                    items: const [],
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Send Booking Request'),
              )
              .onPressed,
          isNull,
        );
        expect(find.text('Update land details'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/services/auth_service.dart';
import 'package:kapconnect_mobile/services/machinery_api.dart';
import 'package:kapconnect_mobile/services/provider_calendar_repository.dart';
import 'package:kapconnect_mobile/models/provider_booking_request.dart';
import 'package:kapconnect_mobile/screens/provider/provider_request_page.dart';
import 'package:kapconnect_mobile/screens/provider/provider_calendar_page.dart';

Map<String, dynamic> bookingJson({
  int version = 1,
  int proposer = 20,
  bool agreed = false,
  double total = 54400,
}) => {
  'id': 1,
  'machine_id': 1,
  'owner_user_id': 20,
  'provider_user_id': 10,
  'version': version,
  'machine_name': 'Sunil Tractor',
  'machinery': 'Tractor',
  'estate_name': 'Green Valley Estate',
  'address': 'Kurunegala',
  'starts_at': '2030-04-20T02:00:00.000Z',
  'ends_at': '2030-04-20T06:30:00.000Z',
  'status': 'PENDING',
  'proposed_total': '$total',
  'proposed_by': proposer,
  'offer_agreed': agreed,
  'agreed_total': null,
  'latitude': null,
  'longitude': null,
  'owner': {
    'id': 20,
    'name': 'Gamini',
    'phone': '0771234567',
    'latitude': null,
    'longitude': null,
  },
  'provider': {
    'id': 10,
    'name': 'Sunil',
    'phone': '0711234567',
    'latitude': null,
    'longitude': null,
  },
  'items': [
    {
      'service_id': 1,
      'name': 'Disc Ploughing',
      'unit': 'acre',
      'quantity': '8',
      'rate': '6800',
    },
  ],
  'messages': [
    {
      'sender_id': 20,
      'message': 'Please plough eight acres.',
      'created_at': '2030-04-19T03:00:00.000Z',
      'offer_total': '54400',
    },
  ],
};
http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);
final machine = {
  'id': 1,
  'name': 'Sunil Tractor',
  'category': 'Tractor',
  'services': <Object>[],
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'real repository uses authenticated APIs, preserves prices and converts schedule to Sri Lanka time',
    () async {
      await http.runWithClient(
        () async {
          await AuthService.login(phone: '0771234567', password: 'secret123');
          final repo = LiveProviderCalendarRepository();
          final data = await repo.loadMonth(DateTime(2030, 4));
          expect(repo.isPreview, isFalse);
          expect(repo.selectedMachineId, 1);
          expect(data.rates.single.rate, 6800.5);
          expect(data.requests.single.startsAt.hour, 7);
          expect(data.requests.single.startsAt.minute, 30);
          expect(data.requests.single.version, 1);
          expect(data.requests.single.ownerName, 'Gamini');
          expect(data.requests.single.machineName, 'Sunil Tractor');
          expect(data.requests.single.canAccept, isTrue);
        },
        () => MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return jsonResponse({
              'token': 'real-test-token',
              'user': {
                'id': 10,
                'name': 'Sunil',
                'phone': '0771234567',
                'role': 'SERVICE_PROVIDER',
              },
            });
          }
          expect(request.headers['Authorization'], 'Bearer real-test-token');
          if (request.url.path.endsWith('/machines')) {
            return jsonResponse([machine]);
          }
          expect(request.url.queryParameters['month'], '2030-04');
          return jsonResponse({
            'days': [],
            'bookings': [bookingJson()],
            'services': [
              {
                'id': 1,
                'name': 'Disc Ploughing',
                'unit': 'acre',
                'rate': '6800.50',
              },
            ],
          });
        }),
      );
    },
  );
  test(
    'server counteroffers send the current version and booking total',
    () async {
      final model = ProviderBookingRequest.fromJson(bookingJson());
      await http.runWithClient(
        () async {
          final saved = await const MachineryApi().respond(
            model,
            'messages',
            rate: 7000,
          );
          expect(saved.version, 2);
          expect(saved.proposedRate, 7000);
          expect(saved.canAccept, isFalse);
          expect(
            model.version,
            1,
          ); // Server response replaces the snapshot; no local pretend save.
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/machinery/bookings/1/messages');
          final body = jsonDecode(request.body) as Map;
          expect(body['expected_version'], 1);
          expect(body['offer_total'], 56000);
          return jsonResponse(
            bookingJson(version: 2, proposer: 10, total: 56000),
            201,
          );
        }),
      );
    },
  );
  test('expired sessions clear the saved authentication token', () async {
    SharedPreferences.setMockInitialValues({'auth_token': 'expired-token'});
    await http.runWithClient(
      () async {
        expect(await AuthService.restoreSession(), isNull);
        expect(AuthService.currentUser, isNull);
        expect(
          (await SharedPreferences.getInstance()).getString('auth_token'),
          isNull,
        );
      },
      () => MockClient(
        (request) async => jsonResponse({'message': 'Session expired'}, 401),
      ),
    );
  });
  testWidgets(
    'live negotiation hides simulated replies and waits for the server',
    (tester) async {
      var updateCalls = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: ProviderRequestPage(
                request: ProviderBookingRequest.fromJson(bookingJson()),
                api: const MachineryApi(),
                showMap: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('Preview workflow'), findsNothing);
          final field = find.byKey(const Key('counter-rate'));
          await tester.scrollUntilVisible(
            field,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(field);
          await tester.pumpAndSettle();
          await tester.enterText(field, '7000');
          await tester.ensureVisible(find.text('Update Rate'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Update Rate'));
          await tester.pumpAndSettle();
          expect(updateCalls, 1);
          expect(find.text('Preview: customer accepts offer'), findsNothing);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Accept & Lock Booking'),
                )
                .onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            updateCalls++;
            return jsonResponse(
              bookingJson(version: 2, proposer: 10, total: 56000),
              201,
            );
          }
          return jsonResponse(
            bookingJson(version: 2, proposer: 10, total: 56000),
          );
        }),
      );
    },
  );
  testWidgets(
    'normal provider home loads a real empty inventory instead of sample requests',
    (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: ProviderCalendarPage()),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Sample bookings'), findsNothing);
        expect(find.text('Add Machinery'), findsOneWidget);
        expect(
          find.textContaining('Add your machinery, then set its service rates'),
          findsOneWidget,
        );
        expect(find.text('Gamini Perera'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => MockClient((request) async => jsonResponse([])));
    },
  );
  test('cancelled server bookings retain their cancellation status', () {
    final json = bookingJson()..['status'] = 'CANCELLED';
    expect(
      ProviderBookingRequest.fromJson(json).status,
      ProviderRequestStatus.cancelled,
    );
  });
  testWidgets(
    'owner agrees to a provider offer through the server without confirming the booking',
    (tester) async {
      var agrees = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: ProviderRequestPage(
                request: ProviderBookingRequest.fromJson(
                  bookingJson(version: 2, proposer: 10, total: 56000),
                ),
                api: const MachineryApi(),
                isOwner: true,
                showMap: false,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Booking Request Sent'), findsOneWidget);
          final button = find.text('Agree to Counteroffer');
          await tester.scrollUntilVisible(
            button,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(agrees, 1);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Agree to Counteroffer'),
                )
                .onPressed,
            isNull,
          );
          expect(find.text('Accept & Lock Booking'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            agrees++;
            expect(request.url.path, '/api/machinery/bookings/1/agree');
            expect((jsonDecode(request.body) as Map)['expected_version'], 2);
          }
          return jsonResponse(
            bookingJson(version: 3, proposer: 10, agreed: true, total: 56000),
          );
        }),
      );
    },
  );
  testWidgets(
    'provider saves service rates through the API and sees the saved decimal price',
    (tester) async {
      var price = 6800.5;
      var saves = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: ProviderCalendarPage(initialDate: DateTime(2030, 4, 21)),
            ),
          );
          await tester.pumpAndSettle();
          final edit = find.text('Edit Rate');
          await tester.scrollUntilVisible(
            edit,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(edit);
          await tester.pumpAndSettle();
          await tester.tap(edit);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField), '7200.25');
          await tester.tap(find.text('Save Rate'));
          await tester.pumpAndSettle();
          expect(saves, 1);
          expect(find.textContaining('Service rate saved'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'PUT') {
            saves++;
            final body = jsonDecode(request.body) as Map;
            price = (body['rate'] as num).toDouble();
            expect(price, 7200.25);
            return jsonResponse({});
          }
          if (request.url.path.endsWith('/catalog')) {
            return jsonResponse({
              'Tractor': {
                'Disc Ploughing': ['acre'],
              },
            });
          }
          if (request.url.path.endsWith('/machines')) {
            return jsonResponse([machine]);
          }
          return jsonResponse({
            'days': [],
            'bookings': [],
            'services': [
              {
                'id': 1,
                'name': 'Disc Ploughing',
                'unit': 'acre',
                'rate': '$price',
              },
            ],
          });
        }),
      );
    },
  );
  testWidgets(
    'provider saves availability through the API and clears only saved drafts',
    (tester) async {
      String state = 'AVAILABLE';
      var saves = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: ProviderCalendarPage(initialDate: DateTime(2030, 4, 21)),
            ),
          );
          await tester.pumpAndSettle();
          final toggle = find.byKey(const Key('availability-toggle'));
          await tester.scrollUntilVisible(
            toggle,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          final save = find.text('Save Availability Settings');
          await tester.ensureVisible(save);
          await tester.pumpAndSettle();
          await tester.tap(save);
          await tester.pumpAndSettle();
          expect(saves, 1);
          expect(state, 'UNAVAILABLE');
          expect(find.text('Unsaved availability changes'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient((request) async {
          if (request.method == 'PUT') {
            saves++;
            final body = jsonDecode(request.body) as Map;
            expect(body['day'], '2030-04-21');
            state = '${body['state']}';
            return jsonResponse({});
          }
          if (request.url.path.endsWith('/machines')) {
            return jsonResponse([machine]);
          }
          return jsonResponse({
            'days': [
              {'day': '2030-04-21', 'state': state},
            ],
            'bookings': [],
            'services': [],
          });
        }),
      );
    },
  );
}

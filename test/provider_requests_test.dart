import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/models/provider_booking_request.dart';
import 'package:kapconnect_mobile/models/provider_calendar.dart';
import 'package:kapconnect_mobile/screens/provider/provider_calendar_page.dart';
import 'package:kapconnect_mobile/screens/provider/provider_request_page.dart';
import 'package:kapconnect_mobile/services/provider_calendar_repository.dart';

ProviderBookingRequest request(String id, {int hour = 8}) =>
    ProviderBookingRequest(
      id: id,
      machineId: 'tractor-1',
      ownerName: id == '1' ? 'Gamini Perera' : 'Nimal Silva',
      estateName: 'Green Valley Estate',
      address: 'Kurunegala',
      machinery: 'Tractor',
      service: 'Disc Ploughing',
      quantity: 8,
      unit: 'acre',
      startsAt: DateTime(2028, 1, 6, hour),
      endsAt: DateTime(2028, 1, 6, hour + 2),
      proposedRate: 6800,
      messages: [
        ProviderRequestMessage(
          text: 'Please plough eight acres.',
          sender: RequestSpeaker.owner,
          sentAt: DateTime(2028, 1, 5, 10),
          rate: 6800,
        ),
      ],
    );

class _Repository implements ProviderCalendarRepository {
  final List<ProviderBookingRequest> requests;
  _Repository(this.requests);
  @override
  bool get isPreview => true;
  @override
  Future<ProviderCalendarMonth> loadMonth(DateTime month) async =>
      ProviderCalendarMonth(requests: requests);
}

Future<void> mobile(
  WidgetTester tester,
  Widget page, {
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: ThemeData(useMaterial3: true), home: page),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'counteroffers retain history and require customer agreement before locking',
    () {
      final r = request('1');
      r.sendMessage('I can arrive at eight.');
      r.counter(7000);
      expect(r.messages.length, 3);
      expect(r.agreedRate, isNull);
      expect(r.canAccept, isFalse);
      expect(() => r.accept([r]), throwsStateError);
      r.previewCustomerAccepts();
      r.accept([r]);
      expect(r.agreedRate, 7000);
      expect(r.status, ProviderRequestStatus.confirmed);
      expect(r.messages.first.text, 'Please plough eight acres.');
      expect(() => r.counter(7500), throwsStateError);
    },
  );
  test(
    'overlap is rejected but adjacent bookings and declined requests do not block slots',
    () {
      final first = request('1');
      final overlap = request('2', hour: 9);
      final adjacent = request('3', hour: 10);
      first.accept([first, overlap, adjacent]);
      expect(() => overlap.accept([first, overlap]), throwsStateError);
      adjacent.accept([first, adjacent]);
      expect(adjacent.status, ProviderRequestStatus.confirmed);
      final declined = request('4', hour: 13)..decline();
      final later = request('5', hour: 13);
      later.accept([declined, later]);
      expect(later.status, ProviderRequestStatus.confirmed);
    },
  );
  test('invalid rates cannot replace the current offer', () {
    final r = request('1');
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => r.counter(value), throwsArgumentError);
    }
    expect(r.proposedRate, 6800);
  });

  testWidgets(
    'calendar inquiry supports multiple requests and opens the correct detail page',
    (tester) async {
      final requests = [request('1'), request('2')];
      await mobile(
        tester,
        ProviderCalendarPage(
          initialDate: DateTime(2028, 1, 6),
          repository: _Repository(requests),
        ),
      );
      await tester.tap(find.byKey(const Key('provider-day-2028-01-06')));
      await tester.pumpAndSettle();
      expect(find.text('Request 1 of 2'), findsOneWidget);
      expect(find.text('Gamini Perera'), findsOneWidget);
      await tester.tap(find.byTooltip('Next request'));
      await tester.pumpAndSettle();
      expect(find.text('Request 2 of 2'), findsOneWidget);
      expect(find.text('Nimal Silva'), findsOneWidget);
      await reveal(tester, find.text('Review & Respond to Request'));
      await tester.tap(find.text('Review & Respond to Request'));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderRequestPage), findsOneWidget);
      expect(find.text('Nimal Silva'), findsOneWidget);
      expect(find.text('Gamini Perera'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the provider can only accept or decline: no counter rate, no messages',
    (tester) async {
      final r = request('1');
      await mobile(
        tester,
        ProviderRequestPage(request: r, bookings: [r], showMap: false),
        width: 320,
      );
      expect(
        find.textContaining('Only the estate owner can change the price'),
        findsOneWidget,
      );
      await reveal(tester, find.text('Accept & Lock Booking'));
      expect(find.byKey(const Key('counter-rate')), findsNothing);
      expect(find.text('Update Rate'), findsNothing);
      expect(find.byKey(const Key('provider-message')), findsNothing);
      expect(find.text('Send message'), findsNothing);
      expect(find.byKey(const Key('change-request')), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Accept & Lock Booking'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('Decline'), findsOneWidget);
      expect(r.messages.length, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'locking a booking refreshes calendar counts and survives month navigation',
    (tester) async {
      final r = request('1');
      await mobile(
        tester,
        ProviderCalendarPage(
          initialDate: DateTime(2028, 1, 6),
          repository: _Repository([r]),
        ),
      );
      await tester.tap(find.byKey(const Key('provider-day-2028-01-06')));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Review & Respond to Request'));
      await tester.tap(find.text('Review & Respond to Request'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Accept & Lock Booking'));
      await tester.tap(find.text('Accept & Lock Booking'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lock preview booking'));
      await tester.pumpAndSettle();
      expect(r.status, ProviderRequestStatus.confirmed);
      await reveal(tester, find.byKey(const Key('selected-date')));
      expect(find.text('1 confirmed · 0 incoming'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byTooltip('Next month'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(r.status, ProviderRequestStatus.confirmed);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the offer card and the log show the service date', (
    tester,
  ) async {
    final r = request('1');
    await mobile(
      tester,
      ProviderRequestPage(request: r, bookings: [r], showMap: false),
    );
    await reveal(tester, find.text('Received Offer'));
    expect(find.textContaining('Service date: '), findsOneWidget);
    expect(r.messages.first.sender, RequestSpeaker.owner);
    expect(find.text('Please plough eight acres.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'declining from request review removes the incoming request and leaves the day available',
    (tester) async {
      final r = request('1');
      await mobile(
        tester,
        ProviderCalendarPage(
          initialDate: DateTime(2028, 1, 6),
          repository: _Repository([r]),
        ),
      );
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thursday, January 6, 2028'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Review & Respond to Request'));
      await tester.tap(find.text('Review & Respond to Request'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Decline'));
      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline preview request'));
      await tester.pumpAndSettle();
      expect(r.status, ProviderRequestStatus.declined);
      await reveal(tester, find.byKey(const Key('selected-date')));
      expect(find.text('0 confirmed · 0 incoming'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(find.byKey(const Key('availability-toggle')))
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

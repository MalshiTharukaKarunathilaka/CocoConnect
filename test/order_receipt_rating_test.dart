import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kapconnect_mobile/screens/orders/orders_page.dart';

void main() {
  for (final role in ['BUYER', 'ESTATE_OWNER']) {
    testWidgets('$role receipt and rating controls fit a narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var status = 'AWAITING_RECEIPT';
      final counterpart = role == 'BUYER' ? 'Malmi Estate' : 'Lanka Mills';
      int? rating;
      String? ratingNote;
      Map<String, Object?> order() => {
        'id': 1,
        'status': status,
        'my_role': role,
        'counterpart_name': counterpart,
        'counterpart_trust_score': 4.5,
        'product_type': 'RAW_COCONUT',
        'quantity': 300,
        'final_price_per_unit': 122,
        'total_value': 36600,
        'delivered_quantity': 290,
        'delivered_price_per_unit': 122,
        'due_date': '2026-12-01',
        'created_at': '2026-11-16',
        'completed_at': status == 'COMPLETED' ? '2026-12-01' : null,
        'my_rating': rating,
        'my_rating_note': ratingNote,
      };
      final client = MockClient((request) async {
        if (request.url.path == '/api/orders/1/counterpart-profile') {
          return http.Response(
            jsonEncode({
              'name': counterpart,
              'average_rating': 4.5,
              'rating_count': 2,
              'comments': [{'rating': 5, 'comment': 'Great communication'}],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/confirm-receipt')) {
          status = 'COMPLETED';
          return http.Response('{}', 200);
        }
        if (request.url.path.endsWith('/rating')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          rating = body['rating'] as int;
          ratingNote = body['note'] as String?;
          return http.Response('{}', 200);
        }
        if (request.url.path != '/api/activity') {
          return http.Response('[]', 200);
        }
        return http.Response(
          jsonEncode({
            'pending': [],
            'negotiations': [],
            'deals': status == 'COMPLETED' ? [] : [order()],
            'transactions': status == 'COMPLETED' ? [order()] : [],
          }),
          200,
        );
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(
          const MaterialApp(home: OrdersPage(initialTab: 1)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (role == 'BUYER') {
          await tester.ensureVisible(find.text('Confirm Goods Received'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirm Goods Received'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('290 nuts at Malmi Estate'),
            findsOneWidget,
          );
          expect(status, 'AWAITING_RECEIPT');
          await tester.tap(
            find.widgetWithText(FilledButton, 'Confirm Goods Received'),
          );
          await tester.pumpAndSettle();
          expect(status, 'COMPLETED');
        } else {
          expect(
            find.text('Waiting for Lanka Mills to mark the nuts as received'),
            findsOneWidget,
          );
          expect(find.text('Complete Transaction'), findsNothing);
          status = 'COMPLETED';
          await tester.pumpWidget(
            const MaterialApp(
              key: ValueKey('completed'),
              home: OrdersPage(initialTab: 2),
            ),
          );
          await tester.pumpAndSettle();
        }
        expect(find.text('★ 4.5/5'), findsOneWidget);
        await tester.ensureVisible(find.text(counterpart));
        await tester.tap(find.text(counterpart));
        await tester.pumpAndSettle();
        expect(find.text('Great communication'), findsOneWidget);
        await tester.tap(find.byTooltip('Close profile'));
        await tester.pumpAndSettle();
        final label = role == 'BUYER' ? 'Rate seller' : 'Rate buyer';
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('4 stars'));
        await tester.pumpAndSettle();
        expect(find.text('Comment (optional)'), findsOneWidget);
        if (role == 'BUYER') {
          await tester.enterText(find.byType(TextField), 'Easy collection');
        }
        await tester.tap(find.text('Submit rating'));
        await tester.pumpAndSettle();
        expect(rating, 4);
        expect(ratingNote, role == 'BUYER' ? 'Easy collection' : isNull);
        expect(find.text('Your rating: 4/5 stars'), findsOneWidget);
        expect(find.text('Submit rating'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }
}

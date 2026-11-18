import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kapconnect_mobile/screens/chat/chat_page.dart';

void main() {
  for (final role in ['BUYER', 'ESTATE_OWNER']) {
    for (final width in [320.0, 390.0, 1200.0]) {
      testWidgets('$role chat stays mobile width and can cancel at $width', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var cancelled = false;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/cancel-deal')) {
            cancelled = true;
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode({
              'id': 1,
              'status': cancelled ? 'CANCELLED' : 'ACCEPTED',
              'my_role': role,
              'order_id': 1,
              'order_status': cancelled ? 'CANCELLED' : 'ACCEPTED',
              'order_price': 130,
              'counterpart_name':
                  'A very long counterpart name for mobile testing',
              'counterpart_location': 'Kurunegala',
              'listing': {
                'product_type': 'RAW_COCONUT',
                'quantity': 2000,
                'offer_price_per_unit': 130,
                'available_date': '2026-12-01',
                'estate_name':
                    'A very long estate name that must wrap within the card',
              },
              'messages': [],
            }),
            200,
          );
        });
        await http.runWithClient(() async {
          await tester.pumpWidget(const MaterialApp(home: ChatPage(chatId: 1)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final chat = tester.getSize(find.byType(Column).first);
          expect(chat.width, lessThanOrEqualTo(390));
          expect(find.text('Cancel Deal').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Cancel Deal'));
          await tester.pumpAndSettle();
          expect(cancelled, isFalse);
          await tester.tap(find.widgetWithText(TextButton, 'Cancel Deal'));
          await tester.pumpAndSettle();
          expect(cancelled, isTrue);
          expect(find.text('Deal cancelled'), findsWidgets);
          expect(find.text('Cancel Deal'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      });
    }
  }
}

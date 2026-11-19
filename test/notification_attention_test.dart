import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kapconnect_mobile/screens/chat/notifications_page.dart';
import 'package:kapconnect_mobile/services/chat_service.dart';
import 'package:kapconnect_mobile/services/notification_attention.dart';
import 'package:kapconnect_mobile/widgets/app_bottom_nav.dart';

void main() {
  final now = DateTime.utc(2026, 11, 19, 12);
  AppNotification update(
    int id, {
    int chat = 1,
    bool urgent = false,
    int? sender,
  }) => AppNotification(
    key: 'chat-$id',
    type: NotificationType.chat,
    title: 'New message',
    body: '',
    at: now.subtract(Duration(seconds: id)),
    urgent: urgent,
    negotiationId: chat,
    requestId: null,
    orderId: null,
    dayJobChatId: null,
    senderId: sender,
    senderName: sender == null ? null : 'Sender $sender',
  );

  test('one unread message queues a pulse without a minimum count', () {
    final attention = NotificationAttention();
    attention.update([update(1, sender: 1)]);
    expect(attention.takePulse('sender-1'), isTrue);
    attention.update([update(1, sender: 1), update(2, sender: 1)]);
    expect(attention.takePulse('sender-1'), isFalse);
    attention.update([]);
    attention.update([update(3, sender: 1)]);
    expect(attention.takePulse('sender-1'), isTrue);
  });

  test(
    'one urgent alert pulses immediately without grouping unrelated chats',
    () {
      final attention = NotificationAttention();
      final alerts = [update(1, urgent: true), update(2, chat: 2)];
      expect(groupNotifications(alerts).length, 2);
      attention.update(alerts);
      expect(attention.takePulse('negotiation-1'), isTrue);
      attention.update([]);
      expect(attention.takePulse('negotiation-2'), isFalse);
    },
  );

  test('inbox groups by sender across chats and keeps actions separate', () {
    final inbox = groupNotifications([
      update(1, sender: 1),
      update(2, sender: 1, chat: 2),
      update(3, sender: 2),
      update(4, urgent: true),
    ], bySender: true);
    expect(inbox.values.map((group) => group.length), [2, 1, 1]);
  });

  testWidgets(
    'a single unread message pulses while a reviewed offer stays still',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'seen_notifications_0': ['offer-1'],
      });
      Unread.alertAttention.clear();
      addTearDown(Unread.alertAttention.clear);
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'key': 'offer-1',
              'type': 'OFFER',
              'title': 'New offer',
              'negotiation_id': 1,
              'urgent': true,
            },
            {
              'key': 'chat-2',
              'type': 'CHAT',
              'title': 'New message',
              'negotiation_id': 2,
              'sender_name': 'Malmi',
              'sender_id': 2,
            },
          ]),
          200,
        ),
      );
      await http.runWithClient(() async {
        await tester.pumpWidget(const MaterialApp(home: NotificationsPage()));
        await tester.pump();
        double scale(String key) => tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform
            .storage[0];
        const message = 'sender-2';
        expect(scale(message), 1);
        await tester.pump(const Duration(milliseconds: 300));
        expect(scale(message), lessThan(1));
        expect(scale('negotiation-1'), 1);
        await tester.pumpAndSettle();
        expect(scale(message), 1);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}

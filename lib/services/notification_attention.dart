import 'chat_service.dart';

Map<String, List<AppNotification>> groupNotifications(
  Iterable<AppNotification> items, {
  bool bySender = false,
}) {
  final groups = <String, List<AppNotification>>{};
  for (final item in items) {
    final key = switch (item) {
      AppNotification(
        type: NotificationType.dayJobChat,
        dayJobChatId: final id?,
      ) => 'day-job-chat-$id',
      AppNotification(isChatMessage: true, senderId: final id?) when bySender =>
        'sender-$id',
      AppNotification(isChatMessage: true, negotiationId: final id?)
          when bySender =>
        'messages-$id',
      AppNotification(negotiationId: final id?) => 'negotiation-$id',
      AppNotification(orderId: final id?) => 'order-$id',
      AppNotification(requestId: final id?) => 'request-$id',
      _ => item.key,
    };
    (groups[key] ??= []).add(item);
  }
  return groups;
}

/// Queues one pulse when a card first has unread alerts.
class NotificationAttention {
  final _unreadGroups = <String>{};
  final _pendingPulses = <String>{};

  bool takePulse(String key) => _pendingPulses.remove(key);

  void update(List<AppNotification> unseen) {
    final groups = groupNotifications(unseen, bySender: true).keys.toSet();
    _pendingPulses.retainAll(groups);
    _pendingPulses.addAll(groups.difference(_unreadGroups));
    _unreadGroups
      ..clear()
      ..addAll(groups);
  }

  void clear() {
    _unreadGroups.clear();
    _pendingPulses.clear();
  }
}

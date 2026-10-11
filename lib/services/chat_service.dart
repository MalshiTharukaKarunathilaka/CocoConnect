import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'auth_service.dart';

double? _numOrNull(Object? value) =>
    value == null ? null : double.tryParse('$value');

DateTime? _timeOrNull(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

/// PENDING / ACCEPTED / REJECTED / SUPERSEDED / CLOSED
enum OfferStatus {
  pending,
  accepted,
  rejected,
  superseded,
  closed;

  static OfferStatus? fromApi(Object? value) => switch ('$value') {
    'PENDING' => pending,
    'ACCEPTED' => accepted,
    'REJECTED' => rejected,
    'SUPERSEDED' => superseded,
    'CLOSED' => closed,
    _ => null,
  };
}

/// One row of the chats list.
class ChatSummary {
  final int id;
  final String status; // OPEN / ACCEPTED / REJECTED
  final String? orderStatus;
  final bool iAmBuyer;
  final String counterpartName;
  final String productType;
  final int quantity;
  final double listedPrice;
  final String? lastText;
  final double? lastOfferPrice;
  final bool lastIsMine;
  final DateTime? lastActivityAt;
  final int unreadCount;

  /// The other side sent a price that is waiting for my answer.
  final bool offerWaiting;

  const ChatSummary({
    required this.id,
    required this.status,
    required this.orderStatus,
    required this.iAmBuyer,
    required this.counterpartName,
    required this.productType,
    required this.quantity,
    required this.listedPrice,
    required this.lastText,
    required this.lastOfferPrice,
    required this.lastIsMine,
    required this.lastActivityAt,
    required this.unreadCount,
    required this.offerWaiting,
  });

  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? last =
        json['last_message'] as Map<String, dynamic>?;
    return ChatSummary(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'OPEN',
      orderStatus: json['order_status'] as String?,
      iAmBuyer: json['my_role'] == 'BUYER',
      counterpartName: json['counterpart_name'] as String? ?? '',
      productType: json['product_type'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      listedPrice: _numOrNull(json['listed_price']) ?? 0,
      lastText: last?['text'] as String?,
      lastOfferPrice: _numOrNull(last?['offer_price_per_unit']),
      lastIsMine: last?['is_mine'] == true,
      lastActivityAt: _timeOrNull(json['last_activity_at']),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      offerWaiting: json['offer_waiting'] == true,
    );
  }
}

class ChatMessage {
  final int id;
  final String? text;
  final double? offerPrice;
  final OfferStatus? offerStatus;
  final DateTime? createdAt;
  final bool isMine;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.offerPrice,
    required this.offerStatus,
    required this.createdAt,
    required this.isMine,
  });

  bool get isOffer => offerPrice != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    text: json['message'] as String?,
    offerPrice: _numOrNull(json['offer_price_per_unit']),
    offerStatus: OfferStatus.fromApi(json['offer_status']),
    createdAt: _timeOrNull(json['created_at']),
    isMine: json['is_mine'] == true,
  );
}

class ChatDetail {
  final int id;
  final String status;
  final bool iAmBuyer;
  final int? orderId;
  final String? orderStatus;
  final double? orderPrice;
  final String counterpartName;
  final String? counterpartLocation;
  final String productType;
  final int quantity;
  final double listedPrice;
  final DateTime? availableDate;
  final String? estateName;

  /// The buyer may still take the listed price (no other price offered).
  final bool canAcceptListing;
  final List<ChatMessage> messages;

  const ChatDetail({
    required this.id,
    required this.status,
    required this.iAmBuyer,
    required this.orderId,
    required this.orderStatus,
    required this.orderPrice,
    required this.counterpartName,
    required this.counterpartLocation,
    required this.productType,
    required this.quantity,
    required this.listedPrice,
    required this.availableDate,
    required this.estateName,
    required this.canAcceptListing,
    required this.messages,
  });

  bool get isOpen => status == 'OPEN';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isCompleted => orderStatus == 'COMPLETED';

  /// The newest offer, if any price was sent in the chat.
  ChatMessage? get latestOffer {
    for (final message in messages.reversed) {
      if (message.isOffer) return message;
    }
    return null;
  }

  factory ChatDetail.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> listing =
        json['listing'] as Map<String, dynamic>? ?? {};
    return ChatDetail(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'OPEN',
      iAmBuyer: json['my_role'] == 'BUYER',
      orderId: json['order_id'] as int?,
      orderStatus: json['order_status'] as String?,
      orderPrice: _numOrNull(json['order_price']),
      counterpartName: json['counterpart_name'] as String? ?? '',
      counterpartLocation: json['counterpart_location'] as String?,
      productType: listing['product_type'] as String? ?? '',
      quantity: (listing['quantity'] as num?)?.toInt() ?? 0,
      listedPrice: _numOrNull(listing['offer_price_per_unit']) ?? 0,
      availableDate: DateTime.tryParse(
        '${listing['available_date']}'.split('T').first,
      ),
      estateName: listing['estate_name'] as String?,
      canAcceptListing: json['can_accept_listing'] == true,
      messages: [
        for (final item in json['messages'] as List? ?? const [])
          ChatMessage.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

enum NotificationType { offer, sellOffer, delivery }

class AppNotification {
  /// Stable id, used to remember which ones were already seen.
  final String key;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime? at;
  final bool urgent;
  final int? negotiationId;
  final int? requestId;
  final int? orderId;

  const AppNotification({
    required this.key,
    required this.type,
    required this.title,
    required this.body,
    required this.at,
    required this.urgent,
    required this.negotiationId,
    required this.requestId,
    required this.orderId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        key: json['key'] as String? ?? '',
        type: switch (json['type']) {
          'OFFER' => NotificationType.offer,
          'SELL_OFFER' => NotificationType.sellOffer,
          _ => NotificationType.delivery,
        },
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        at: _timeOrNull(json['at']),
        urgent: json['urgent'] == true,
        negotiationId: json['negotiation_id'] as int?,
        requestId: json['request_id'] as int?,
        orderId: json['order_id'] as int?,
      );
}

/// Chats and notifications, the same for buyers and estate owners.
class ChatService {
  ChatService._();

  static Future<List<ChatSummary>> getChats() async {
    final data = await ApiClient.get('/api/chats');
    return [
      for (final item in data as List)
        ChatSummary.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Opening a chat also marks it read.
  static Future<ChatDetail> getChat(int id) async {
    final data = await ApiClient.get('/api/chats/$id');
    return ChatDetail.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> send(int id, {String? text, double? offerPrice}) =>
      ApiClient.post('/api/chats/$id/messages', {
        if (text != null && text.isNotEmpty) 'message': text,
        'offerPricePerUnit': ?offerPrice,
      });

  static Future<void> acceptOffer(int chatId, int messageId) =>
      ApiClient.post('/api/chats/$chatId/offers/$messageId/accept');

  static Future<void> rejectOffer(int chatId, int messageId) =>
      ApiClient.post('/api/chats/$chatId/offers/$messageId/reject');

  static Future<void> acceptListing(int chatId) =>
      ApiClient.post('/api/chats/$chatId/accept-listing');

  static Future<void> close(int chatId) =>
      ApiClient.post('/api/chats/$chatId/close');

  static Future<List<AppNotification>> getNotifications() async {
    final data = await ApiClient.get('/api/notifications');
    return [
      for (final item in data as List)
        AppNotification.fromJson(item as Map<String, dynamic>),
    ];
  }

  // Which notifications this user has already seen, kept on the phone.
  static String get _seenKey =>
      'seen_notifications_${AuthService.currentUser?.id ?? 0}';

  static Future<Set<String>> _seen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_seenKey) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<int> unseenCount(List<AppNotification> items) async {
    final Set<String> seen = await _seen();
    return items.where((item) => !seen.contains(item.key)).length;
  }

  static Future<void> markSeen(List<AppNotification> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only keep keys that still exist, so the list doesn't grow forever.
      await prefs.setStringList(_seenKey, [for (final item in items) item.key]);
    } catch (_) {
      // Badges just stay on; nothing else depends on this.
    }
  }
}

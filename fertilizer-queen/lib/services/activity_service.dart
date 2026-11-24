import 'api_client.dart';
import 'chat_service.dart';

double? _numOrNull(Object? value) =>
    value == null ? null : double.tryParse('$value');

DateTime? _timeOrNull(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

/// Plain dates ("2026-10-20") stay calendar days, no time zone shift.
DateTime? _dayOrNull(Object? value) =>
    value == null ? null : DateTime.tryParse('$value'.split('T').first);

/// An offer I put out that is still waiting for the other side.
class PendingOffer {
  final String kind; // CHAT_OFFER / SELL_OFFER
  final int id;
  final int? negotiationId;
  final int? requestId;
  final String counterpartName;
  final String productType;
  final int quantity;
  final double price;

  /// Listed price (chat) or the buyer's bid (offer on a request).
  final double? theirPrice;

  /// When the buyer needs the nuts (offers on requests).
  final DateTime? date;
  final DateTime? createdAt;

  const PendingOffer({
    required this.kind,
    required this.id,
    required this.negotiationId,
    required this.requestId,
    required this.counterpartName,
    required this.productType,
    required this.quantity,
    required this.price,
    required this.theirPrice,
    required this.date,
    required this.createdAt,
  });

  bool get inChat => kind == 'CHAT_OFFER';

  factory PendingOffer.fromJson(Map<String, dynamic> json) => PendingOffer(
    kind: json['kind'] as String? ?? 'CHAT_OFFER',
    id: json['id'] as int,
    negotiationId: json['negotiation_id'] as int?,
    requestId: json['request_id'] as int?,
    counterpartName: json['counterpart_name'] as String? ?? '',
    productType: json['product_type'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    price: _numOrNull(json['price']) ?? 0,
    theirPrice: _numOrNull(json['their_price']),
    date: _dayOrNull(json['date']),
    createdAt: _timeOrNull(json['created_at']),
  );
}

/// An accepted order (a deal) or a completed one (a transaction), from
/// either side.
class OrderItem {
  final int id;
  final String status; // ACCEPTED / COMPLETED
  final bool iAmBuyer;
  final int? negotiationId;
  final String counterpartName;
  final String productType;
  final int quantity;
  final double pricePerUnit;
  final double totalValue;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final int? deliveredQuantity;
  final double? deliveredPrice;
  final DateTime? completedAt;

  /// A different final price waiting for (or decided by) an admin.
  final double? disputePrice;
  final String? disputeStatus; // PENDING / APPROVED / REJECTED

  const OrderItem({
    required this.id,
    required this.status,
    required this.iAmBuyer,
    required this.negotiationId,
    required this.counterpartName,
    required this.productType,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalValue,
    required this.dueDate,
    required this.createdAt,
    required this.deliveredQuantity,
    required this.deliveredPrice,
    required this.completedAt,
    required this.disputePrice,
    required this.disputeStatus,
  });

  bool get isCompleted => status == 'COMPLETED';

  /// "DL-2026-081": the year the deal was made and its order number.
  String get reference =>
      'DL-${(createdAt ?? DateTime.now()).year}-${id.toString().padLeft(3, '0')}';

  /// Whole days until delivery; negative when overdue.
  int? get daysUntilDue {
    final DateTime? due = dueDate;
    if (due == null) return null;
    final DateTime now = DateTime.now();
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool get dueSoon {
    final int? days = daysUntilDue;
    return !isCompleted && days != null && days <= 1;
  }

  /// What was delivered at the price that currently counts.
  double get settledTotal =>
      (deliveredQuantity ?? quantity) * (deliveredPrice ?? pricePerUnit);

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    id: json['id'] as int,
    status: json['status'] as String? ?? 'ACCEPTED',
    iAmBuyer: json['my_role'] == 'BUYER',
    negotiationId: json['negotiation_id'] as int?,
    counterpartName: json['counterpart_name'] as String? ?? '',
    productType: json['product_type'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    pricePerUnit: _numOrNull(json['final_price_per_unit']) ?? 0,
    totalValue: _numOrNull(json['total_value']) ?? 0,
    dueDate: _dayOrNull(json['due_date']),
    createdAt: _timeOrNull(json['created_at']),
    deliveredQuantity: (json['delivered_quantity'] as num?)?.toInt(),
    deliveredPrice: _numOrNull(json['delivered_price_per_unit']),
    completedAt: _timeOrNull(json['completed_at']),
    disputePrice: _numOrNull(json['dispute_price_per_unit']),
    disputeStatus: json['dispute_status'] as String?,
  );
}

class Activity {
  final List<PendingOffer> pending;
  final List<ChatSummary> negotiations;
  final List<OrderItem> deals;
  final List<OrderItem> transactions;

  const Activity({
    required this.pending,
    required this.negotiations,
    required this.deals,
    required this.transactions,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => [
      for (final item in json[key] as List? ?? const [])
        parse(item as Map<String, dynamic>),
    ];
    return Activity(
      pending: list('pending', PendingOffer.fromJson),
      negotiations: list('negotiations', ChatSummary.fromJson),
      deals: list('deals', OrderItem.fromJson),
      transactions: list('transactions', OrderItem.fromJson),
    );
  }
}

class ActivityService {
  ActivityService._();

  static Future<Activity> load() async {
    final data = await ApiClient.get('/api/activity');
    return Activity.fromJson(data as Map<String, dynamic>);
  }

  /// One of my deals or transactions, by order id.
  static Future<OrderItem?> findOrder(int orderId) async {
    final Activity activity = await load();
    for (final order in [...activity.deals, ...activity.transactions]) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  /// Throws an [ApiException] with code PRICE_REVIEW_REQUIRED's message if
  /// the price differs and [requestPriceReview] is false.
  static Future<void> completeDeal(
    int orderId, {
    required int deliveredQuantity,
    required double finalPricePerUnit,
    bool requestPriceReview = false,
    String? disputeNote,
  }) => ApiClient.post('/api/owner/orders/$orderId/complete', {
    'deliveredQuantity': deliveredQuantity,
    'finalPricePerUnit': finalPricePerUnit,
    'requestPriceReview': requestPriceReview,
    if (disputeNote != null && disputeNote.isNotEmpty)
      'disputeNote': disputeNote,
  });
}

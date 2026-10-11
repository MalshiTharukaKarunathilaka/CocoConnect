import 'api_client.dart';
import 'buyer_service.dart';

// Postgres numeric columns arrive as strings ("115.00").
double _toDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

double? _toDoubleOrNull(dynamic value) =>
    value == null ? null : _toDouble(value);

/// Trust scores of 0 (the column default) mean "not rated yet".
double? _rating(dynamic value) {
  final double? score = _toDoubleOrNull(value);
  return score == null || score <= 0 ? null : score;
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class Estate {
  final int id;
  final String estateName;
  final String ownerName;
  final String? location;
  final String? totalLandArea;
  final String? primaryCrop;
  final int? yearEstablished;
  final double? trustScore;

  const Estate({
    required this.id,
    required this.estateName,
    required this.ownerName,
    required this.location,
    this.totalLandArea,
    this.primaryCrop,
    this.yearEstablished,
    this.trustScore,
  });

  factory Estate.fromJson(Map<String, dynamic> json) => Estate(
    id: json['id'] as int,
    estateName: json['estate_name'] as String? ?? '',
    ownerName: json['name'] as String? ?? '',
    location: json['location'] as String?,
    totalLandArea: json['total_land_area'] as String?,
    primaryCrop: json['primary_crop'] as String?,
    yearEstablished: (json['year_established'] as num?)?.toInt(),
    trustScore: _rating(json['trust_score']),
  );
}

/// Everything the estate owner profile page shows.
class OwnerSummary {
  final Estate estate;
  final int activeListings;
  final int openChats;
  final int offersWaiting;
  final int ordersActive;
  final int ordersCompleted;

  const OwnerSummary({
    required this.estate,
    required this.activeListings,
    required this.openChats,
    required this.offersWaiting,
    required this.ordersActive,
    required this.ordersCompleted,
  });

  factory OwnerSummary.fromJson(Map<String, dynamic> json) => OwnerSummary(
    estate: Estate.fromJson(json['estate'] as Map<String, dynamic>),
    activeListings: (json['active_listings'] as num).toInt(),
    openChats: (json['open_chats'] as num).toInt(),
    offersWaiting: (json['offers_waiting'] as num).toInt(),
    ordersActive: (json['orders_active'] as num).toInt(),
    ordersCompleted: (json['orders_completed'] as num).toInt(),
  );
}

/// An open buyer request, as an estate owner sees it.
class OpenBuyerRequest {
  final int id;
  final String buyerName;
  final String? location;
  final String productType;
  final int quantity;
  final DateTime? requiredDate;
  final double bidPerUnit;
  final double? trustScore;

  /// This estate's offer on the request, if one was sent.
  final double? myOfferPrice;
  final String? myOfferStatus;

  /// From this estate owner's location; null when either side has none.
  final double? distanceKm;

  const OpenBuyerRequest({
    required this.id,
    required this.buyerName,
    required this.location,
    required this.productType,
    required this.quantity,
    required this.requiredDate,
    required this.bidPerUnit,
    required this.trustScore,
    required this.myOfferPrice,
    required this.myOfferStatus,
    this.distanceKm,
  });

  bool get offerSent => myOfferPrice != null;

  factory OpenBuyerRequest.fromJson(Map<String, dynamic> json) =>
      OpenBuyerRequest(
        id: json['id'] as int,
        buyerName: json['buyer_name'] as String? ?? 'Buyer',
        location: json['location'] as String?,
        productType: json['product_type'] as String? ?? '',
        quantity: (json['requested_quantity'] as num?)?.toInt() ?? 0,
        requiredDate: DateTime.tryParse('${json['required_date']}'),
        bidPerUnit: _toDouble(json['bidding_price_per_unit']),
        trustScore: _rating(json['trust_score']),
        myOfferPrice: _toDoubleOrNull(json['my_offer_price']),
        myOfferStatus: json['my_offer_status'] as String?,
        distanceKm: _toDoubleOrNull(json['distance_km']),
      );
}

/// An order on one of this estate's listings or accepted offers, as shown
/// in the Deal Window.
class Deal {
  final int id;
  final int? negotiationId;
  final int? buyerRequestId;
  final String status; // ACCEPTED / COMPLETED
  final String productType;
  final int quantity;
  final double pricePerUnit;
  final double totalValue;
  final String buyerName;
  final String? buyerLocation;
  final DateTime? dueDate;
  final DateTime? createdAt;
  final int? deliveredQuantity;
  final double? deliveredPrice;
  final DateTime? completedAt;

  const Deal({
    required this.id,
    required this.negotiationId,
    required this.buyerRequestId,
    required this.status,
    required this.productType,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalValue,
    required this.buyerName,
    required this.buyerLocation,
    required this.dueDate,
    required this.createdAt,
    required this.deliveredQuantity,
    required this.deliveredPrice,
    required this.completedAt,
  });

  bool get isCompleted => status == 'COMPLETED';

  /// "DL-2026-081": year the deal was made plus its order number.
  String get reference =>
      'DL-${(createdAt ?? DateTime.now()).year}-${id.toString().padLeft(3, '0')}';

  /// Whole days from today until delivery; negative when overdue.
  int? get daysUntilDue {
    final DateTime? due = dueDate;
    if (due == null) return null;
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return DateTime(due.year, due.month, due.day).difference(today).inDays;
  }

  factory Deal.fromJson(Map<String, dynamic> json) => Deal(
    id: json['id'] as int,
    negotiationId: json['negotiation_id'] as int?,
    buyerRequestId: json['buyer_request_id'] as int?,
    status: json['status'] as String? ?? 'ACCEPTED',
    productType: json['product_type'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    pricePerUnit: _toDouble(json['final_price_per_unit']),
    totalValue: _toDouble(json['total_value']),
    buyerName: json['buyer_name'] as String? ?? 'Buyer',
    buyerLocation: json['buyer_location'] as String?,
    // Plain dates come back as "YYYY-MM-DD"; keep them as local calendar days.
    dueDate: DateTime.tryParse('${json['due_date']}'.split('T').first),
    createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
    deliveredQuantity: (json['delivered_quantity'] as num?)?.toInt(),
    deliveredPrice: _toDoubleOrNull(json['delivered_price_per_unit']),
    completedAt: DateTime.tryParse('${json['completed_at']}')?.toLocal(),
  );
}

/// Recent prices for one product type, across all estates.
class MarketStats {
  final int? lastDealQuantity;
  final double? lastDealPrice;
  final double? todayAvgPrice;
  final double? weekAvgPrice;

  const MarketStats({
    required this.lastDealQuantity,
    required this.lastDealPrice,
    required this.todayAvgPrice,
    required this.weekAvgPrice,
  });

  factory MarketStats.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? last =
        json['last_deal'] as Map<String, dynamic>?;
    return MarketStats(
      lastDealQuantity: (last?['quantity'] as num?)?.toInt(),
      lastDealPrice: _toDoubleOrNull(last?['price']),
      todayAvgPrice: _toDoubleOrNull(json['today_avg_price']),
      weekAvgPrice: _toDoubleOrNull(json['week_avg_price']),
    );
  }
}

class OwnerService {
  OwnerService._();

  static Future<Estate> getEstate() async {
    final data = await ApiClient.get('/api/owner/estate');
    return Estate.fromJson(data as Map<String, dynamic>);
  }

  static Future<OwnerSummary> getSummary() async {
    final data = await ApiClient.get('/api/owner/summary');
    return OwnerSummary.fromJson(data as Map<String, dynamic>);
  }

  static Future<Estate> updateEstate({
    required String estateName,
    String? location,
    String? totalLandArea,
    String? primaryCrop,
    String? yearEstablished,
  }) async {
    final data = await ApiClient.patch('/api/owner/estate', {
      'estateName': estateName,
      'location': location ?? '',
      'totalLandArea': totalLandArea ?? '',
      'primaryCrop': primaryCrop ?? '',
      'yearEstablished': yearEstablished ?? '',
    });
    return Estate.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> createListing({
    required String productType,
    required int quantity,
    required String availableDate,
    required double pricePerUnit,
  }) async {
    await ApiClient.post('/api/owner/listings', {
      'productType': productType,
      'quantity': quantity,
      'availableDate': availableDate,
      'offerPricePerUnit': pricePerUnit,
    });
  }

  /// [sort] is 'price' (highest bid first), 'date' or 'nearest';
  /// [radiusKm] keeps buyers within that distance of the owner.
  static Future<List<OpenBuyerRequest>> getBuyerRequests({
    String? productType,
    int? radiusKm,
    String sort = 'price',
  }) async {
    final data = await ApiClient.get(
      '/api/owner/buyer-requests',
      query: {
        'type': ?productType,
        if (radiusKm != null) 'radiusKm': '$radiusKm',
        'sort': sort,
      },
    );
    return (data as List)
        .map((item) => OpenBuyerRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> sendOffer({
    required int buyerRequestId,
    required int quantity,
    required double pricePerUnit,
    DateTime? availableDate,
  }) async {
    await ApiClient.post('/api/owner/sell-requests', {
      'buyerRequestId': buyerRequestId,
      'quantity': quantity,
      'sellerPricePerUnit': pricePerUnit,
      if (availableDate != null) 'availableDate': _isoDate(availableDate),
    });
  }

  static Future<List<SellOffer>> getMyOffers() async {
    final data = await ApiClient.get('/api/owner/sell-requests');
    return (data as List)
        .map((item) => SellOffer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<List<NegotiationSummary>> getChats() async {
    final data = await ApiClient.get('/api/owner/negotiations');
    return (data as List)
        .map(
          (item) => NegotiationSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<Negotiation> getChat(int id) async {
    final data = await ApiClient.get('/api/owner/negotiations/$id');
    return Negotiation.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> reply(int id, {String? text, double? offerPrice}) async {
    await ApiClient.post('/api/owner/negotiations/$id/messages', {
      'message': ?text,
      'offerPricePerUnit': ?offerPrice,
    });
  }

  static Future<void> decline(int id) =>
      ApiClient.post('/api/owner/negotiations/$id/decline');

  static Future<List<Deal>> getDeals() async {
    final data = await ApiClient.get('/api/owner/orders');
    return (data as List)
        .map((item) => Deal.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Accepts the buyer's latest offer in a chat; creates the order.
  static Future<void> acceptChat(int negotiationId) =>
      ApiClient.post('/api/owner/negotiations/$negotiationId/accept');

  /// Marks a deal delivered with the actual quantity and price.
  static Future<void> completeDeal(
    int orderId, {
    required int deliveredQuantity,
    required double finalPricePerUnit,
  }) => ApiClient.post('/api/owner/orders/$orderId/complete', {
    'deliveredQuantity': deliveredQuantity,
    'finalPricePerUnit': finalPricePerUnit,
  });

  static Future<MarketStats> getMarketStats(String productType) async {
    final data = await ApiClient.get(
      '/api/owner/market-stats',
      query: {'type': productType},
    );
    return MarketStats.fromJson(data as Map<String, dynamic>);
  }
}

import 'api_client.dart';

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

class Listing {
  final int id;
  final String productType;
  final int quantity;
  final DateTime? availableDate;
  final double pricePerUnit;
  final String estateName;
  final String ownerName;
  final String? location;
  final double? trustScore;
  final DateTime? createdAt;

  /// From the buyer's saved location; null when either side has none.
  final double? distanceKm;

  const Listing({
    required this.id,
    required this.productType,
    required this.quantity,
    required this.availableDate,
    required this.pricePerUnit,
    required this.estateName,
    required this.ownerName,
    required this.location,
    required this.trustScore,
    required this.createdAt,
    this.distanceKm,
  });

  factory Listing.fromJson(Map<String, dynamic> json) => Listing(
    id: json['id'] as int,
    productType: json['product_type'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    availableDate: DateTime.tryParse('${json['available_date']}'),
    pricePerUnit: _toDouble(json['offer_price_per_unit']),
    estateName: json['estate_name'] as String? ?? 'Unknown estate',
    ownerName: json['owner_name'] as String? ?? '',
    location: json['location'] as String?,
    trustScore: _rating(json['trust_score']),
    createdAt: DateTime.tryParse('${json['created_at']}'),
    distanceKm: _toDoubleOrNull(json['distance_km']),
  );
}

class NegotiationMessage {
  final int id;
  final String? text;
  final double? offerPrice;
  final DateTime? createdAt;
  final bool isMine;

  const NegotiationMessage({
    required this.id,
    required this.text,
    required this.offerPrice,
    required this.createdAt,
    required this.isMine,
  });

  factory NegotiationMessage.fromJson(Map<String, dynamic> json) =>
      NegotiationMessage(
        id: json['id'] as int,
        text: json['message'] as String?,
        offerPrice: _toDoubleOrNull(json['offer_price_per_unit']),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        isMine: json['is_mine'] == true,
      );
}

class Negotiation {
  final int id;
  final String status; // OPEN / ACCEPTED / REJECTED
  final int? orderId;
  final String? orderStatus; // ACCEPTED / COMPLETED
  final Listing listing;
  final List<NegotiationMessage> messages;

  /// Set when an estate owner opens the chat.
  final String? buyerName;

  const Negotiation({
    required this.id,
    required this.status,
    required this.orderId,
    required this.orderStatus,
    required this.listing,
    required this.messages,
    this.buyerName,
  });

  /// The other side's latest counter-offer, or the listed price. For a buyer
  /// this is the estate owner's price that "Accept Deal" agrees to - the
  /// backend uses the same rule.
  double get priceOnTable {
    for (final message in messages.reversed) {
      if (!message.isMine && message.offerPrice != null) {
        return message.offerPrice!;
      }
    }
    return listing.pricePerUnit;
  }

  factory Negotiation.fromJson(Map<String, dynamic> json) => Negotiation(
    id: json['id'] as int,
    status: json['status'] as String,
    orderId: json['order_id'] as int?,
    orderStatus: json['order_status'] as String?,
    listing: Listing.fromJson(json['listing'] as Map<String, dynamic>),
    messages: (json['messages'] as List)
        .map((m) => NegotiationMessage.fromJson(m as Map<String, dynamic>))
        .toList(),
    buyerName: (json['buyer'] as Map<String, dynamic>?)?['name'] as String?,
  );
}

class BuyerRequest {
  final int id;
  final String productType;
  final int quantity;
  final DateTime? requiredDate;
  final double pricePerUnit;
  final String status; // PENDING, ACCEPTED once an offer is accepted
  final DateTime? createdAt;

  /// How many estate owners have sent an offer for this request.
  final int responseCount;

  const BuyerRequest({
    required this.id,
    required this.productType,
    required this.quantity,
    required this.requiredDate,
    required this.pricePerUnit,
    required this.status,
    required this.createdAt,
    this.responseCount = 0,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';

  factory BuyerRequest.fromJson(Map<String, dynamic> json) => BuyerRequest(
    id: json['id'] as int,
    productType: json['product_type'] as String? ?? '',
    quantity: (json['requested_quantity'] as num?)?.toInt() ?? 0,
    requiredDate: DateTime.tryParse('${json['required_date']}'),
    pricePerUnit: _toDouble(json['bidding_price_per_unit']),
    status: json['status'] as String? ?? 'PENDING',
    createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
    responseCount: _toDouble(json['response_count']).toInt(),
  );
}

/// An estate owner's offer (sell request) answering a buyer request.
class SellOffer {
  final int id;
  final int buyerRequestId;
  final String productType;
  final int quantity;
  final double pricePerUnit;
  final DateTime? availableDate;
  final String status; // pending / accepted / declined
  final String estateName;
  final String ownerName;
  final String? location;
  final double? trustScore;

  // Filled in when an estate owner lists the offers they sent.
  final String? buyerName;
  final int? requestedQuantity;
  final double? buyerBid;
  final DateTime? createdAt;
  final int? orderId;
  final String? orderStatus;

  const SellOffer({
    required this.id,
    required this.buyerRequestId,
    required this.productType,
    required this.quantity,
    required this.pricePerUnit,
    required this.availableDate,
    required this.status,
    required this.estateName,
    required this.ownerName,
    required this.location,
    required this.trustScore,
    this.buyerName,
    this.requestedQuantity,
    this.buyerBid,
    this.createdAt,
    this.orderId,
    this.orderStatus,
  });

  bool get isPending => status.toLowerCase() == 'pending';

  factory SellOffer.fromJson(Map<String, dynamic> json) => SellOffer(
    id: json['id'] as int,
    buyerRequestId: json['buyer_request_id'] as int,
    productType: json['product_type'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    pricePerUnit: _toDouble(json['seller_price_per_unit']),
    availableDate: DateTime.tryParse('${json['available_date']}'),
    status: json['status'] as String? ?? 'pending',
    estateName: json['estate_name'] as String? ?? '',
    ownerName: json['owner_name'] as String? ?? '',
    location: json['location'] as String?,
    trustScore: _rating(json['trust_score']),
    buyerName: json['buyer_name'] as String?,
    requestedQuantity: (json['requested_quantity'] as num?)?.toInt(),
    buyerBid: _toDoubleOrNull(json['bidding_price_per_unit']),
    createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
    orderId: json['order_id'] as int?,
    orderStatus: json['order_status'] as String?,
  );
}

class NegotiationSummary {
  final int id;
  final String status;
  final String? orderStatus;
  final String productType;
  final int quantity;
  final double listedPrice;
  final String estateName;
  final String ownerName;
  final int messageCount;
  final DateTime? createdAt;

  /// Set when an estate owner lists the chats on their listings.
  final String? buyerName;

  const NegotiationSummary({
    required this.id,
    required this.status,
    required this.orderStatus,
    required this.productType,
    required this.quantity,
    required this.listedPrice,
    required this.estateName,
    required this.ownerName,
    required this.messageCount,
    required this.createdAt,
    this.buyerName,
  });

  factory NegotiationSummary.fromJson(Map<String, dynamic> json) =>
      NegotiationSummary(
        id: json['id'] as int,
        status: json['status'] as String,
        orderStatus: json['order_status'] as String?,
        productType: json['product_type'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        listedPrice: _toDouble(json['offer_price_per_unit']),
        estateName: json['estate_name'] as String? ?? 'Unknown estate',
        ownerName: json['owner_name'] as String? ?? '',
        messageCount: _toDouble(json['message_count']).toInt(),
        createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
        buyerName: json['buyer_name'] as String?,
      );
}

class BuyerOrder {
  final int id;
  final int? negotiationId;
  final String status; // ACCEPTED / COMPLETED
  final String productType;
  final int quantity;
  final double pricePerUnit;
  final double totalValue;
  final String estateName;
  final DateTime? createdAt;

  /// Set when an estate owner lists their orders.
  final String? buyerName;

  /// Filled in when the estate owner completes the deal.
  final int? deliveredQuantity;
  final double? deliveredPrice;

  const BuyerOrder({
    required this.id,
    required this.negotiationId,
    required this.status,
    required this.productType,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalValue,
    required this.estateName,
    required this.createdAt,
    this.buyerName,
    this.deliveredQuantity,
    this.deliveredPrice,
  });

  factory BuyerOrder.fromJson(Map<String, dynamic> json) => BuyerOrder(
    id: json['id'] as int,
    negotiationId: json['negotiation_id'] as int?,
    status: json['status'] as String? ?? 'ACCEPTED',
    productType: json['product_type'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    pricePerUnit: _toDouble(json['final_price_per_unit']),
    totalValue: _toDouble(json['total_value']),
    estateName: json['estate_name'] as String? ?? 'Unknown estate',
    createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
    buyerName: json['buyer_name'] as String?,
    deliveredQuantity: (json['delivered_quantity'] as num?)?.toInt(),
    deliveredPrice: _toDoubleOrNull(json['delivered_price_per_unit']),
  );
}

/// Counts shown on the buyer profile page.
class BuyerSummary {
  final int openRequests;
  final int openChats;
  final int ordersActive;
  final int ordersCompleted;

  const BuyerSummary({
    required this.openRequests,
    required this.openChats,
    required this.ordersActive,
    required this.ordersCompleted,
  });

  factory BuyerSummary.fromJson(Map<String, dynamic> json) => BuyerSummary(
    openRequests: (json['open_requests'] as num).toInt(),
    openChats: (json['open_chats'] as num).toInt(),
    ordersActive: (json['orders_active'] as num).toInt(),
    ordersCompleted: (json['orders_completed'] as num).toInt(),
  );
}

enum ListingSort {
  newest('newest', 'Newest first', 'Newest'),
  priceLow('price_asc', 'Price: low to high', 'Lowest price'),
  priceHigh('price_desc', 'Price: high to low', 'Highest price'),
  trust('trust', 'Highest trust score', 'Top trust'),
  nearest('nearest', 'Nearest first', 'Nearest');

  final String apiValue;
  final String label;

  /// Fits on the Filter button.
  final String shortLabel;
  const ListingSort(this.apiValue, this.label, this.shortLabel);
}

class BuyerService {
  BuyerService._();

  static Future<List<Listing>> getListings({
    required String productType,
    ListingSort sort = ListingSort.newest,
    double? latitude,
    double? longitude,
    int? radiusKm,
    int? minQuantity,
    DateTime? requiredDate,
  }) async {
    final data = await ApiClient.get(
      '/api/buyer/listings',
      query: {
        'type': productType,
        'sort': sort.apiValue,
        if (latitude != null && longitude != null) ...{
          'lat': '$latitude',
          'lng': '$longitude',
        },
        if (radiusKm != null) 'radiusKm': '$radiusKm',
        // Matching a request: enough nuts, available within 7 days of it.
        if (minQuantity != null) 'minQuantity': '$minQuantity',
        if (requiredDate != null) 'requiredDate': _isoDate(requiredDate),
      },
    );
    return (data as List)
        .map((item) => Listing.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createRequest({
    required String productType,
    required int quantity,
    required DateTime requiredDate,
    required double pricePerUnit,
  }) async {
    await ApiClient.post('/api/buyer/requests', {
      'productType': productType,
      'requestedQuantity': quantity,
      'requiredDate': _isoDate(requiredDate),
      'biddingPricePerUnit': pricePerUnit,
    });
  }

  static Future<BuyerSummary> getSummary() async {
    final data = await ApiClient.get('/api/buyer/summary');
    return BuyerSummary.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<BuyerRequest>> getMyRequests() async {
    final data = await ApiClient.get('/api/buyer/requests');
    return (data as List)
        .map((item) => BuyerRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  static Future<void> updateRequest(
    int id, {
    required int quantity,
    required DateTime requiredDate,
    required double pricePerUnit,
  }) async {
    await ApiClient.put('/api/buyer/requests/$id', {
      'requestedQuantity': quantity,
      'requiredDate': _isoDate(requiredDate),
      'biddingPricePerUnit': pricePerUnit,
    });
  }

  static Future<List<SellOffer>> getRequestResponses(int requestId) async {
    final data = await ApiClient.get(
      '/api/buyer/requests/$requestId/responses',
    );
    return (data as List)
        .map((item) => SellOffer.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Accepts one estate owner's offer; creates an order and closes the
  /// request.
  static Future<void> acceptResponse(int sellOfferId) =>
      ApiClient.post('/api/buyer/responses/$sellOfferId/accept');

  static Future<void> deleteRequest(int id) =>
      ApiClient.delete('/api/buyer/requests/$id');

  static Future<List<NegotiationSummary>> getMyNegotiations() async {
    final data = await ApiClient.get('/api/buyer/negotiations');
    return (data as List)
        .map(
          (item) => NegotiationSummary.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<List<BuyerOrder>> getMyOrders() async {
    final data = await ApiClient.get('/api/buyer/orders');
    return (data as List)
        .map((item) => BuyerOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Starts a negotiation on [listingId], or reopens the open one.
  static Future<int> startNegotiation(int listingId) async {
    final data = await ApiClient.post('/api/buyer/negotiations', {
      'listingId': listingId,
    });
    return (data as Map<String, dynamic>)['id'] as int;
  }

  static Future<Negotiation> getNegotiation(int id) async {
    final data = await ApiClient.get('/api/buyer/negotiations/$id');
    return Negotiation.fromJson(data as Map<String, dynamic>);
  }

  static Future<NegotiationMessage> sendMessage(
    int negotiationId, {
    String? text,
    double? offerPrice,
  }) async {
    final data = await ApiClient.post(
      '/api/buyer/negotiations/$negotiationId/messages',
      {'message': ?text, 'offerPricePerUnit': ?offerPrice},
    );
    return NegotiationMessage.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> acceptDeal(int negotiationId) =>
      ApiClient.post('/api/buyer/negotiations/$negotiationId/accept');

  static Future<void> rejectDeal(int negotiationId) =>
      ApiClient.post('/api/buyer/negotiations/$negotiationId/reject');

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

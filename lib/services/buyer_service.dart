import 'api_client.dart';

// Postgres numeric columns arrive as strings ("115.00").
double _toDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

double? _toDoubleOrNull(dynamic value) =>
    value == null ? null : _toDouble(value);

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
    trustScore: _toDoubleOrNull(json['trust_score']),
    createdAt: DateTime.tryParse('${json['created_at']}'),
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

  const Negotiation({
    required this.id,
    required this.status,
    required this.orderId,
    required this.orderStatus,
    required this.listing,
    required this.messages,
  });

  /// The estate owner's latest counter-offer, or the listed price. This is
  /// the price "Accept Deal" agrees to - the backend uses the same rule.
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
  );
}

class BuyerRequest {
  final int id;
  final String productType;
  final int quantity;
  final DateTime? requiredDate;
  final double pricePerUnit;
  final String status; // PENDING, or whatever estate owners move it to
  final DateTime? createdAt;

  const BuyerRequest({
    required this.id,
    required this.productType,
    required this.quantity,
    required this.requiredDate,
    required this.pricePerUnit,
    required this.status,
    required this.createdAt,
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
  );
}

enum ListingSort {
  newest('newest', 'Newest first', 'Newest'),
  priceLow('price_asc', 'Price: low to high', 'Lowest price'),
  priceHigh('price_desc', 'Price: high to low', 'Highest price'),
  trust('trust', 'Highest trust score', 'Top trust');

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
  }) async {
    final data = await ApiClient.get(
      '/api/buyer/listings',
      query: {'type': productType, 'sort': sort.apiValue},
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

  static Future<void> completeOrder(int orderId) =>
      ApiClient.patch('/api/buyer/orders/$orderId/complete');

  static String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

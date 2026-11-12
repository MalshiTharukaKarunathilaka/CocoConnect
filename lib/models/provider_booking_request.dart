import 'package:latlong2/latlong.dart';

/// Preview state is owned by a calendar visit, never shared with Supabase.
enum ProviderRequestStatus { pending, confirmed, declined, cancelled }

enum RequestSpeaker { owner, provider }

class ProviderRequestMessage {
  final String text;
  final RequestSpeaker sender;
  final DateTime sentAt;
  final double? rate;
  const ProviderRequestMessage({
    required this.text,
    required this.sender,
    required this.sentAt,
    this.rate,
  });
}

class ProviderBookingRequest {
  final String? machineName;
  final int version;
  final int? ownerUserId;
  final String? providerName;
  final String? providerPhone;
  final List<Map<String, dynamic>> items;
  final String id;
  final String machineId;
  final String ownerName;
  final String estateName;
  final String address;
  final String? phone;
  final double? rating;
  final String? photoUrl;
  final String machinery;
  final String service;
  final double quantity;
  final String unit;
  final DateTime startsAt;
  final DateTime endsAt;
  final LatLng? estateAt;
  final LatLng? providerAt;
  final List<ProviderRequestMessage> messages;
  ProviderRequestStatus status = ProviderRequestStatus.pending;
  double proposedRate;
  RequestSpeaker proposedBy = RequestSpeaker.owner;
  bool customerAccepted = false;
  double? agreedRate;

  ProviderBookingRequest({
    this.machineName,
    this.version = 1,
    this.ownerUserId,
    this.providerName,
    this.providerPhone,
    this.items = const [],
    required this.id,
    required this.machineId,
    required this.ownerName,
    required this.estateName,
    required this.address,
    this.phone,
    this.rating,
    this.photoUrl,
    required this.machinery,
    required this.service,
    required this.quantity,
    required this.unit,
    required this.startsAt,
    required this.endsAt,
    this.estateAt,
    this.providerAt,
    required this.proposedRate,
    List<ProviderRequestMessage>? messages,
  }) : messages = messages ?? [];

  factory ProviderBookingRequest.fromJson(Map<String, dynamic> json) {
    double number(dynamic v) => double.parse('$v');
    DateTime local(dynamic value) {
      final utc = DateTime.parse(
        '$value',
      ).toUtc().add(const Duration(minutes: 330));
      return DateTime(
        utc.year,
        utc.month,
        utc.day,
        utc.hour,
        utc.minute,
        utc.second,
      );
    }

    LatLng? point(dynamic lat, dynamic lon) =>
        lat == null || lon == null ? null : LatLng(number(lat), number(lon));
    final owner = json['owner'] as Map;
    final provider = json['provider'] as Map;
    final items = (json['items'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final one = items.length == 1;
    final quantity = one ? number(items.first['quantity']) : 1.0;
    final request = ProviderBookingRequest(
      machineName: json['machine_name'] as String?,
      id: '${json['id']}',
      machineId: '${json['machine_id']}',
      version: json['version'] as int,
      ownerUserId: json['owner_user_id'] as int,
      ownerName: '${owner['name']}',
      providerName: '${provider['name']}',
      providerPhone: provider['phone'] as String?,
      estateName: '${json['estate_name']}',
      address: '${json['address']}',
      phone: owner['phone'] as String?,
      machinery: '${json['machinery']}',
      service: items.map((i) => '${i['name']}').join(' + '),
      quantity: quantity,
      unit: one ? '${items.first['unit']}' : 'booking',
      items: items,
      startsAt: local(json['starts_at']),
      endsAt: local(json['ends_at']),
      providerAt: point(provider['latitude'], provider['longitude']),
      estateAt: point(json['latitude'], json['longitude']),
      proposedRate: number(json['proposed_total']) / quantity,
      messages: (json['messages'] as List)
          .map(
            (m) => ProviderRequestMessage(
              text: '${m['message']}',
              sender: m['sender_id'] == json['owner_user_id']
                  ? RequestSpeaker.owner
                  : RequestSpeaker.provider,
              sentAt: local(m['created_at']),
              rate: m['offer_total'] == null
                  ? null
                  : number(m['offer_total']) / quantity,
            ),
          )
          .toList(),
    );
    request.status = switch (json['status']) {
      'PENDING' => ProviderRequestStatus.pending,
      'CONFIRMED' => ProviderRequestStatus.confirmed,
      'CANCELLED' => ProviderRequestStatus.cancelled,
      _ => ProviderRequestStatus.declined,
    };
    request.proposedBy = json['proposed_by'] == json['owner_user_id']
        ? RequestSpeaker.owner
        : RequestSpeaker.provider;
    request.customerAccepted = json['offer_agreed'] == true;
    request.agreedRate = json['agreed_total'] == null
        ? null
        : number(json['agreed_total']) / quantity;
    return request;
  }

  bool get isPending => status == ProviderRequestStatus.pending;
  bool get canAccept =>
      isPending && (proposedBy == RequestSpeaker.owner || customerAccepted);
  double get proposedTotal => proposedRate * quantity;
  double? get distanceKm => estateAt == null || providerAt == null
      ? null
      : const Distance().as(LengthUnit.Meter, providerAt!, estateAt!) / 1000;

  void sendMessage(String text) {
    if (!isPending) throw StateError('This request is already closed.');
    if (text.trim().isEmpty) throw ArgumentError('Enter a message.');
    messages.add(
      ProviderRequestMessage(
        text: text.trim(),
        sender: RequestSpeaker.provider,
        sentAt: DateTime.now(),
      ),
    );
  }

  void counter(double rate) {
    if (!isPending) throw StateError('This request is already closed.');
    if (!rate.isFinite || rate <= 0 || rate > 100000000) {
      throw ArgumentError('Enter a rate between 0 and Rs. 100,000,000.');
    }
    proposedRate = rate;
    proposedBy = RequestSpeaker.provider;
    customerAccepted = false;
    agreedRate = null;
    messages.add(
      ProviderRequestMessage(
        text: 'Proposed a new rate.',
        sender: RequestSpeaker.provider,
        sentAt: DateTime.now(),
        rate: rate,
      ),
    );
  }

  /// Explicit preview control, never an automated or real customer reply.
  void previewCustomerAccepts() {
    if (!isPending ||
        proposedBy != RequestSpeaker.provider ||
        customerAccepted) {
      return;
    }
    customerAccepted = true;
    messages.add(
      ProviderRequestMessage(
        text: 'Preview customer accepted the proposed rate.',
        sender: RequestSpeaker.owner,
        sentAt: DateTime.now(),
        rate: proposedRate,
      ),
    );
  }

  void accept(Iterable<ProviderBookingRequest> bookings) {
    if (!canAccept) {
      throw StateError('The customer must accept your counteroffer first.');
    }
    final conflict = bookings.any(
      (other) =>
          other.id != id &&
          other.status == ProviderRequestStatus.confirmed &&
          other.machineId == machineId &&
          startsAt.isBefore(other.endsAt) &&
          endsAt.isAfter(other.startsAt),
    );
    if (conflict) {
      throw StateError('This machine already has a booking in that time slot.');
    }
    agreedRate = proposedRate;
    status = ProviderRequestStatus.confirmed;
    messages.add(
      ProviderRequestMessage(
        text: 'Booking locked in this preview.',
        sender: RequestSpeaker.provider,
        sentAt: DateTime.now(),
        rate: agreedRate,
      ),
    );
  }

  void decline() {
    if (!isPending) throw StateError('This request is already closed.');
    status = ProviderRequestStatus.declined;
    messages.add(
      ProviderRequestMessage(
        text: 'Request declined in this preview.',
        sender: RequestSpeaker.provider,
        sentAt: DateTime.now(),
      ),
    );
  }
}

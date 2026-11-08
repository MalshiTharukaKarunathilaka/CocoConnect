import 'package:latlong2/latlong.dart';

/// Demo fertilizer catalogue + orders for the estate-owner / supplier flow.
/// Same logic as the HTML demo: 50 kg base unit, Pending Ack, one shop login.

class FertItem {
  FertItem({
    required this.name,
    required this.brand,
    required this.type,
    required this.price,
    required this.unit,
    required this.stock,
  });

  final String name;
  final String brand;
  final String type;
  final int price; // pack price
  final String unit; // e.g. "50 kg bag"
  final int stock; // packs on hand

  int get bagKg {
    final m = RegExp(r'(\d+)\s*kg', caseSensitive: false).firstMatch(unit);
    return int.tryParse(m?.group(1) ?? '') ?? 50;
  }

  int get perKg => (price / bagKg).round();
  int get price50 => perKg * 50;
  int get stock50 => (stock * bagKg / 50).floor();
}

class FertPlace {
  FertPlace({
    required this.id,
    required this.company,
    required this.who,
    required this.kind,
    required this.physical,
    required this.willingFar,
    required this.brands,
    required this.distanceKm,
    required this.dLat,
    required this.dLng,
    required this.items,
    this.phone = '',
  });

  final String id;
  final String company;
  final String who;
  final String kind; // shop | cdo
  final bool physical;
  final bool willingFar;
  final List<String> brands;
  final double distanceKm;
  final double dLat;
  final double dLng;
  final List<FertItem> items;
  final String phone;

  bool get isGov => kind == 'cdo';
  int get minPrice50 =>
      items.map((i) => i.price50).reduce((a, b) => a < b ? a : b);
  String get brandLine => brands.join(' + ');
}

class CartLine {
  CartLine({required this.item, required this.qty50});
  final FertItem item;
  int qty50;
  int get lineTotal => item.price50 * qty50;
}

class FertOrder {
  FertOrder({
    required this.id,
    required this.placeId,
    required this.company,
    required this.agent,
    required this.owner,
    required this.product,
    required this.items,
    required this.qty50,
    required this.price,
    required this.preferredDate,
    required this.slot,
    required this.status,
    required this.message,
    this.negotiation = const [],
  });

  final String id;
  final String placeId;
  final String company;
  final String agent;
  final String owner;
  final String product;
  final List<CartLine> items;
  final int qty50;
  final int price;
  final DateTime preferredDate;
  final String slot;
  String status; // Pending Ack | Accepted | Cancelled | Negotiating
  final String message;
  final List<FertChat> negotiation;
}

class FertChat {
  const FertChat(this.from, this.text, this.time);
  final String from;
  final String text;
  final String time;
}

class FertDayAvail {
  FertDayAvail({required this.mode, this.qty});
  String mode; // units | unlimited
  int? qty;
}

/// In-memory session store (demo only).
class FertilizerStore {
  FertilizerStore._();
  static final FertilizerStore instance = FertilizerStore._();

  /// Logged-in supplier shop (one login = one shop).
  String agentShopId = 'PL4';

  final List<FertPlace> places = [
    FertPlace(
      id: 'PL4',
      company: 'Nadeesha Stores',
      who: 'Nadeesha Perera',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['CIC', 'Baurs'],
      distanceKm: 1.6,
      dLat: 0.012,
      dLng: -0.008,
      phone: '077 111 2233',
      items: [
        FertItem(
          name: 'CIC Urea',
          brand: 'CIC',
          type: 'Urea',
          price: 5900,
          unit: '50 kg bag',
          stock: 20,
        ),
        FertItem(
          name: 'Baurs Coconut Blend',
          brand: 'Baurs',
          type: 'Coconut mix',
          price: 7000,
          unit: '50 kg bag',
          stock: 14,
        ),
      ],
    ),
    FertPlace(
      id: 'PL4b',
      company: 'Leaf Point',
      who: 'Kasun Silva',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Hayleys'],
      distanceKm: 1.6,
      dLat: 0.012,
      dLng: -0.008,
      phone: '077 555 0101',
      items: [
        FertItem(
          name: 'Hayleys Organic',
          brand: 'Hayleys',
          type: 'Organic',
          price: 5200,
          unit: '25 kg bag',
          stock: 18,
        ),
      ],
    ),
    FertPlace(
      id: 'PL1',
      company: 'CIC Agri',
      who: 'Ruwan Perera',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['CIC'],
      distanceKm: 4.2,
      dLat: -0.028,
      dLng: 0.018,
      phone: '077 200 3344',
      items: [
        FertItem(
          name: 'Coconut Fertilizer Mix',
          brand: 'CIC',
          type: 'Coconut mix',
          price: 6850,
          unit: '50 kg bag',
          stock: 42,
        ),
        FertItem(
          name: 'Urea',
          brand: 'CIC',
          type: 'Urea',
          price: 6100,
          unit: '50 kg bag',
          stock: 8,
        ),
      ],
    ),
    FertPlace(
      id: 'PL3',
      company: 'Hayleys Agriculture',
      who: 'Nimali Silva',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Hayleys'],
      distanceKm: 6.8,
      dLat: -0.04,
      dLng: -0.035,
      items: [
        FertItem(
          name: 'Organic Soil Enricher',
          brand: 'Hayleys',
          type: 'Organic',
          price: 4900,
          unit: '25 kg bag',
          stock: 16,
        ),
      ],
    ),
    FertPlace(
      id: 'PL5',
      company: 'CDO Area 01',
      who: 'CDO - Mawathagama',
      kind: 'cdo',
      physical: true,
      willingFar: true,
      brands: const ['CCB'],
      distanceKm: 10,
      dLat: 0.055,
      dLng: 0.04,
      phone: '037 222 3344',
      items: [
        FertItem(
          name: 'ERP Coconut Fertilizer',
          brand: 'CCB',
          type: 'Government',
          price: 6000,
          unit: '50 kg bag',
          stock: 120,
        ),
        FertItem(
          name: 'Urea subsidy',
          brand: 'CCB',
          type: 'Urea',
          price: 4200,
          unit: '50 kg bag',
          stock: 80,
        ),
      ],
    ),
    FertPlace(
      id: 'PL6',
      company: 'CIC Depot Colombo',
      who: 'CIC warehouse',
      kind: 'shop',
      physical: false,
      willingFar: true,
      brands: const ['CIC'],
      distanceKm: 86,
      dLat: 0.09,
      dLng: 0.06,
      items: [
        FertItem(
          name: 'Coconut Fertilizer Mix',
          brand: 'CIC',
          type: 'Coconut mix',
          price: 7100,
          unit: '50 kg bag',
          stock: 200,
        ),
      ],
    ),
  ];

  late final List<FertOrder> orders = [
    FertOrder(
      id: 'PO-410',
      placeId: 'PL4',
      company: 'Nadeesha Stores',
      agent: 'Nadeesha Perera',
      owner: 'Your Estate',
      product: 'CIC Urea (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL4').items.first,
          qty50: 10,
        ),
      ],
      qty50: 10,
      price: 59000,
      preferredDate: DateTime(2026, 11, 8),
      slot: 'Morning 8–11',
      status: 'Pending Ack',
      message: 'Need urea for the lower block this week.',
    ),
    FertOrder(
      id: 'PO-411',
      placeId: 'PL4',
      company: 'Nadeesha Stores',
      agent: 'Nadeesha Perera',
      owner: 'Green Palm Estate',
      product: 'Baurs Coconut Blend (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL4').items[1],
          qty50: 6,
        ),
      ],
      qty50: 6,
      price: 42000,
      preferredDate: DateTime(2026, 11, 8),
      slot: 'Afternoon 12–3',
      status: 'Pending Ack',
      message: 'Can you deliver Friday afternoon?',
      negotiation: const [
        FertChat(
          'Green Palm Estate',
          'Can you do Friday afternoon and confirm Baurs bag size?',
          '10:05',
        ),
        FertChat(
          'Nadeesha Stores',
          'Yes, Friday 12–3 works. Baurs blend is 50 kg bags.',
          '10:22',
        ),
      ],
    ),
    FertOrder(
      id: 'PO-412',
      placeId: 'PL4',
      company: 'Nadeesha Stores',
      agent: 'Nadeesha Perera',
      owner: 'Estate A',
      product: 'CIC Urea (50 kg), Baurs Coconut Blend (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL4').items.first,
          qty50: 4,
        ),
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL4').items[1],
          qty50: 4,
        ),
      ],
      qty50: 8,
      price: 51600,
      preferredDate: DateTime(2026, 11, 9),
      slot: 'Morning 8–11',
      status: 'Pending Ack',
      message: 'Mixed cart for 8-acre estate.',
    ),
    FertOrder(
      id: 'PO-413',
      placeId: 'PL4',
      company: 'Nadeesha Stores',
      agent: 'Nadeesha Perera',
      owner: 'Estate F',
      product: 'CIC Urea (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL4').items.first,
          qty50: 12,
        ),
      ],
      qty50: 12,
      price: 70800,
      preferredDate: DateTime(2026, 11, 10),
      slot: 'Evening 3–6',
      status: 'Pending Ack',
      message: 'Urgent — palms need urea after rains.',
    ),
    FertOrder(
      id: 'PO-420',
      placeId: 'PL4',
      company: 'Nadeesha Stores',
      agent: 'Nadeesha Perera',
      owner: 'Your Estate',
      product: 'CIC Urea (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL4').items.first,
          qty50: 6,
        ),
      ],
      qty50: 6,
      price: 35400,
      preferredDate: DateTime(2026, 11, 7),
      slot: 'Morning 8–11',
      status: 'Accepted',
      message: 'Already accepted sample order.',
    ),
  ];

  /// dateKey yyyy-MM-dd -> itemKey placeId::name -> availability
  final Map<String, Map<String, FertDayAvail>> availability = {};

  /// Shop-level map chat (owner ↔ shop), separate from per-order negotiation.
  final Map<String, List<FertChat>> shopTalks = {
    'PL4': const [
      FertChat(
        'You',
        'What colour are the CIC bags, and what is your phone number?',
        '9:10',
      ),
      FertChat(
        'Nadeesha Stores',
        'Green and white bags. Call 077 111 2233.',
        '9:18',
      ),
    ],
  };

  static const estateGeo = {
    'Your Estate': LatLng(7.4863, 80.3647),
    'Green Palm Estate': LatLng(7.5010, 80.3520),
    'Estate A': LatLng(7.4720, 80.3810),
    'Estate F': LatLng(7.4550, 80.3480),
  };

  FertPlace? placeById(String id) {
    for (final p in places) {
      if (p.id == id) return p;
    }
    return null;
  }

  FertPlace get myShop =>
      placeById(agentShopId) ?? places.firstWhere((p) => p.kind == 'shop');

  List<FertOrder> get myShopOrders =>
      orders.where((o) => o.placeId == agentShopId).toList();

  List<FertOrder> get pendingAck => myShopOrders
      .where((o) => o.status == 'Pending Ack' || o.status == 'Negotiating')
      .toList();

  List<FertOrder> ownerOrders(String owner) =>
      orders.where((o) => o.owner == owner).toList();

  String nextId() => 'PO-${410 + orders.length + 1}';

  void placeOrder(FertOrder order) => orders.insert(0, order);

  void cancelOrder(String id) {
    for (final o in orders) {
      if (o.id == id &&
          (o.status == 'Pending Ack' || o.status == 'Negotiating')) {
        o.status = 'Cancelled';
        return;
      }
    }
  }

  void acceptOrder(String id) {
    for (final o in orders) {
      if (o.id == id) {
        o.status = 'Accepted';
        return;
      }
    }
  }
}

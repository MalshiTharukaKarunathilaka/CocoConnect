import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';

/// Demo fertilizer catalogue + orders for the estate-owner / supplier flow.
/// Same logic as the HTML demo: 50 kg base unit, Pending Ack, one shop login.

/// Which home calendar to show after login.
enum FertHomeMode { supplier, cdo }

/// The standard fertilizer types people search by.
const List<String> kFertKinds = ['APM', 'YPM', 'MOP', 'ERP', 'TSP', 'Urea', 'Dolomite'];

/// Brand filter chips on the map (same idea as Distance / Fertilizer).
/// Private-brand filter only (CCB stays under Government supplier filter).
const List<String> kFertBrands = ['CIC', 'Hayleys', 'Baurs'];

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
  int price; // pack price — supplier can update for market reasons
  final String unit; // e.g. "50 kg bag"
  int stock; // packs on hand — supplier updates in Stock tab

  /// Which of the standard types (APM, YPM, MOP, ERP, TSP, Urea, Dolomite) this product is.
  Set<String> get kinds {
    final text = '$name $type';
    final out = <String>{
      for (final k in kFertKinds)
        if (RegExp('\\b$k\\b', caseSensitive: false).hasMatch(text)) k,
    };
    // a coconut mix is made of urea, MOP and ERP
    if (type == 'Coconut mix') out.addAll(const ['Urea', 'MOP', 'ERP']);
    return out;
  }

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
    this.coverageNote = '',
    this.absLat,
    this.absLng,
    this.region = 'kurunegala',
  });

  final String id;
  final String company;
  String who;
  final String kind; // shop | cdo
  final bool physical;
  bool willingFar;
  final List<String> brands;
  double distanceKm;
  final double dLat;
  final double dLng;
  final List<FertItem> items;
  String phone;
  /// Free-text coverage note the supplier can edit on Profile.
  String coverageNote;
  /// Absolute map pin (Colombo / Puttalam / …). Null = offset from estate.
  final double? absLat;
  final double? absLng;
  /// Which demo region this outlet belongs to.
  final String region;

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

/// One row in the supplier Messages inbox.
class FertSupplierThread {
  const FertSupplierThread({
    required this.owner,
    required this.preview,
    required this.unread,
  });
  final String owner;
  final String preview;
  final int unread;
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
    List<FertChat>? negotiation,
    this.ownerStars,
    this.supplierStars,
    this.ownerRateNote = '',
    this.supplierRateNote = '',
  }) : negotiation = List<FertChat>.from(negotiation ?? const []);

  final String id;
  final String placeId;
  final String company;
  final String agent;
  final String owner;
  String product;
  final List<CartLine> items;
  int qty50;
  int price;
  DateTime preferredDate;
  String slot;
  /// Pending Ack | Negotiating | Accepted | Distributed | Completed | Cancelled | Disputed
  String status;
  String message;
  /// Chat notes between estate and supplier on this order.
  final List<FertChat> negotiation;
  /// Owner rates the supplier after completion (1–5).
  int? ownerStars;
  /// Supplier rates the estate owner after completion (1–5).
  int? supplierStars;
  String ownerRateNote;
  String supplierRateNote;

  /// Why: cancelled / disputed / delivered / completed jobs leave the calendar.
  bool get showsOnCalendar =>
      status != 'Cancelled' &&
      status != 'Disputed' &&
      status != 'Distributed' &&
      status != 'Completed';

  bool get isPendingAck =>
      status == 'Pending Ack' || status == 'Submitted';

  bool get isNegotiating => status == 'Negotiating';

  bool get isAcceptedOnCalendar =>
      status == 'Accepted' || status == 'Stock Confirmed';

  bool get awaitingOwnerConfirm => status == 'Distributed';

  bool get isCompleted => status == 'Completed';

  /// Why: after the owner changes bag counts, total bags and price must match the lines.
  void refreshTotals() {
    qty50 = items.fold(0, (s, l) => s + l.qty50);
    price = items.fold(0, (s, l) => s + l.lineTotal);
    product = items
        .where((l) => l.qty50 > 0)
        .map((l) => '${l.item.brand} ${l.item.name} (50 kg)')
        .join(', ');
  }
}

class FertChat {
  const FertChat(this.from, this.text, this.time);
  final String from;
  final String text;
  final String time;
}

/// Alert for the estate owner when a supplier accepts, cancels, negotiates, etc.
class FertOwnerAlert {
  FertOwnerAlert({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.at,
    this.orderId = '',
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  /// new_order | cancelled | estate_dispute | low_stock | (legacy kinds ignored for supplier bell)
  final String kind;
  final DateTime at;
  final String orderId;
  bool read;

  /// Why: Show can open Stock when there is no order id (low-stock alerts).
  bool get opensStock =>
      kind == 'low_stock' || title.toLowerCase().contains('low stock');

  /// Why: supplier bell only shows alerts that need quick attention.
  bool get isImportantForSupplier =>
      kind == 'low_stock' ||
      kind == 'new_order' ||
      kind == 'cancelled' ||
      kind == 'estate_dispute' ||
      opensStock;

  /// Why: CDO bell mirrors supplier — cancel, dispute, low stock, new requests.
  bool get isImportantForCdo => isImportantForSupplier;
}

class FertDayAvail {
  FertDayAvail({required this.mode, this.qty});
  String mode; // units | unlimited
  int? qty;
}

/// What the owner picked in the order sheet for a government supplier, before the request form.
class GovOrderDraft {
  GovOrderDraft({required this.lines, required this.date, required this.slot});
  final List<CartLine> lines;
  final DateTime date;
  final String slot;

  int get bags => lines.fold(0, (s, l) => s + l.qty50);
  int get total => lines.fold(0, (s, l) => s + l.lineTotal);
  String get summary =>
      lines.map((l) => '${l.item.name} \u00d7 ${l.qty50}').join(', ');
}

/// Logged-in owner's estate card used to auto-fill the CCB fertilizer form.
/// Why: Annex 01 estate/size fields come from the account — owners cannot type them.
class FertOwnerProfile {
  const FertOwnerProfile({
    required this.fullName,
    required this.address,
    required this.phone,
    required this.nicNumber,
    required this.landAddress,
    required this.deedNumber,
    required this.acres,
    this.roods = 0,
    this.perches = 0,
    required this.coconutTrees,
    required this.coconutSaplings,
    required this.annualHarvestNuts,
    this.district = 'Kurunegala',
    this.estateName = 'Mawathagama Palm Estate',
  });

  final String fullName;
  final String address;
  final String phone;
  final String nicNumber;
  final String landAddress;
  final String deedNumber;
  final int acres;
  final int roods;
  final int perches;
  final int coconutTrees;
  final int coconutSaplings;
  final int annualHarvestNuts;
  final String district;
  final String estateName;

  String get landSizeLabel {
    final parts = <String>['$acres A'];
    if (roods > 0) parts.add('$roods R');
    if (perches > 0) parts.add('$perches P');
    return parts.join(' · ');
  }
}

class FertGovRequest {
  FertGovRequest({
    required this.id,
    required this.owner,
    required this.fertilizer,
    required this.requested,
    required this.status,
    required this.cdo,
    required this.date,
    this.district = 'Kurunegala',
    this.approved = 0,
    this.distributed = 0,
    this.estateName = '',
    this.acres = 0,
    this.nicCopy = '',
    this.landTitleCopy = '',
    this.outlet = '',
    this.preferred = '',
    this.beneficiaryName = '',
    this.address = '',
    this.phone = '',
    this.nicNumber = '',
    this.landAddress = '',
    this.deedNumber = '',
    this.roods = 0,
    this.perches = 0,
    this.coconutTrees = 0,
    this.coconutSaplings = 0,
    this.annualHarvestNuts = 0,
    this.deliveryAt,
    List<FertChat>? chat,
  }) : chat = List<FertChat>.from(chat ?? const []);

  final String id;
  final String owner;
  final String fertilizer;
  final int requested;
  String status;
  final String cdo;
  final DateTime date;
  final String district;
  int approved;
  int distributed;
  /// Planned / confirmed delivery moment shown in CDO ↔ estate chat.
  DateTime? deliveryAt;
  /// CDO ↔ estate messages for this government application.
  final List<FertChat> chat;

  // From the request form (Annex 01 / RH/AGRI/CCB/01)
  final String estateName;
  final double acres;
  final String nicCopy; // file name of the attached NIC copy
  final String landTitleCopy; // file name of the attached land title / deed copy
  final String outlet; // the government outlet it was ordered from
  final String preferred; // preferred date and time slot
  final String beneficiaryName;
  final String address;
  final String phone;
  final String nicNumber;
  final String landAddress;
  final String deedNumber;
  final int roods;
  final int perches;
  final int coconutTrees;
  final int coconutSaplings;
  final int annualHarvestNuts;

  /// Why: delivered / cancelled / disputed leave the CDO calendar.
  bool get showsOnCalendar =>
      status != 'Cancelled' &&
      status != 'Disputed' &&
      status != 'Distributed' &&
      distributed == 0;

  bool get isPendingAck =>
      status == 'Pending Ack' || status == 'Submitted';

  bool get isAcceptedOnCalendar =>
      status == 'Accepted' || status == 'Receipt Confirmed';
}

class FertComplaint {
  FertComplaint({
    required this.id,
    required this.category,
    required this.product,
    required this.status,
    required this.date,
    required this.description,
    this.owner = 'Mawathagama Palm Estate',
    this.district = 'Kurunegala',
  });

  final String id;
  final String category;
  final String product;
  String status;
  final DateTime date;
  final String description;
  final String owner;
  final String district;
}

/// In-memory session store (demo only).
class FertilizerStore {
  FertilizerStore._();
  static final FertilizerStore instance = FertilizerStore._();

  /// Logged-in supplier shop (one login = one shop).
  String agentShopId = 'PL4';

  /// Logged-in CDO place (government office).
  String cdoPlaceId = 'PL5';

  /// Estate name key for the logged-in owner (orders / complaints / gov).
  String boundOwnerKey = 'Mawathagama Palm Estate';

  /// Demo region for map filtering: kurunegala | colombo | puttalam.
  String ownerRegion = 'kurunegala';

  FertHomeMode homeMode = FertHomeMode.supplier;

  /// Estate-owner alerts (supplier accept / cancel / negotiate…).
  final List<FertOwnerAlert> ownerAlerts = [];

  /// Supplier alerts (new order, dispute, low stock…).
  final List<FertOwnerAlert> supplierAlerts = [];

  /// CDO desk alerts (estate cancel / dispute, low warehouse stock, new request).
  final List<FertOwnerAlert> cdoAlerts = [];

  /// Bumps whenever a new alert arrives so the hub bell can refresh.
  final ValueNotifier<int> ownerAlertTick = ValueNotifier<int>(0);
  final ValueNotifier<int> supplierAlertTick = ValueNotifier<int>(0);
  final ValueNotifier<int> cdoAlertTick = ValueNotifier<int>(0);

  int get unreadOwnerAlerts => ownerAlerts.where((a) => !a.read).length;
  /// Only attention-needed alerts for the supplier bell.
  List<FertOwnerAlert> get importantSupplierAlerts =>
      supplierAlerts.where((a) => a.isImportantForSupplier).toList();

  int get unreadSupplierAlerts =>
      importantSupplierAlerts.where((a) => !a.read).length;

  List<FertOwnerAlert> get importantCdoAlerts =>
      cdoAlerts.where((a) => a.isImportantForCdo).toList();

  int get unreadCdoAlerts => importantCdoAlerts.where((a) => !a.read).length;

  void notifyOwner({
    required String title,
    required String body,
    required String kind,
    String orderId = '',
  }) {
    ownerAlerts.insert(
      0,
      FertOwnerAlert(
        id: 'AL-${ownerAlerts.length + 1}-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        kind: kind,
        at: DateTime.now(),
        orderId: orderId,
      ),
    );
    ownerAlertTick.value++;
  }

  void notifySupplier({
    required String title,
    required String body,
    required String kind,
    String orderId = '',
  }) {
    supplierAlerts.insert(
      0,
      FertOwnerAlert(
        id: 'SA-${supplierAlerts.length + 1}-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        kind: kind,
        at: DateTime.now(),
        orderId: orderId,
      ),
    );
    supplierAlertTick.value++;
  }

  void notifyCdo({
    required String title,
    required String body,
    required String kind,
    String orderId = '',
  }) {
    cdoAlerts.insert(
      0,
      FertOwnerAlert(
        id: 'CA-${cdoAlerts.length + 1}-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        kind: kind,
        at: DateTime.now(),
        orderId: orderId,
      ),
    );
    cdoAlertTick.value++;
  }

  void markOwnerAlertsRead() {
    for (final a in ownerAlerts) {
      a.read = true;
    }
    ownerAlertTick.value++;
  }

  void markSupplierAlertsRead() {
    for (final a in supplierAlerts) {
      a.read = true;
    }
    supplierAlertTick.value++;
  }

  void markCdoAlertsRead() {
    for (final a in cdoAlerts) {
      a.read = true;
    }
    cdoAlertTick.value++;
  }

  /// Low-stock threshold in 50 kg bag units.
  static const int lowStockBags = 10;

  void checkLowStock(FertPlace shop) {
    for (final item in shop.items) {
      if (item.stock50 > 0 && item.stock50 <= lowStockBags) {
        final title = 'Low stock · ${item.name}';
        // Why: avoid flooding the bell every time the Stock tab opens.
        final already = supplierAlerts.any(
          (a) => a.title == title && !a.read,
        );
        if (already) continue;
        notifySupplier(
          title: title,
          body:
              'Only ${item.stock50} × 50 kg left. Update Stock or raise the price.',
          kind: 'low_stock',
        );
      }
    }
  }

  /// Why: CDO warehouse also warns when a line drops to / under the bag limit.
  void checkCdoLowStock() {
    for (final line in cdoStock) {
      if (line.bags > 0 && line.bags <= lowStockBags) {
        final title = 'Low stock · ${line.type}';
        final already = cdoAlerts.any((a) => a.title == title && !a.read);
        if (already) continue;
        notifyCdo(
          title: title,
          body:
              'Only ${line.bags} × 50 kg left at the CDO warehouse. Update Stock.',
          kind: 'low_stock',
        );
      }
    }
  }

  /// Auto-filled CCB form details for the logged-in estate owner (demo values).
  FertOwnerProfile ownerProfile = const FertOwnerProfile(
    fullName: 'Demo Estate Owner',
    address: 'No. 12, Temple Road, Mawathagama',
    phone: '0711000001',
    nicNumber: '198512345678',
    landAddress: 'Mawathagama Palm Estate, Mawathagama, Kurunegala',
    deedNumber: 'KUR/MWT/2018/0456',
    acres: 8,
    roods: 0,
    perches: 0,
    coconutTrees: 640,
    coconutSaplings: 80,
    annualHarvestNuts: 42000,
    district: 'Kurunegala',
    estateName: 'Mawathagama Palm Estate',
  );

  /// Demo estate cards keyed by last-9 phone digits.
  static const Map<String, FertOwnerProfile> demoOwnerProfiles = {
    '711000001': FertOwnerProfile(
      fullName: 'Demo Estate Owner',
      address: 'No. 12, Temple Road, Mawathagama',
      phone: '0711000001',
      nicNumber: '198512345678',
      landAddress: 'Mawathagama Palm Estate, Mawathagama, Kurunegala',
      deedNumber: 'KUR/MWT/2018/0456',
      acres: 8,
      coconutTrees: 640,
      coconutSaplings: 80,
      annualHarvestNuts: 42000,
      district: 'Kurunegala',
      estateName: 'Mawathagama Palm Estate',
    ),
    '712000011': FertOwnerProfile(
      fullName: 'Nushrath Silva',
      address: '42 Marine Drive, Colombo 03',
      phone: '0712000011',
      nicNumber: '199012345678',
      landAddress: 'Colombo Palm Estate, Kaduwela, Colombo',
      deedNumber: 'COL/KDW/2020/1188',
      acres: 6,
      coconutTrees: 480,
      coconutSaplings: 60,
      annualHarvestNuts: 28000,
      district: 'Colombo',
      estateName: 'Colombo Palm Estate',
    ),
    '712000022': FertOwnerProfile(
      fullName: 'Kamal Fernando',
      address: '15 Beach Road, Puttalam',
      phone: '0712000022',
      nicNumber: '198712345678',
      landAddress: 'Puttalam Coast Estate, Chilaw, Puttalam',
      deedNumber: 'PUT/CHW/2019/0771',
      acres: 10,
      coconutTrees: 820,
      coconutSaplings: 100,
      annualHarvestNuts: 51000,
      district: 'Puttalam',
      estateName: 'Puttalam Coast Estate',
    ),
  };

  static String regionForDistrict(String district) {
    final d = district.toLowerCase();
    if (d.contains('colombo')) return 'colombo';
    if (d.contains('puttalam')) return 'puttalam';
    return 'kurunegala';
  }

  static String _last9(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    return digits.length > 9 ? digits.substring(digits.length - 9) : digits;
  }

  /// Tie the fertilizer demo store to the real login (phone / role).
  /// Why: one phone should only see that person's shop, CDO desk, or estate.
  void bindUser(AppUser user) {
    final key = _last9(user.phone);
    if (user.role == 'ESTATE_OWNER') {
      final demo = demoOwnerProfiles[key];
      final estateName = demo?.estateName ??
          (user.name.trim().isEmpty
              ? 'My Estate'
              : "${user.name.trim()}'s Estate");
      ownerProfile = FertOwnerProfile(
        fullName: user.name.trim().isEmpty
            ? (demo?.fullName ?? ownerProfile.fullName)
            : user.name.trim(),
        address: (user.location ?? '').trim().isEmpty
            ? (demo?.address ?? ownerProfile.address)
            : user.location!.trim(),
        phone: user.phone,
        nicNumber: demo?.nicNumber ?? ownerProfile.nicNumber,
        landAddress: demo?.landAddress ??
            '$estateName, ${user.location ?? ownerProfile.district}',
        deedNumber: demo?.deedNumber ?? ownerProfile.deedNumber,
        acres: demo?.acres ?? ownerProfile.acres,
        roods: demo?.roods ?? ownerProfile.roods,
        perches: demo?.perches ?? ownerProfile.perches,
        coconutTrees: demo?.coconutTrees ?? ownerProfile.coconutTrees,
        coconutSaplings: demo?.coconutSaplings ?? ownerProfile.coconutSaplings,
        annualHarvestNuts:
            demo?.annualHarvestNuts ?? ownerProfile.annualHarvestNuts,
        district: demo?.district ??
            ((user.location ?? '').trim().isEmpty
                ? ownerProfile.district
                : user.location!.trim()),
        estateName: estateName,
      );
      boundOwnerKey = estateName;
      ownerRegion = regionForDistrict(ownerProfile.district);
      if (user.latitude != null && user.longitude != null) {
        estateGeo[estateName] = LatLng(user.latitude!, user.longitude!);
      }
      return;
    }
    if (user.role == 'CDO') {
      homeMode = FertHomeMode.cdo;
      final profile = AuthService.cdoProfile;
      final district = '${profile?['assigned_district'] ?? user.location ?? ''}';
      ownerRegion = regionForDistrict(
        district.isEmpty ? 'Kurunegala' : district,
      );
      _ensureRegisteredCdoPlace(user);
      final match = places.where(
        (p) => p.kind == 'cdo' && _last9(p.phone) == key,
      );
      cdoPlaceId = match.isNotEmpty
          ? match.first.id
          : places.firstWhere((p) => p.kind == 'cdo').id;
      agentShopId = cdoPlaceId;
      return;
    }

    homeMode = FertHomeMode.supplier;
    if (user.role == 'FERTILIZER_SUPPLIER') {
      _ensureRegisteredSupplierPlace(user);
    }
    final match = places.where(
      (p) => p.kind == 'shop' && _last9(p.phone) == key,
    );
    agentShopId = match.isNotEmpty
        ? match.first.id
        : places.firstWhere((p) => p.kind == 'shop').id;
  }

  /// New supplier accounts from the API get their own map pin + profile.
  void _ensureRegisteredSupplierPlace(AppUser user) {
    final key = _last9(user.phone);
    final existing = places.where(
      (p) => p.kind == 'shop' && _last9(p.phone) == key,
    );
    final profile = AuthService.fertilizerSupplierProfile;
    if (existing.isNotEmpty) {
      final p = existing.first;
      if (profile != null) {
        p.who = user.name;
        p.phone = user.phone;
        p.willingFar = profile['willing_far'] == true;
        p.coverageNote = '${profile['coverage_note'] ?? ''}';
      }
      return;
    }
    if (profile == null) return;
    final brands = '${profile['brands'] ?? ''}'
        .split(RegExp(r'[,+/]| and '))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    final radius = (profile['radius_km'] as num?)?.toDouble() ?? 5;
    places.add(
      FertPlace(
        id: 'PL-U-${user.id}',
        company: '${profile['shop_name'] ?? user.name}',
        who: user.name,
        kind: 'shop',
        physical: profile['shop_type'] != 'Delivery-only',
        willingFar: profile['willing_far'] == true,
        brands: brands.isEmpty ? const ['CIC'] : brands,
        distanceKm: radius,
        dLat: 0.01,
        dLng: -0.01,
        phone: user.phone,
        coverageNote: '${profile['coverage_note'] ?? ''}',
        items: [
          FertItem(
            name: '${brands.isEmpty ? 'CIC' : brands.first} Urea',
            brand: brands.isEmpty ? 'CIC' : brands.first,
            type: 'Urea',
            price: 5900,
            unit: '50 kg bag',
            stock: 20,
          ),
        ],
      ),
    );
  }

  /// New CDO accounts from the API get a single CCB desk pin.
  void _ensureRegisteredCdoPlace(AppUser user) {
    final key = _last9(user.phone);
    final existing = places.where(
      (p) => p.kind == 'cdo' && _last9(p.phone) == key,
    );
    final profile = AuthService.cdoProfile;
    if (existing.isNotEmpty) {
      final p = existing.first;
      if (profile != null) {
        final district = '${profile['assigned_district'] ?? ''}';
        p.who = district.isEmpty
            ? user.name
            : 'CDO - ${district.split(',').first.trim()}';
        p.phone = user.phone;
      }
      return;
    }
    if (profile == null) return;
    final district = '${profile['assigned_district'] ?? 'Kurunegala'}';
    final who = 'CDO - $district';
    places.add(
      FertPlace(
        id: 'PL-CDO-${user.id}',
        company: 'CCB',
        who: who,
        kind: 'cdo',
        physical: true,
        willingFar: false,
        brands: const ['CCB'],
        distanceKm: 4,
        dLat: -0.02,
        dLng: 0.015,
        phone: user.phone,
        items: [
          FertItem(
            name: 'ERP Coconut Fertilizer',
            brand: 'CCB',
            type: 'Government',
            price: 6000,
            unit: '50 kg bag',
            stock: 100,
          ),
        ],
      ),
    );
    cdoPlaceId = 'PL-CDO-${user.id}';
  }

  final List<FertPlace> places = [
    // three suppliers right next to the estate, so the 1 km view is never empty
    FertPlace(
      id: 'PL0a',
      company: 'Estate Gate Agro',
      who: 'Saman Kumara',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['CIC', 'Hayleys'],
      distanceKm: 0.5,
      dLat: 0.004,
      dLng: 0.003,
      phone: '077 301 4455',
      items: [
        FertItem(
          name: 'CIC Urea',
          brand: 'CIC',
          type: 'Urea',
          price: 5950,
          unit: '50 kg bag',
          stock: 25,
        ),
        FertItem(
          name: 'Hayleys Dolomite',
          brand: 'Hayleys',
          type: 'Dolomite',
          price: 2450,
          unit: '50 kg bag',
          stock: 40,
        ),
      ],
    ),
    FertPlace(
      id: 'PL0b',
      company: 'Lanka Agro Mart',
      who: 'Priyantha Jayalath',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['CIC', 'Baurs'],
      distanceKm: 0.8,
      dLat: 0.001,
      dLng: -0.007,
      phone: '077 302 6677',
      items: [
        FertItem(
          name: 'CIC MOP',
          brand: 'CIC',
          type: 'MOP',
          price: 6650,
          unit: '50 kg bag',
          stock: 16,
        ),
        FertItem(
          name: 'Baurs YPM',
          brand: 'Baurs',
          type: 'YPM',
          price: 6950,
          unit: '50 kg bag',
          stock: 10,
        ),
      ],
    ),
    // Why: only one CCB pin on the estate map (PL5 below).
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
        FertItem(
          name: 'CIC MOP',
          brand: 'CIC',
          type: 'MOP',
          price: 6600,
          unit: '50 kg bag',
          stock: 12,
        ),
        FertItem(
          name: 'Baurs YPM',
          brand: 'Baurs',
          type: 'YPM',
          price: 6900,
          unit: '50 kg bag',
          stock: 9,
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
      // Own pin — never share coordinates with Nadeesha Stores.
      distanceKm: 2.3,
      dLat: 0.018,
      dLng: 0.010,
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
        FertItem(
          name: 'Hayleys Dolomite',
          brand: 'Hayleys',
          type: 'Dolomite',
          price: 2400,
          unit: '50 kg bag',
          stock: 30,
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
        FertItem(
          name: 'CIC TSP',
          brand: 'CIC',
          type: 'TSP',
          price: 8800,
          unit: '50 kg bag',
          stock: 11,
        ),
        FertItem(
          name: 'CIC APM',
          brand: 'CIC',
          type: 'APM',
          price: 7600,
          unit: '50 kg bag',
          stock: 7,
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
      company: 'CCB',
      who: 'CDO - Mawathagama',
      kind: 'cdo',
      physical: true,
      // Why: government programme only lists one CCB near the estate.
      willingFar: false,
      brands: const ['CCB'],
      distanceKm: 3.2,
      dLat: -0.018,
      dLng: 0.012,
      region: 'kurunegala',
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
        FertItem(
          name: 'MOP subsidy',
          brand: 'CCB',
          type: 'MOP',
          price: 5400,
          unit: '50 kg bag',
          stock: 70,
        ),
        FertItem(
          name: 'TSP subsidy',
          brand: 'CCB',
          type: 'TSP',
          price: 5600,
          unit: '50 kg bag',
          stock: 55,
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
      region: 'colombo',
      absLat: 6.9271,
      absLng: 79.8612,
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
    // --- Colombo suppliers (for Colombo Palm Estate) ---
    FertPlace(
      id: 'PL-CMB-1',
      company: 'Colombo Agro Mart',
      who: 'Ravi Jayasuriya',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['CIC', 'Baurs'],
      distanceKm: 2.1,
      dLat: 0,
      dLng: 0,
      region: 'colombo',
      absLat: 6.9350,
      absLng: 79.8700,
      phone: '0772100001',
      items: [
        FertItem(
          name: 'CIC Urea',
          brand: 'CIC',
          type: 'Urea',
          price: 5950,
          unit: '50 kg bag',
          stock: 24,
        ),
        FertItem(
          name: 'Baurs YPM',
          brand: 'Baurs',
          type: 'YPM',
          price: 6900,
          unit: '50 kg bag',
          stock: 12,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-CMB-2',
      company: 'Green Leaf Colombo',
      who: 'Sithara Perera',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Hayleys'],
      distanceKm: 3.4,
      dLat: 0,
      dLng: 0,
      region: 'colombo',
      absLat: 6.9150,
      absLng: 79.8800,
      phone: '0772100002',
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
      id: 'PL-CMB-3',
      company: 'CIC Point Colombo',
      who: 'Nuwan Dias',
      kind: 'shop',
      physical: true,
      willingFar: true,
      brands: const ['CIC'],
      distanceKm: 4.8,
      dLat: 0,
      dLng: 0,
      region: 'colombo',
      absLat: 6.9450,
      absLng: 79.8500,
      phone: '0772100003',
      items: [
        FertItem(
          name: 'CIC MOP',
          brand: 'CIC',
          type: 'MOP',
          price: 6600,
          unit: '50 kg bag',
          stock: 15,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-CMB-4',
      company: 'Baurs Depot Colombo',
      who: 'Malsha Fernando',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Baurs'],
      distanceKm: 5.5,
      dLat: 0,
      dLng: 0,
      region: 'colombo',
      absLat: 6.9000,
      absLng: 79.8900,
      phone: '0772100004',
      items: [
        FertItem(
          name: 'Baurs Coconut Blend',
          brand: 'Baurs',
          type: 'Coconut mix',
          price: 7000,
          unit: '50 kg bag',
          stock: 20,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-CMB-5',
      company: 'Hayleys Colombo Hub',
      who: 'Ishara Gunasekara',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Hayleys', 'CIC'],
      distanceKm: 6.2,
      dLat: 0,
      dLng: 0,
      region: 'colombo',
      absLat: 6.9600,
      absLng: 79.8700,
      phone: '0772100005',
      items: [
        FertItem(
          name: 'Hayleys Dolomite',
          brand: 'Hayleys',
          type: 'Dolomite',
          price: 2400,
          unit: '50 kg bag',
          stock: 40,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-CCB-CMB',
      company: 'CCB',
      who: 'CDO - Colombo',
      kind: 'cdo',
      physical: true,
      willingFar: false,
      brands: const ['CCB'],
      distanceKm: 3.0,
      dLat: 0,
      dLng: 0,
      region: 'colombo',
      absLat: 6.9300,
      absLng: 79.8650,
      phone: '0772300001',
      items: [
        FertItem(
          name: 'ERP Coconut Fertilizer',
          brand: 'CCB',
          type: 'Government',
          price: 6000,
          unit: '50 kg bag',
          stock: 100,
        ),
        FertItem(
          name: 'Urea subsidy',
          brand: 'CCB',
          type: 'Urea',
          price: 4200,
          unit: '50 kg bag',
          stock: 70,
        ),
      ],
    ),
    // --- Puttalam suppliers (for Puttalam Coast Estate) ---
    FertPlace(
      id: 'PL-PUT-1',
      company: 'Puttalam Fertilizer',
      who: 'Ajith Bandara',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['CIC'],
      distanceKm: 1.8,
      dLat: 0,
      dLng: 0,
      region: 'puttalam',
      absLat: 8.0400,
      absLng: 79.8350,
      phone: '0772200001',
      items: [
        FertItem(
          name: 'CIC Urea',
          brand: 'CIC',
          type: 'Urea',
          price: 5900,
          unit: '50 kg bag',
          stock: 22,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-PUT-2',
      company: 'Chilaw Agro',
      who: 'Dilani Wijesinghe',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Baurs', 'Hayleys'],
      distanceKm: 2.9,
      dLat: 0,
      dLng: 0,
      region: 'puttalam',
      absLat: 8.0200,
      absLng: 79.8500,
      phone: '0772200002',
      items: [
        FertItem(
          name: 'Baurs YPM',
          brand: 'Baurs',
          type: 'YPM',
          price: 6850,
          unit: '50 kg bag',
          stock: 14,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-PUT-3',
      company: 'Coastline Supplies',
      who: 'Pradeep Silva',
      kind: 'shop',
      physical: true,
      willingFar: true,
      brands: const ['CIC', 'Hayleys'],
      distanceKm: 4.1,
      dLat: 0,
      dLng: 0,
      region: 'puttalam',
      absLat: 8.0550,
      absLng: 79.8200,
      phone: '0772200003',
      items: [
        FertItem(
          name: 'CIC TSP',
          brand: 'CIC',
          type: 'TSP',
          price: 8700,
          unit: '50 kg bag',
          stock: 10,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-PUT-4',
      company: 'Palm Care Puttalam',
      who: 'Nadeeka Rathnayake',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Baurs'],
      distanceKm: 5.0,
      dLat: 0,
      dLng: 0,
      region: 'puttalam',
      absLat: 8.0100,
      absLng: 79.8600,
      phone: '0772200004',
      items: [
        FertItem(
          name: 'Baurs Coconut Blend',
          brand: 'Baurs',
          type: 'Coconut mix',
          price: 7050,
          unit: '50 kg bag',
          stock: 16,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-PUT-5',
      company: 'Wennappuwa Agro',
      who: 'Kasun Mendis',
      kind: 'shop',
      physical: true,
      willingFar: false,
      brands: const ['Hayleys'],
      distanceKm: 6.5,
      dLat: 0,
      dLng: 0,
      region: 'puttalam',
      absLat: 8.0700,
      absLng: 79.8400,
      phone: '0772200005',
      items: [
        FertItem(
          name: 'Hayleys Organic',
          brand: 'Hayleys',
          type: 'Organic',
          price: 5100,
          unit: '25 kg bag',
          stock: 25,
        ),
      ],
    ),
    FertPlace(
      id: 'PL-CCB-PUT',
      company: 'CCB',
      who: 'CDO - Puttalam',
      kind: 'cdo',
      physical: true,
      willingFar: false,
      brands: const ['CCB'],
      distanceKm: 2.5,
      dLat: 0,
      dLng: 0,
      region: 'puttalam',
      absLat: 8.0350,
      absLng: 79.8300,
      phone: '0772300002',
      items: [
        FertItem(
          name: 'ERP Coconut Fertilizer',
          brand: 'CCB',
          type: 'Government',
          price: 6000,
          unit: '50 kg bag',
          stock: 90,
        ),
        FertItem(
          name: 'Urea subsidy',
          brand: 'CCB',
          type: 'Urea',
          price: 4200,
          unit: '50 kg bag',
          stock: 60,
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
      owner: 'Mawathagama Palm Estate',
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
      owner: 'Mawathagama Palm Estate',
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
    FertOrder(
      id: 'PO-501',
      placeId: 'PL5',
      company: 'CCB',
      agent: 'CDO - Mawathagama',
      owner: 'Smallholder Group B',
      product: 'ERP Coconut Fertilizer (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL5').items.first,
          qty50: 20,
        ),
      ],
      qty50: 20,
      price: 120000,
      preferredDate: DateTime(2026, 11, 9),
      slot: 'Morning 8–11',
      status: 'Pending Ack',
      message: 'Subsidy collection for 20 farmers.',
    ),
    FertOrder(
      id: 'PO-502',
      placeId: 'PL5',
      company: 'CCB',
      agent: 'CDO - Mawathagama',
      owner: 'Estate Co-op',
      product: 'Urea subsidy (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL5').items[1],
          qty50: 15,
        ),
      ],
      qty50: 15,
      price: 63000,
      preferredDate: DateTime(2026, 11, 11),
      slot: 'Afternoon 12–3',
      status: 'Pending Ack',
      message: 'Please confirm pickup window.',
    ),
    // --- Rich demo: Nushrath (Colombo) ↔ Colombo Agro Mart ---
    FertOrder(
      id: 'PO-610',
      placeId: 'PL-CMB-1',
      company: 'Colombo Agro Mart',
      agent: 'Ravi Jayasuriya',
      owner: 'Colombo Palm Estate',
      product: 'CIC Urea (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL-CMB-1').items.first,
          qty50: 8,
        ),
      ],
      qty50: 8,
      price: 47600,
      preferredDate: DateTime(2026, 11, 19),
      slot: 'Morning 8–11',
      status: 'Pending Ack',
      message: 'Need urea for the Kaduwela block this week.',
    ),
    FertOrder(
      id: 'PO-611',
      placeId: 'PL-CMB-1',
      company: 'Colombo Agro Mart',
      agent: 'Ravi Jayasuriya',
      owner: 'Colombo Palm Estate',
      product: 'Baurs YPM (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL-CMB-1').items[1],
          qty50: 5,
        ),
      ],
      qty50: 5,
      price: 34500,
      preferredDate: DateTime(2026, 11, 20),
      slot: 'Afternoon 12–3',
      status: 'Negotiating',
      message: 'Can you do a better price for 5 bags?',
      negotiation: const [
        FertChat('You', 'Can you do Rs. 6,500 / bag for Baurs YPM?', '10:05'),
        FertChat(
          'Colombo Agro Mart',
          'I can do Rs. 6,700 if you take 5 bags this week.',
          '10:12',
        ),
      ],
    ),
    FertOrder(
      id: 'PO-612',
      placeId: 'PL-CMB-1',
      company: 'Colombo Agro Mart',
      agent: 'Ravi Jayasuriya',
      owner: 'Colombo Palm Estate',
      product: 'CIC Urea (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL-CMB-1').items.first,
          qty50: 4,
        ),
      ],
      qty50: 4,
      price: 23800,
      preferredDate: DateTime(2026, 11, 18),
      slot: 'Morning 8–11',
      status: 'Accepted',
      message: 'Accepted · awaiting delivery',
    ),
    FertOrder(
      id: 'PO-613',
      placeId: 'PL-CMB-1',
      company: 'Colombo Agro Mart',
      agent: 'Ravi Jayasuriya',
      owner: 'Colombo Palm Estate',
      product: 'Baurs YPM (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL-CMB-1').items[1],
          qty50: 3,
        ),
      ],
      qty50: 3,
      price: 20700,
      preferredDate: DateTime(2026, 11, 15),
      slot: 'Morning 8–11',
      status: 'Distributed',
      message: 'Marked delivered · waiting for owner to confirm',
    ),
    FertOrder(
      id: 'PO-614',
      placeId: 'PL-CMB-1',
      company: 'Colombo Agro Mart',
      agent: 'Ravi Jayasuriya',
      owner: 'Colombo Palm Estate',
      product: 'CIC Urea (50 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL-CMB-1').items.first,
          qty50: 10,
        ),
      ],
      qty50: 10,
      price: 59500,
      preferredDate: DateTime(2026, 11, 10),
      slot: 'Afternoon 12–3',
      status: 'Completed',
      message: 'Owner confirmed receipt · order completed',
      ownerStars: 5,
      supplierStars: 4,
      ownerRateNote: 'On time and bags were sealed.',
      supplierRateNote: 'Clear instructions and easy access.',
    ),
    FertOrder(
      id: 'PO-615',
      placeId: 'PL-CMB-2',
      company: 'Green Leaf Colombo',
      agent: 'Sithara Perera',
      owner: 'Colombo Palm Estate',
      product: 'Hayleys Organic (25 kg)',
      items: [
        CartLine(
          item: places.firstWhere((p) => p.id == 'PL-CMB-2').items.first,
          qty50: 6,
        ),
      ],
      qty50: 6,
      price: 31200,
      preferredDate: DateTime(2026, 11, 22),
      slot: 'Morning 8–11',
      status: 'Cancelled',
      message: 'Cancelled by estate · changed plan',
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
    'PL-CMB-1': [
      const FertChat(
        'You',
        'Hi Ravi — what colour are the CIC bags, and your phone number?',
        '9:40',
      ),
      const FertChat(
        'Colombo Agro Mart',
        'Green and white bags. Call 077 210 0001 anytime.',
        '9:45',
      ),
      const FertChat(
        'You',
        'Can you deliver 8 × CIC Urea on 19 Nov morning?',
        '9:50',
      ),
      const FertChat(
        'Colombo Agro Mart',
        'Yes — I can confirm after you place the order.',
        '9:55',
      ),
      const FertChat(
        'You',
        'Also looking at Baurs YPM — can you do a better price for 5 bags?',
        '10:05',
      ),
    ],
  };

  /// Northern districts the Regional Manager can see in the demo.
  static const managerDistricts = ['Jaffna', 'Mannar', 'Mullaitivu'];

  final List<FertGovRequest> govRequests = [
    FertGovRequest(
      id: 'FR-1099',
      owner: 'Mawathagama Palm Estate',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 12,
      status: 'Pending Ack',
      cdo: 'CDO - Mawathagama',
      date: DateTime(2026, 11, 8),
      district: 'Kurunegala',
      // Why: CDO View must show the filled Annex 01 form the estate uploaded.
      estateName: 'Mawathagama Palm Estate',
      acres: 8,
      nicCopy: 'nic_demo_owner.jpg',
      landTitleCopy: 'deed_KUR_MWT_2018_0456.pdf',
      outlet: 'CCB',
      preferred: '08 Nov 2026 · Morning',
      beneficiaryName: 'Demo Estate Owner',
      address: 'No. 12, Temple Road, Mawathagama',
      phone: '0711000001',
      nicNumber: '198512345678',
      landAddress: 'Mawathagama Palm Estate, Mawathagama, Kurunegala',
      deedNumber: 'KUR/MWT/2018/0456',
      coconutTrees: 640,
      coconutSaplings: 80,
      annualHarvestNuts: 42000,
      deliveryAt: DateTime(2026, 11, 18, 10, 30),
      chat: const [
        FertChat(
          'Mawathagama Palm Estate',
          'We submitted Annex 01 for 12 bags of ERP.',
          '08 Nov · 09:12',
        ),
        FertChat(
          'CDO - Mawathagama',
          'Received. We will verify documents and confirm delivery.',
          '08 Nov · 11:40',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-1100',
      owner: 'Estate A',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 20,
      approved: 20,
      distributed: 20,
      status: 'Distributed',
      cdo: 'CDO - Mawathagama',
      date: DateTime(2026, 10, 12),
      district: 'Kurunegala',
      estateName: 'Estate A',
      acres: 12,
      nicCopy: 'nic_nimal.jpg',
      landTitleCopy: 'deed_estate_a.pdf',
      outlet: 'CCB',
      preferred: '12 Oct 2026 · Morning',
      beneficiaryName: 'Nimal Perera',
      address: 'Estate A road, Mawathagama',
      phone: '0712233445',
      nicNumber: '197812345V',
      landAddress: 'Estate A, Mawathagama',
      deedNumber: 'KUR/MWT/2015/0211',
      coconutTrees: 900,
      coconutSaplings: 40,
      annualHarvestNuts: 58000,
      deliveryAt: DateTime(2026, 10, 20, 14, 0),
      chat: const [
        FertChat(
          'Estate A',
          'Please confirm morning delivery near the estate gate.',
          '12 Oct · 08:20',
        ),
        FertChat(
          'CDO - Mawathagama',
          'Confirmed. Delivery set for 20 Oct at 2:00 PM.',
          '13 Oct · 16:05',
        ),
        FertChat(
          'Estate A',
          'Bags received. Thank you.',
          '20 Oct · 14:40',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-1101',
      owner: 'Estate A',
      fertilizer: 'Urea subsidy (50 kg)',
      requested: 8,
      status: 'Pending Ack',
      cdo: 'CDO - Mawathagama',
      date: DateTime(2026, 11, 10),
      district: 'Kurunegala',
      estateName: 'Estate A',
      acres: 12,
      nicCopy: 'nic_nimal.jpg',
      landTitleCopy: 'deed_estate_a.pdf',
      outlet: 'CCB',
      preferred: '10 Nov 2026 · Afternoon',
      beneficiaryName: 'Nimal Perera',
      phone: '0712233445',
      deliveryAt: DateTime(2026, 11, 22, 9, 0),
      chat: const [
        FertChat(
          'Estate A',
          'New urea request for 8 bags. Documents already on file.',
          '10 Nov · 15:02',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-1102',
      owner: 'Estate F',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 10,
      status: 'Cancelled',
      cdo: 'CDO - Mawathagama',
      date: DateTime(2026, 9, 22),
      district: 'Kurunegala',
      estateName: 'Estate F',
      acres: 6,
      outlet: 'CCB',
      preferred: '22 Sep 2026 · Morning',
      beneficiaryName: 'Sunil Fernando',
      phone: '0715566778',
      chat: const [
        FertChat(
          'CDO - Mawathagama',
          'Cancelled · land title copy was missing.',
          '23 Sep · 10:11',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-1103',
      owner: 'River Bend Estate',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 15,
      approved: 15,
      distributed: 0,
      status: 'Accepted',
      cdo: 'CDO - Mawathagama',
      date: DateTime(2026, 11, 5),
      district: 'Kurunegala',
      estateName: 'River Bend Estate',
      acres: 9,
      nicCopy: 'nic_ranjith.jpg',
      landTitleCopy: 'deed_river_bend.pdf',
      outlet: 'CCB',
      preferred: '05 Nov 2026 · Morning',
      beneficiaryName: 'Ranjith Jayasuriya',
      phone: '0761122334',
      deliveryAt: DateTime(2026, 11, 19, 11, 0),
      chat: const [
        FertChat(
          'River Bend Estate',
          'When can we collect the 15 bags?',
          '05 Nov · 09:30',
        ),
        FertChat(
          'CDO - Mawathagama',
          'Accepted. Delivery on 19 Nov at 11:00 AM.',
          '06 Nov · 13:18',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-N-1001',
      owner: 'Northern Estate J',
      fertilizer: 'ERP Coconut Fertilizer',
      requested: 18,
      approved: 18,
      distributed: 18,
      status: 'Receipt Confirmed',
      cdo: 'CDO - Jaffna (demo)',
      date: DateTime(2026, 10, 18),
      district: 'Jaffna',
    ),
    FertGovRequest(
      id: 'FR-N-1002',
      owner: 'Northern Estate M',
      fertilizer: 'ERP Coconut Fertilizer',
      requested: 24,
      approved: 20,
      distributed: 0,
      status: 'Negotiation',
      cdo: 'CDO - Mannar (demo)',
      date: DateTime(2026, 10, 19),
      district: 'Mannar',
    ),
    FertGovRequest(
      id: 'FR-N-1003',
      owner: 'Northern Estate ML',
      fertilizer: 'ERP Coconut Fertilizer',
      requested: 15,
      approved: 15,
      distributed: 10,
      status: 'Distributed',
      cdo: 'CDO - Mullaitivu (demo)',
      date: DateTime(2026, 10, 20),
      district: 'Mullaitivu',
    ),
    // --- Rich demo: Nushrath ↔ CDO Colombo ---
    FertGovRequest(
      id: 'FR-COL-2001',
      owner: 'Colombo Palm Estate',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 10,
      status: 'Pending Ack',
      cdo: 'CDO - Colombo',
      date: DateTime(2026, 11, 17),
      district: 'Colombo',
      estateName: 'Colombo Palm Estate',
      acres: 6,
      nicCopy: 'nic_nushrath.jpg',
      landTitleCopy: 'deed_COL_KDW_2020_1188.pdf',
      outlet: 'CCB',
      preferred: '17 Nov 2026 · Morning',
      beneficiaryName: 'Nushrath Silva',
      address: '42 Marine Drive, Colombo 03',
      phone: '0712000011',
      nicNumber: '199012345678',
      landAddress: 'Colombo Palm Estate, Kaduwela, Colombo',
      deedNumber: 'COL/KDW/2020/1188',
      coconutTrees: 480,
      coconutSaplings: 60,
      annualHarvestNuts: 28000,
      deliveryAt: DateTime(2026, 11, 25, 10, 0),
      chat: const [
        FertChat(
          'Colombo Palm Estate',
          'Submitted Annex 01 for 10 bags of ERP for Kaduwela block.',
          '17 Nov · 09:05',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-COL-2002',
      owner: 'Colombo Palm Estate',
      fertilizer: 'Urea subsidy (50 kg)',
      requested: 6,
      approved: 6,
      status: 'Negotiation',
      cdo: 'CDO - Colombo',
      date: DateTime(2026, 11, 14),
      district: 'Colombo',
      estateName: 'Colombo Palm Estate',
      acres: 6,
      nicCopy: 'nic_nushrath.jpg',
      landTitleCopy: 'deed_COL_KDW_2020_1188.pdf',
      outlet: 'CCB',
      preferred: '14 Nov 2026 · Afternoon',
      beneficiaryName: 'Nushrath Silva',
      phone: '0712000011',
      deliveryAt: DateTime(2026, 11, 21, 14, 0),
      chat: const [
        FertChat(
          'Colombo Palm Estate',
          'Can we collect urea on 21 Nov afternoon?',
          '14 Nov · 11:20',
        ),
        FertChat(
          'CDO - Colombo',
          'Checking stock at CCB. Can you take morning instead?',
          '14 Nov · 15:40',
        ),
        FertChat(
          'Colombo Palm Estate',
          'Morning also works if afternoon is tight.',
          '14 Nov · 16:05',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-COL-2003',
      owner: 'Colombo Palm Estate',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 8,
      approved: 8,
      distributed: 0,
      status: 'Accepted',
      cdo: 'CDO - Colombo',
      date: DateTime(2026, 11, 8),
      district: 'Colombo',
      estateName: 'Colombo Palm Estate',
      acres: 6,
      nicCopy: 'nic_nushrath.jpg',
      landTitleCopy: 'deed_COL_KDW_2020_1188.pdf',
      outlet: 'CCB',
      preferred: '08 Nov 2026 · Morning',
      beneficiaryName: 'Nushrath Silva',
      phone: '0712000011',
      deliveryAt: DateTime(2026, 11, 19, 10, 30),
      chat: const [
        FertChat(
          'CDO - Colombo',
          'Accepted. Delivery on 19 Nov at 10:30 AM.',
          '09 Nov · 10:12',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-COL-2004',
      owner: 'Colombo Palm Estate',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 12,
      approved: 12,
      distributed: 12,
      status: 'Distributed',
      cdo: 'CDO - Colombo',
      date: DateTime(2026, 10, 28),
      district: 'Colombo',
      estateName: 'Colombo Palm Estate',
      acres: 6,
      nicCopy: 'nic_nushrath.jpg',
      landTitleCopy: 'deed_COL_KDW_2020_1188.pdf',
      outlet: 'CCB',
      preferred: '28 Oct 2026 · Morning',
      beneficiaryName: 'Nushrath Silva',
      phone: '0712000011',
      deliveryAt: DateTime(2026, 11, 5, 11, 0),
      chat: const [
        FertChat(
          'CDO - Colombo',
          'Marked as delivered · please confirm you received the 12 bags.',
          '05 Nov · 11:20',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-COL-2005',
      owner: 'Colombo Palm Estate',
      fertilizer: 'Urea subsidy (50 kg)',
      requested: 5,
      approved: 5,
      distributed: 5,
      status: 'Receipt Confirmed',
      cdo: 'CDO - Colombo',
      date: DateTime(2026, 10, 5),
      district: 'Colombo',
      estateName: 'Colombo Palm Estate',
      acres: 6,
      nicCopy: 'nic_nushrath.jpg',
      landTitleCopy: 'deed_COL_KDW_2020_1188.pdf',
      outlet: 'CCB',
      preferred: '05 Oct 2026 · Morning',
      beneficiaryName: 'Nushrath Silva',
      phone: '0712000011',
      deliveryAt: DateTime(2026, 10, 12, 9, 30),
      chat: const [
        FertChat(
          'Colombo Palm Estate',
          'Bags received in good condition. Thank you.',
          '12 Oct · 10:05',
        ),
      ],
    ),
    FertGovRequest(
      id: 'FR-COL-2006',
      owner: 'Colombo Palm Estate',
      fertilizer: 'ERP Coconut Fertilizer (50 kg)',
      requested: 4,
      status: 'Cancelled',
      cdo: 'CDO - Colombo',
      date: DateTime(2026, 9, 18),
      district: 'Colombo',
      estateName: 'Colombo Palm Estate',
      acres: 6,
      outlet: 'CCB',
      preferred: '18 Sep 2026 · Afternoon',
      beneficiaryName: 'Nushrath Silva',
      phone: '0712000011',
      chat: const [
        FertChat(
          'CDO - Colombo',
          'Cancelled · land title scan was unclear. Please re-upload.',
          '19 Sep · 09:40',
        ),
      ],
    ),
  ];

  final List<FertComplaint> complaints = [
    FertComplaint(
      id: 'QC-202',
      category: 'Product quality',
      product: 'ERP Coconut Fertilizer',
      status: 'Submitted',
      date: DateTime(2026, 10, 16),
      description: 'Sample complaint for demonstration.',
      owner: 'Mawathagama Palm Estate',
      district: 'Kurunegala',
    ),
    FertComplaint(
      id: 'QC-203',
      category: 'Incorrect quantity',
      product: 'ERP Coconut Fertilizer',
      status: 'Submitted',
      date: DateTime(2026, 10, 18),
      description: 'Sample Northern-region complaint.',
      owner: 'Northern Estate J',
      district: 'Jaffna',
    ),
    FertComplaint(
      id: 'QC-204',
      category: "Didn't receive the fertilizer",
      product: 'ERP Coconut Fertilizer',
      status: 'Under Review',
      date: DateTime(2026, 10, 19),
      description: 'Sample Northern-region complaint.',
      owner: 'Northern Estate M',
      district: 'Mannar',
    ),
    FertComplaint(
      id: 'QC-COL-301',
      category: 'Product quality',
      product: 'CIC Urea (50 kg)',
      status: 'Submitted',
      date: DateTime(2026, 11, 12),
      description: 'One bag from PO-614 had a torn seal. Rest were fine.',
      owner: 'Colombo Palm Estate',
      district: 'Colombo',
    ),
  ];

  static final Map<String, LatLng> estateGeo = {
    'Mawathagama Palm Estate': LatLng(7.4863, 80.3647),
    'Colombo Palm Estate': LatLng(6.9271, 79.8612),
    'Puttalam Coast Estate': LatLng(8.0362, 79.8283),
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

  /// Active jobs that still belong on the supplier calendar.
  List<FertOrder> get myShopCalendarOrders =>
      myShopOrders.where((o) => o.showsOnCalendar).toList();

  List<FertOrder> get pendingAck => myShopOrders
      .where((o) => o.status == 'Pending Ack' || o.status == 'Negotiating')
      .toList();

  bool isDisputed(String orderId) =>
      complaints.any((c) => c.description.contains(orderId)) ||
      orders.any((o) => o.id == orderId && o.status == 'Disputed');

  List<FertOrder> ownerOrders(String owner) =>
      orders.where((o) => o.owner == owner).toList();

  /// Orders that belong to the logged-in estate owner only.
  List<FertOrder> get myOrders => ownerOrders(boundOwnerKey);

  List<FertGovRequest> get myGovRequests {
    final phone = _last9(ownerProfile.phone);
    return govRequests
        .where(
          (r) =>
              r.owner == boundOwnerKey ||
              r.estateName == boundOwnerKey ||
              (phone.isNotEmpty && _last9(r.phone) == phone),
        )
        .toList();
  }

  List<FertComplaint> get myComplaints =>
      complaints.where((c) => c.owner == boundOwnerKey).toList();

  String nextId() => 'PO-${410 + orders.length + 1}';

  void placeOrder(FertOrder order) {
    orders.insert(0, order);
    // Why: estate hub banner shows “processing” right after Order now.
    notifyOwner(
      title: 'Order placed · processing',
      body: '${order.id} sent to ${order.company}. Waiting for accept.',
      kind: 'info',
      orderId: order.id,
    );
    notifySupplier(
      title: 'New order ${order.id}',
      body:
          '${order.owner} · ${order.product} · ${order.qty50} bags · ${order.slot}',
      kind: 'new_order',
      orderId: order.id,
    );
  }

  void cancelOrder(String id, {bool bySupplier = false, String? note}) {
    for (final o in orders) {
      if (o.id == id &&
          (o.status == 'Pending Ack' || o.status == 'Negotiating')) {
        o.status = 'Cancelled';
        // Why: estate My orders must show who cancelled — supplier or owner.
        o.message = bySupplier
            ? (note?.trim().isNotEmpty == true
                ? 'Cancelled by supplier · ${note!.trim()}'
                : 'Cancelled by supplier')
            : (note?.trim().isNotEmpty == true
                ? 'Cancelled by estate · ${note!.trim()}'
                : 'Cancelled by estate');
        o.negotiation.add(
          FertChat(
            bySupplier ? o.agent : o.owner,
            o.message,
            _nowStamp(),
          ),
        );
        if (bySupplier) {
          notifyOwner(
            title: '${o.company} cancelled your order',
            body: '${o.id} · ${o.product}. ${o.message}',
            kind: 'cancelled',
            orderId: o.id,
          );
        } else {
          // Why: supplier must hear when the estate cancels — that needs attention.
          notifySupplier(
            title: 'Estate cancelled ${o.id}',
            body: '${o.owner} · ${o.product}. ${o.message}',
            kind: 'cancelled',
            orderId: o.id,
          );
        }
        return;
      }
    }
  }

  void acceptOrder(String id) {
    for (final o in orders) {
      if (o.id == id &&
          (o.status == 'Pending Ack' || o.status == 'Negotiating')) {
        o.status = 'Accepted';
        o.message = 'Accepted by supplier · awaiting delivery';
        o.negotiation.add(
          FertChat(o.agent, 'Order accepted.', _nowStamp()),
        );
        notifyOwner(
          title: '${o.company} accepted your order',
          body: '${o.id} · ${o.product} · ${o.qty50} bags. Payment is after delivery setup.',
          kind: 'accepted',
          orderId: o.id,
        );
        return;
      }
    }
  }

  /// Supplier opens a price / date talk — estate sees Negotiating.
  void startNegotiation(String id, {String? note}) {
    for (final o in orders) {
      if (o.id == id &&
          (o.status == 'Pending Ack' || o.status == 'Negotiating')) {
        o.status = 'Negotiating';
        final text = note?.trim().isNotEmpty == true
            ? note!.trim()
            : 'Supplier opened negotiation.';
        o.message = text;
        o.negotiation.add(FertChat(o.agent, text, _nowStamp()));
        notifyOwner(
          title: '${o.company} wants to negotiate',
          body: '${o.id} · $text',
          kind: 'negotiating',
          orderId: o.id,
        );
        return;
      }
    }
  }

  static String _nowStamp() {
    final n = DateTime.now();
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    final m = n.minute.toString().padLeft(2, '0');
    final ap = n.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  void markDelivered(String id) {
    for (final o in orders) {
      if (o.id == id &&
          (o.status == 'Accepted' || o.status == 'Stock Confirmed')) {
        o.status = 'Distributed';
        o.message = 'Marked delivered by supplier · waiting for owner to confirm';
        notifyOwner(
          title: '${o.company} marked delivered',
          body: '${o.id} · Confirm when you receive the bags.',
          kind: 'delivered',
          orderId: o.id,
        );
        return;
      }
    }
  }

  /// Estate owner confirms bags arrived → order is completed.
  void confirmReceived(String id) {
    for (final o in orders) {
      if (o.id == id && o.status == 'Distributed') {
        o.status = 'Completed';
        o.message = 'Owner confirmed receipt · order completed';
        notifySupplier(
          title: '${o.owner} confirmed receipt',
          body: '${o.id} · completed. Please rate each other.',
          kind: 'accepted',
          orderId: o.id,
        );
        notifyOwner(
          title: 'Order ${o.id} completed',
          body: 'You confirmed receipt. Rate ${o.company}.',
          kind: 'accepted',
          orderId: o.id,
        );
        return;
      }
    }
  }

  /// Either side rates the other after completion.
  void rateOrder(
    String id, {
    required bool byOwner,
    required int stars,
    String note = '',
  }) {
    final s = stars.clamp(1, 5);
    for (final o in orders) {
      if (o.id != id || o.status != 'Completed') continue;
      if (byOwner) {
        o.ownerStars = s;
        o.ownerRateNote = note;
      } else {
        o.supplierStars = s;
        o.supplierRateNote = note;
      }
      return;
    }
  }

  /// CDO marks government bags delivered → owner must confirm.
  void markGovDelivered(String id, {int? bags}) {
    for (final r in govRequests) {
      if (r.id == id &&
          (r.status == 'Accepted' || r.status == 'Stock Confirmed')) {
        r.status = 'Distributed';
        r.distributed = bags ?? (r.approved > 0 ? r.approved : r.requested);
        r.chat.add(
          FertChat(
            r.cdo,
            'Marked delivered · ${r.distributed} bags. Please confirm receipt.',
            _nowStamp(),
          ),
        );
        notifyOwner(
          title: '${r.cdo} marked delivered',
          body: '${r.id} · Confirm when you receive the subsidy bags.',
          kind: 'delivered',
          orderId: r.id,
        );
        return;
      }
    }
  }

  /// Estate owner confirms government delivery.
  void confirmGovReceipt(String id) {
    for (final r in govRequests) {
      if (r.id == id && r.status == 'Distributed') {
        r.status = 'Receipt Confirmed';
        r.chat.add(
          FertChat(
            r.estateName.isNotEmpty ? r.estateName : r.owner,
            'Confirmed receipt of ${r.distributed} bags.',
            _nowStamp(),
          ),
        );
        notifyCdo(
          title: '${r.owner} confirmed receipt',
          body: '${r.id} · government order completed.',
          kind: 'accepted',
          orderId: r.id,
        );
        return;
      }
    }
  }

  // --- Shop chat (owner map negotiation ↔ supplier Messages) ---

  /// Unread owner→supplier messages per placeId.
  /// Why: Colombo Agro Mart starts with unread owner chat so the Messages badge shows.
  final Map<String, int> shopTalkUnread = {
    'PL-CMB-1': 2,
  };

  List<FertChat> shopMessages(String placeId) =>
      List<FertChat>.from(shopTalks[placeId] ?? const []);

  void sendShopChat(
    String placeId, {
    required String from,
    required String text,
    required bool fromOwner,
    String? ownerKey,
  }) {
    final list = List<FertChat>.from(shopTalks[placeId] ?? const []);
    list.add(FertChat(from, text, _nowStamp()));
    shopTalks[placeId] = list;
    if (fromOwner) {
      shopTalkUnread[placeId] = (shopTalkUnread[placeId] ?? 0) + 1;
      notifySupplier(
        title: 'New message from ${ownerKey ?? boundOwnerKey}',
        body: text,
        kind: 'negotiating',
      );
      // Mirror into the latest open order with this shop, if any.
      for (final o in myOrders) {
        if (o.placeId == placeId &&
            (o.status == 'Pending Ack' || o.status == 'Negotiating')) {
          o.status = 'Negotiating';
          o.negotiation.add(FertChat(from, text, _nowStamp()));
          o.message = text;
          break;
        }
      }
    } else {
      notifyOwner(
        title: '$from replied',
        body: text,
        kind: 'negotiating',
      );
      for (final o in orders) {
        if (o.placeId == placeId &&
            o.owner == (ownerKey ?? boundOwnerKey) &&
            (o.status == 'Pending Ack' || o.status == 'Negotiating')) {
          o.status = 'Negotiating';
          o.negotiation.add(FertChat(from, text, _nowStamp()));
          o.message = text;
          break;
        }
      }
    }
  }

  void markShopTalkRead(String placeId, {String? owner}) {
    shopTalkUnread[placeId] = 0;
  }

  int get unreadSupplierMessages => shopTalkUnread[agentShopId] ?? 0;

  List<FertSupplierThread> supplierMessageThreads(String placeId) {
    final msgs = shopTalks[placeId] ?? const <FertChat>[];
    if (msgs.isEmpty &&
        myShopOrders.every((o) => o.negotiation.isEmpty)) {
      return const [];
    }
    // Group by owner from matching orders; fallback single thread.
    final owners = <String>{};
    for (final o in myShopOrders) {
      owners.add(o.owner);
    }
    if (owners.isEmpty) {
      owners.add('Estate owner');
    }
    final unread = shopTalkUnread[placeId] ?? 0;
    final preview = msgs.isNotEmpty
        ? msgs.last.text
        : (myShopOrders.isNotEmpty && myShopOrders.first.negotiation.isNotEmpty
            ? myShopOrders.first.negotiation.last.text
            : 'Open to chat');
    return [
      for (final owner in owners)
        FertSupplierThread(
          owner: owner,
          preview: preview,
          unread: unread,
        ),
    ];
  }

  void placeGovRequest(FertGovRequest request) {
    govRequests.insert(0, request);
    // Why: CDO bell should light up when an estate sends a new board request.
    notifyCdo(
      title: 'New request ${request.id}',
      body:
          '${request.estateName.isNotEmpty ? request.estateName : request.owner} · ${request.fertilizer} · ${request.requested} bags',
      kind: 'new_order',
      orderId: request.id,
    );
  }

  /// Government requests for the logged-in CDO desk (matched by officer name).
  List<FertGovRequest> get myCdoRequests {
    final who = myShop.who;
    return govRequests.where((r) => r.cdo == who).toList();
  }

  List<FertGovRequest> get pendingCdoAck => myCdoRequests
      .where((r) => r.status == 'Pending Ack' || r.status == 'Submitted')
      .toList();

  List<FertGovRequest> get myCdoCalendarRequests =>
      myCdoRequests.where((r) => r.showsOnCalendar).toList();

  void acceptGovRequest(String id, {DateTime? deliveryAt}) {
    for (final r in govRequests) {
      if (r.id == id &&
          (r.status == 'Pending Ack' || r.status == 'Submitted')) {
        r.status = 'Accepted';
        r.approved = r.requested;
        final fallback = DateTime.now().add(const Duration(days: 7));
        r.deliveryAt = deliveryAt ??
            DateTime(fallback.year, fallback.month, fallback.day, 10, 0);
        r.chat.add(
          FertChat(
            r.cdo,
            'Accepted. Delivery on ${_formatDelivery(r.deliveryAt!)}.',
            _nowStamp(),
          ),
        );
        notifyOwner(
          title: 'Government request accepted',
          body:
              '${r.id} · delivery ${_formatDelivery(r.deliveryAt!)} · ${r.fertilizer}',
          kind: 'accepted',
        );
        break;
      }
    }
  }

  void cancelGovRequest(String id, {String? note, bool byCdo = true}) {
    for (final r in govRequests) {
      if (r.id == id &&
          (r.status == 'Pending Ack' || r.status == 'Submitted')) {
        r.status = 'Cancelled';
        final who = byCdo ? r.cdo : (r.estateName.isNotEmpty ? r.estateName : r.owner);
        final why = note?.trim().isNotEmpty == true
            ? note!.trim()
            : 'Cancelled by $who';
        r.chat.add(FertChat(who, why, _nowStamp()));
        if (byCdo) {
          notifyOwner(
            title: 'Government request cancelled',
            body: '${r.id} · $why',
            kind: 'cancelled',
            orderId: r.id,
          );
        } else {
          // Why: CDO must hear when the estate pulls a pending application.
          notifyCdo(
            title: 'Estate cancelled ${r.id}',
            body: '$who · ${r.fertilizer}. $why',
            kind: 'cancelled',
            orderId: r.id,
          );
        }
        break;
      }
    }
  }

  /// Why: CDO or estate can dispute; the other side gets a bell alert.
  void disputeGovRequest(
    String id, {
    required String reason,
    bool byCdo = true,
  }) {
    final why = reason.trim();
    if (why.isEmpty) return;
    for (final r in govRequests) {
      if (r.id == id &&
          (r.status == 'Accepted' ||
              r.status == 'Receipt Confirmed' ||
              r.status == 'Pending Ack' ||
              r.status == 'Submitted')) {
        r.status = 'Disputed';
        final who = byCdo
            ? r.cdo
            : (r.estateName.isNotEmpty ? r.estateName : r.owner);
        r.chat.add(FertChat(who, 'Disputed · $why', _nowStamp()));
        addComplaint(
          FertComplaint(
            id: 'DP-${300 + complaints.length + 1}',
            category: 'Dispute · ${byCdo ? 'CDO' : 'Estate'} · $why',
            product: r.fertilizer,
            status: 'Submitted',
            date: DateTime.now(),
            description: '${r.id} · ${r.owner}\n$why',
            owner: r.owner,
            district: r.district,
          ),
        );
        if (byCdo) {
          notifyOwner(
            title: 'CDO disputed ${r.id}',
            body: why,
            kind: 'cancelled',
            orderId: r.id,
          );
        } else {
          notifyCdo(
            title: 'Estate disputed ${r.id}',
            body: '$who · ${r.fertilizer}. $why',
            kind: 'estate_dispute',
            orderId: r.id,
          );
        }
        break;
      }
    }
  }

  void sendGovChat(String id, {required String from, required String text}) {
    final t = text.trim();
    if (t.isEmpty) return;
    for (final r in govRequests) {
      if (r.id == id) {
        r.chat.add(FertChat(from, t, _nowStamp()));
        return;
      }
    }
  }

  static String _formatDelivery(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final am = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day.toString().padLeft(2, '0')} '
        '${['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month]} '
        '${d.year} · $h:$m $am';
  }

  /// CDO warehouse stock (bags). Receiving stock increases these counts.
  final List<FertCdoStockLine> cdoStock = [
    FertCdoStockLine(type: 'ERP Coconut Fertilizer', bags: 120, packPrice: 6200),
    FertCdoStockLine(type: 'Urea subsidy', bags: 8, packPrice: 5900),
    FertCdoStockLine(type: 'MOP', bags: 0, packPrice: 5400),
    FertCdoStockLine(type: 'Dolomite', bags: 45, packPrice: 2800),
  ];

  List<FertCdoStockLine> get myCdoStock => cdoStock;

  /// Demo seed so the CDO bell has cancel / dispute / low-stock samples.
  bool _cdoAlertsSeeded = false;

  /// Why: notification Show can hand the hub a gov request id to open in Messages.
  String? pendingOpenGovId;

  void ensureCdoDemoAlerts() {
    if (_cdoAlertsSeeded) return;
    _cdoAlertsSeeded = true;
    if (cdoAlerts.isNotEmpty) return;
    notifyCdo(
      title: 'Estate cancelled FR-1102',
      body: 'Estate F · ERP Coconut Fertilizer. Land title copy was missing.',
      kind: 'cancelled',
      orderId: 'FR-1102',
    );
    notifyCdo(
      title: 'Estate disputed FR-1101',
      body: 'Estate A · Wrong bag count on delivery note.',
      kind: 'estate_dispute',
      orderId: 'FR-1101',
    );
    checkCdoLowStock();
  }

  String? consumePendingOpenGovId() {
    final id = pendingOpenGovId;
    pendingOpenGovId = null;
    return id;
  }

  void receiveCdoStock(String type, int bags) {
    final name = type.trim();
    if (name.isEmpty || bags <= 0) return;
    for (final line in cdoStock) {
      if (line.type.toLowerCase() == name.toLowerCase()) {
        line.bags += bags;
        return;
      }
    }
    cdoStock.add(FertCdoStockLine(type: name, bags: bags));
  }

  /// Why: CDO can nudge one fertilizer line up or down from the stock table.
  void adjustCdoStock(String type, int delta) {
    for (final line in cdoStock) {
      if (line.type.toLowerCase() == type.toLowerCase()) {
        line.bags = (line.bags + delta).clamp(0, 99999);
        return;
      }
    }
  }

  void addComplaint(FertComplaint complaint) => complaints.insert(0, complaint);

  /// Demo CDO area stock summary (same idea as the HTML demo).
  final List<Map<String, dynamic>> areaStock = [
    {
      'area': 'CDO - Area 01',
      'district': 'Kurunegala',
      'product': 'ERP Coconut Fertilizer',
      'bags': 120,
      'allocated': 65,
    },
    {
      'area': 'CDO - Area 02',
      'district': 'Kurunegala',
      'product': 'ERP Coconut Fertilizer',
      'bags': 80,
      'allocated': 42,
    },
  ];

  static const eligibleEstates = [
    ('Mawathagama Palm Estate', '8 acres', 'Mawathagama', true),
    ('Estate A', '12 acres', 'Mawathagama', true),
    ('Estate F', '6 acres', 'Kuliyapitiya', true),
    ('Green Palm Estate', '5 acres', 'Narammala', true),
    ('Sunrise Estate', '3 acres', 'Gampaha', false),
  ];

  /// Areas under each CDO desk — used by the Area tab.
  static const List<FertCdoArea> cdoAreas = [
    FertCdoArea(
      id: 'A01',
      name: 'Area 01 · Mawathagama',
      town: 'Mawathagama',
      district: 'Kurunegala',
      cdoWho: 'CDO - Mawathagama',
      estates: [
        FertCdoEstate(
          name: 'Mawathagama Palm Estate',
          acresLabel: '8 acres',
          ownerName: 'Demo Estate Owner',
          phone: '0711000001',
        ),
        FertCdoEstate(
          name: 'Estate A',
          acresLabel: '12 acres',
          ownerName: 'Nimal Perera',
          phone: '0712233445',
        ),
        FertCdoEstate(
          name: 'Hillside Coconut',
          acresLabel: '4 acres',
          ownerName: 'Kamala Silva',
          phone: '0778899001',
        ),
      ],
    ),
    FertCdoArea(
      id: 'A02',
      name: 'Area 02 · Kuliyapitiya',
      town: 'Kuliyapitiya',
      district: 'Kurunegala',
      cdoWho: 'CDO - Mawathagama',
      estates: [
        FertCdoEstate(
          name: 'Estate F',
          acresLabel: '6 acres',
          ownerName: 'Sunil Fernando',
          phone: '0715566778',
        ),
        FertCdoEstate(
          name: 'River Bend Estate',
          acresLabel: '9 acres',
          ownerName: 'Ranjith Jayasuriya',
          phone: '0761122334',
        ),
      ],
    ),
    FertCdoArea(
      id: 'A03',
      name: 'Area 03 · Narammala',
      town: 'Narammala',
      district: 'Kurunegala',
      cdoWho: 'CDO - Mawathagama',
      estates: [
        FertCdoEstate(
          name: 'Green Palm Estate',
          acresLabel: '5 acres',
          ownerName: 'Anusha Wijesinghe',
          phone: '0709988776',
        ),
      ],
    ),
    FertCdoArea(
      id: 'A-COL-1',
      name: 'Area 01 · Kaduwela',
      town: 'Kaduwela',
      district: 'Colombo',
      cdoWho: 'CDO - Colombo',
      estates: [
        FertCdoEstate(
          name: 'Colombo Palm Estate',
          acresLabel: '6 acres',
          ownerName: 'Nushrath Silva',
          phone: '0712000011',
        ),
      ],
    ),
    FertCdoArea(
      id: 'A-PUT-1',
      name: 'Area 01 · Chilaw',
      town: 'Chilaw',
      district: 'Puttalam',
      cdoWho: 'CDO - Puttalam',
      estates: [
        FertCdoEstate(
          name: 'Puttalam Coast Estate',
          acresLabel: '10 acres',
          ownerName: 'Kamal Fernando',
          phone: '0712000022',
        ),
      ],
    ),
  ];

  /// Areas that belong to the logged-in CDO officer.
  List<FertCdoArea> areasForMyCdo() {
    final who = myShop.who;
    return cdoAreas.where((a) => a.cdoWho == who).toList();
  }

  /// All government requests for one estate under this CDO.
  List<FertGovRequest> requestsForEstate(String estateName) {
    final who = myShop.who;
    return govRequests
        .where(
          (r) =>
              r.cdo == who &&
              (r.estateName == estateName ||
                  r.owner == estateName ||
                  (r.estateName.isEmpty && r.owner == estateName)),
        )
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  FertEstateOrderStats statsForEstate(String estateName) {
    final list = requestsForEstate(estateName);
    var pending = 0, accepted = 0, completed = 0, cancelled = 0, bags = 0;
    for (final r in list) {
      bags += r.distributed;
      final s = r.status;
      if (s == 'Pending Ack' || s == 'Submitted' || s == 'Negotiation') {
        pending++;
      } else if (s == 'Cancelled' || s == 'Rejected') {
        cancelled++;
      } else if (s == 'Distributed' || s == 'Receipt Confirmed') {
        completed++;
      } else if (s == 'Accepted') {
        accepted++;
      } else {
        accepted++;
      }
    }
    return FertEstateOrderStats(
      totalRequests: list.length,
      pending: pending,
      accepted: accepted,
      completed: completed,
      cancelled: cancelled,
      bagsDistributed: bags,
    );
  }
}

/// One geographic area under a CDO desk.
class FertCdoArea {
  const FertCdoArea({
    required this.id,
    required this.name,
    required this.town,
    required this.district,
    required this.cdoWho,
    required this.estates,
  });

  final String id;
  final String name;
  final String town;
  final String district;
  final String cdoWho;
  final List<FertCdoEstate> estates;
}

class FertCdoEstate {
  const FertCdoEstate({
    required this.name,
    required this.acresLabel,
    required this.ownerName,
    required this.phone,
  });

  final String name;
  final String acresLabel;
  final String ownerName;
  final String phone;
}

class FertEstateOrderStats {
  const FertEstateOrderStats({
    required this.totalRequests,
    required this.pending,
    required this.accepted,
    required this.completed,
    required this.cancelled,
    required this.bagsDistributed,
  });

  final int totalRequests;
  final int pending;
  final int accepted;
  final int completed;
  final int cancelled;
  final int bagsDistributed;
}

/// One fertilizer type held at the CDO warehouse.
class FertCdoStockLine {
  FertCdoStockLine({
    required this.type,
    required this.bags,
    this.packPrice = 5000,
  });

  final String type;
  int bags;
  /// Board pack price shown read-only on the CDO stock card.
  final int packPrice;

  int get perKg => (packPrice / 50).round();

  /// available | low | not available
  String get level {
    if (bags <= 0) return 'not available';
    if (bags <= FertilizerStore.lowStockBags) return 'low';
    return 'available';
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'fertilizer_chrome.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';
import 'fertilizer_gov_order_form.dart';
import 'fertilizer_dispute_sheet.dart';
import 'fertilizer_order_edit_sheet.dart';
import 'fertilizer_order_sheet.dart';
import 'fertilizer_orders_page.dart';
import 'fertilizer_processing_banner.dart';
import 'fertilizer_talk_page.dart';

/// PickMe-style supplier map — matches the HTML fertilizer demo.
class FertilizerMapPage extends StatefulWidget {
  const FertilizerMapPage({
    super.key,
    this.channel = 'all',
    this.embedded = false,
    this.onGovRequestSent,
    this.onOrderPlaced,
  });

  /// all | private | gov
  final String channel;
  final bool embedded;

  /// Called after a government order form is sent (the hub then opens My orders).
  final void Function(FertGovRequest request)? onGovRequestSent;

  /// Called after a private order is placed (the hub then opens My orders).
  final void Function(FertOrder order)? onOrderPlaced;

  @override
  State<FertilizerMapPage> createState() => _FertilizerMapPageState();
}

class _FertilizerMapPageState extends State<FertilizerMapPage> {
  final _map = MapController();
  final _store = FertilizerStore.instance;
  final _search = TextEditingController();
  late String _channel;
  double _radiusKm = 10;
  final Set<String> _kinds = {}; // fertilizer types ticked in the dropdown
  final Set<String> _brands = {}; // CIC, Hayleys, Baurs
  String? _menu; // which dropdown is open: supplier, distance, brand or kinds
  FertPlace? _selected;
  String? _clusterKey;


  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    if (_channel == 'gov') {
      _radiusKm = 5;
      _brands.clear();
    }
  }

  @override
  void didUpdateWidget(covariant FertilizerMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel) {
      _channel = widget.channel;
      _selected = null;
      _clusterKey = null;
      if (_channel == 'gov') {
        _radiusKm = 5;
        _brands.clear();
      }
    }
  }

  LatLng get _estate {
    final AppUser? me = AuthService.currentUser;
    return LatLng(me?.latitude ?? 7.4863, me?.longitude ?? 80.3647);
  }

  LatLng _at(FertPlace p) =>
      LatLng(_estate.latitude + p.dLat, _estate.longitude + p.dLng);

  String _spotKey(FertPlace p) =>
      '${p.dLat.toStringAsFixed(4)}_${p.dLng.toStringAsFixed(4)}';

  bool _matchesBrand(FertPlace p) {
    if (_brands.isEmpty) return true;
    return p.brands.any(_brands.contains);
  }

  /// Hub Government tab stays on CCB — owner cannot switch to private shops there.
  bool get _govProgramme => widget.channel == 'gov';

  String get _activeChannel => _govProgramme ? 'gov' : _channel;

  bool _isCcbOutlet(FertPlace p) => p.isGov && p.brands.contains('CCB');

  List<FertPlace> get _visible {
    final q = _search.text.trim().toLowerCase();
    final channel = _activeChannel;
    final list = _store.places.where((p) {
      if (channel == 'private' && p.isGov) return false;
      // Why: government programme shows only CCB — no CIC / Hayleys / Baurs shops.
      if (channel == 'gov') {
        if (!_isCcbOutlet(p)) return false;
        if (p.distanceKm > _radiusKm) return false;
      } else {
        if (!_matchesBrand(p)) return false;
      }
      if (_kinds.isNotEmpty &&
          !p.items.any((i) => i.kinds.any(_kinds.contains))) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${p.company} ${p.brandLine} ${p.items.map((i) => i.name).join(' ')}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (p.distanceKm <= _radiusKm) return true;
      if (channel == 'gov') return false;
      return p.willingFar;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    // Why: Government map shows one shop named CCB — not Kurunegala / Mawathagama labels.
    if (channel == 'gov' && list.isNotEmpty) {
      return [list.first];
    }
    return list;
  }

  /// Group shops that sit on the same pin (like the HTML cluster).
  Map<String, List<FertPlace>> get _groups {
    final map = <String, List<FertPlace>>{};
    for (final p in _visible) {
      map.putIfAbsent(_spotKey(p), () => []).add(p);
    }
    return map;
  }

  int get _pendingMine => _store
      .ownerOrders('Your Estate')
      .where(
        (o) =>
            o.status == 'Pending Ack' ||
            o.status == 'Negotiating' ||
            o.status == 'Submitted',
      )
      .length;

  Color _pinColor(FertPlace p) {
    if (p.isGov) return AppColors.green;
    final b = p.brands.first.toLowerCase();
    if (b.startsWith('cic')) return const Color(0xFF1F6BB5);
    if (b.startsWith('bau')) return const Color(0xFFB45309);
    if (b.startsWith('hay')) return const Color(0xFF0F766E);
    return AppColors.brown;
  }

  String _pinMark(FertPlace p) {
    if (p.isGov) return 'CCB';
    final b = p.brands.first;
    return b.length <= 3 ? b : b.substring(0, 3);
  }

  @override
  void dispose() {
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Why: DraggableScrollableSheet overlays the map and steals taps on Flutter
    // web (estate hub feels “dead”). Use a split layout — map + list never overlap.
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _activeChannel == 'gov'
                  ? 'CCB near your estate'
                  : 'Suppliers near you',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FertilizerOrdersPage(),
                ),
              );
              if (mounted) setState(() {});
            },
            child: Text(
              _pendingMine > 0 ? 'Orders · $_pendingMine' : 'Orders',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );

    final banner = (!widget.embedded)
        ? FertProcessingBanner(
            onOpenOrders: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FertilizerOrdersPage(),
                ),
              ).then((_) {
                if (mounted) setState(() {});
              });
            },
          )
        : const SizedBox.shrink();

    final map = Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _mapBlock(),
      ),
    );

    // Show order list under the map when no supplier card is open.
    final showOrders =
        _selected == null && _clusterKey == null && _menu == null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        banner,
        Expanded(
          flex: showOrders ? 5 : 8,
          child: map,
        ),
        if (showOrders)
          Expanded(
            flex: 5,
            child: _ordersSheet(null),
          ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.cream, child: body);
    }

    return FertPage(
      title: 'Suppliers near you',
      subtitle: 'FERTILIZER \u00b7 LAND OWNER',
      child: Material(color: AppColors.cream, child: body),
    );
  }

  /// The title row of the bottom sheet.
  Widget _sheetTabs() {
    final int mine = _store.ownerOrders('Your Estate').length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'My orders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$mine',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.green,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The owner's own orders: what is waiting, what was accepted, with View and Cancel.
  Widget _ordersSheet(ScrollController? scrollController) {
    final mine = _store.ownerOrders('Your Estate');
    final pending = mine
        .where((o) => o.status == 'Pending Ack' || o.status == 'Negotiating')
        .toList();
    final accepted = mine.where((o) => o.status == 'Accepted').toList();
    final other = mine
        .where((o) => !pending.contains(o) && !accepted.contains(o))
        .toList();

    List<Widget> group(String title, List<FertOrder> list) => list.isEmpty
        ? const []
        : [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Text(
                '$title (${list.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final o in list) _orderTile(o),
          ];

    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x33183E29),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          _sheetTabs(),
          Expanded(
            child: ListView(
              controller: scrollController,
              primary: scrollController == null,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              children: [
                const Text(
                  'Orders you placed from the map. View details, or Edit to change bags/date or cancel.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                if (mine.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 22),
                    child: Center(
                      child: Text(
                        'No orders yet. Pick a supplier on the map and tap Order now.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  ),
                ...group('Pending Ack \u00b7 waiting for the provider', pending),
                ...group('Accepted', accepted),
                ...group('Cancelled by supplier or closed', other),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Everything about one order: items, price, date, status and the messages about it.
  void _showOrder(FertOrder o) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) {
          final bool open =
              o.status == 'Pending Ack' || o.status == 'Negotiating';
          final int kg = o.items.fold<int>(0, (a, l) => a + l.qty50 * 50);
          Widget metaTile(IconData icon, String label, String value) =>
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.greenSoft,
                      child: Icon(icon, size: 16, color: AppColors.green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFFCF8EF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order ${o.id}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        StatusPill.forStatus(o.status),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ITEMS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final l in o.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l.item.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          '${l.qty50} \u00d7 50 kg \u00b7 ${rupees(l.item.price50)} per 50 kg',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    rupees(l.lineTotal),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(height: 20, color: AppColors.line),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Order total',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                rupees(o.price),
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    metaTile(Icons.storefront, 'Supplier', o.company),
                    const SizedBox(height: 8),
                    metaTile(
                      Icons.shopping_bag_outlined,
                      'Quantity',
                      '${o.qty50} × 50 kg ($kg kg)',
                    ),
                    const SizedBox(height: 8),
                    metaTile(
                      Icons.event_outlined,
                      'Preferred date',
                      shortDate(o.preferredDate),
                    ),
                    const SizedBox(height: 8),
                    metaTile(Icons.schedule, 'Time slot', o.slot),
                    const SizedBox(height: 8),
                    metaTile(
                      Icons.payments_outlined,
                      'Payment',
                      'After the supplier accepts',
                    ),
                    if (o.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      metaTile(Icons.notes_outlined, 'Your note', o.message),
                    ],
                    if (o.negotiation.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'MESSAGES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final m in o.negotiation)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.from,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.green,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(m.text, style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              final match =
                                  _store.places.where((p) => p.id == o.placeId);
                              Navigator.pop(sheetContext);
                              if (match.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        FertilizerTalkPage(place: match.first),
                                  ),
                                ).then((_) {
                                  if (mounted) setState(() {});
                                });
                              }
                            },
                            child: const Text('Open chat'),
                          ),
                        ),
                        if (open) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                Navigator.pop(sheetContext);
                                await _editOrder(o);
                              },
                              child: const Text('Edit'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _orderMetaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.green),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOrder(FertOrder o) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FertilizerOrderEditSheet(order: o),
    );
    if (changed == true && mounted) setState(() {});
  }

  /// Attractive list card for My orders (not one long text line).
  Widget _orderTile(FertOrder o) {
    final bool canEdit =
        o.status == 'Pending Ack' || o.status == 'Negotiating';
    final String title = o.items.isEmpty
        ? o.product
        : o.items.map((l) => l.item.name).join(', ');
    final accent = o.status == 'Accepted'
        ? AppColors.green
        : (canEdit ? AppColors.warning : AppColors.muted);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showOrder(o),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.greenSoft,
                                    child: Text(
                                      o.company.isEmpty
                                          ? '?'
                                          : o.company[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.green,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: -4,
                                    bottom: -4,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: fertStatusColor(o.status),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${o.company} · ${o.id}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    FertOrderStatusDot(status: o.status),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _orderMetaChip(
                                Icons.shopping_bag_outlined,
                                '${o.qty50} bag${o.qty50 == 1 ? '' : 's'}',
                              ),
                              _orderMetaChip(
                                Icons.event_outlined,
                                shortDate(o.preferredDate),
                              ),
                              _orderMetaChip(Icons.schedule, o.slot),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1, color: AppColors.line),
                          ),
                          if (o.status == 'Cancelled' &&
                              o.message.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                o.message,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dangerText,
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Text(
                                rupees(o.price),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.green,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _showOrder(o),
                                child: const Text('View'),
                              ),
                              if (canEdit)
                                TextButton(
                                  onPressed: () => _editOrder(o),
                                  child: const Text('Edit'),
                                ),
                              if (o.status == 'Accepted')
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.dangerText,
                                  ),
                                  onPressed: () async {
                                    final ok =
                                        await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) =>
                                          FertilizerDisputeSheet(order: o),
                                    );
                                    if (ok == true && mounted) {
                                      setState(() {});
                                    }
                                  },
                                  child: const Text('Dispute'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapBlock() {
    final groups = _groups;
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _centerFor(_zoomFor(_radiusKm)),
              initialZoom: _zoomFor(_radiusKm),
              // Why: keep pan/zoom/taps enabled on Flutter web desktop browsers.
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (_, __) => setState(() {
                _selected = null;
                _clusterKey = null;
                _menu = null;
              }),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.kapconnect_mobile',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _estate,
                    radius: _radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderColor: AppColors.green.withValues(alpha: 0.4),
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  for (final entry in groups.entries)
                    _groupMarker(entry.key, entry.value),
                  Marker(
                    point: _estate,
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x44000000),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF115A36),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Column(
            children: [
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(99),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search brand, shop or fertilizer',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(99),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // Government programme: locked to CCB — no All / Private switch.
                    if (_govProgramme)
                      _drop('supplier', 'Supplier', 'CCB only', active: true)
                    else
                      _drop(
                        'supplier',
                        'Supplier',
                        _channel == 'all'
                            ? 'All'
                            : (_channel == 'private' ? 'Private' : 'Government'),
                      ),
                    _drop('distance', 'Distance', '${_radiusKm.toInt()} km'),
                    if (_activeChannel != 'gov')
                      _drop(
                        'brand',
                        'Brand',
                        _brands.isEmpty
                            ? 'Any'
                            : (_brands.length == 1
                                ? _brands.first
                                : '${_brands.length} picked'),
                        active: _brands.isNotEmpty,
                      )
                    else
                      _drop('brand', 'Brand', 'CCB', active: true),
                    _drop(
                      'kinds',
                      'Fertilizer',
                      _kinds.isEmpty ? 'Any' : '${_kinds.length} picked',
                      active: _kinds.isNotEmpty,
                    ),
                  ],
                ),
              ),
              if (_menu != null) _menuPanel() else _nearPill(),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 180,
          child: FloatingActionButton.small(
            heroTag: 'fert-recenter',
            backgroundColor: Colors.white,
            onPressed: () => _map.move(_centerFor(_zoomFor(_radiusKm)), _zoomFor(_radiusKm)),
            child: const Icon(Icons.my_location, color: AppColors.green),
          ),
        ),
        if (_clusterKey != null &&
            _selected == null &&
            (groups[_clusterKey!]?.length ?? 0) > 1)
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: _clusterPop(groups[_clusterKey!]!),
          ),
        if (_selected != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: _placePop(_selected!),
          ),
      ],
    );
  }

  void _setChannel(String c) {
    // Why: Government tab must stay CCB-only — ignore All / Private here.
    if (_govProgramme && c != 'gov') {
      setState(() => _menu = null);
      return;
    }
    setState(() {
      _channel = c;
      _selected = null;
      _clusterKey = null;
      _menu = null;
      if (c == 'gov') {
        _brands.clear();
        if (_radiusKm > 5) _radiusKm = 5;
      }
    });
    if (c == 'gov') {
      _map.move(_centerFor(_zoomFor(_radiusKm)), _zoomFor(_radiusKm));
    }
  }

  /// Map zoom that fits a radius around the estate.
  double _zoomFor(double km) => km <= 1 ? 14.2 : (km <= 5 ? 12.3 : 11.4);

  /// Centre of the map for a zoom, a little south of the estate so the list below does not cover it.
  LatLng _centerFor(double zoom) => LatLng(
    _estate.latitude - 0.04 * math.pow(2, 11.8 - zoom),
    _estate.longitude,
  );

  void _setRadius(double km) {
    setState(() {
      _radiusKm = km;
      _selected = null;
      _clusterKey = null;
      _menu = null;
    });
    _map.move(_centerFor(_zoomFor(km)), _zoomFor(km));
  }

  /// Suppliers inside a radius that match brand + fertilizer filters and the search.
  List<FertPlace> _within({String? channel, double? km}) {
    final c = channel ?? _activeChannel;
    final r = km ?? _radiusKm;
    final q = _search.text.trim().toLowerCase();
    final list = _store.places.where((p) {
      if (c == 'private' && p.isGov) return false;
      if (c == 'gov') {
        if (!_isCcbOutlet(p)) return false;
      } else if (_brands.isNotEmpty && !p.brands.any(_brands.contains)) {
        return false;
      }
      if (_kinds.isNotEmpty && !p.items.any((i) => i.kinds.any(_kinds.contains))) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${p.company} ${p.brandLine} ${p.items.map((i) => i.name).join(' ')}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return p.distanceKm <= r;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    if (c == 'gov' && list.isNotEmpty) return [list.first];
    return list;
  }

  /// One dropdown button: Supplier, Distance, Brand or Fertilizer.
  Widget _drop(String key, String name, String value, {bool active = false}) {
    final open = _menu == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: open || active ? AppColors.greenSoft : Colors.white,
        elevation: 2,
        shape: StadiumBorder(
          side: BorderSide(
            color: open || active ? AppColors.green : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => setState(() => _menu = open ? null : key),
          child: Padding(
            padding: const EdgeInsets.only(left: 12, right: 6, top: 7, bottom: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$name ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
                Icon(
                  open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 20,
                  color: AppColors.green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(IconData icon, String title, String sub, bool on, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: on ? AppColors.green : const Color(0xFFF4F1E8),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: on ? Colors.white : AppColors.green),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : AppColors.ink,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: on ? Colors.white70 : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The dropdown under the filter row. One at a time.
  Widget _menuPanel() {
    Widget body;
    if (_menu == 'supplier') {
      if (_govProgramme) {
        body = const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'This programme lists Coconut Cultivation Board (CCB) outlets only. Private suppliers are on the Suppliers tab.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        );
      } else {
        String n(String c) =>
            '${_within(channel: c).length} within ${_radiusKm.toInt()} km';
        body = Row(
          children: [
            _option(
              Icons.apps,
              'All',
              n('all'),
              _channel == 'all',
              () => _setChannel('all'),
            ),
            _option(
              Icons.storefront,
              'Private',
              n('private'),
              _channel == 'private',
              () => _setChannel('private'),
            ),
            _option(
              Icons.account_balance,
              'CCB only',
              n('gov'),
              _channel == 'gov',
              () => _setChannel('gov'),
            ),
          ],
        );
      }
    } else if (_menu == 'distance') {
      body = Row(
        children: [
          for (final km in [1.0, 5.0, 10.0])
            _option(
              Icons.radar,
              '${km.toInt()} km',
              '${_within(km: km).length} supplier${_within(km: km).length == 1 ? '' : 's'}',
              _radiusKm == km,
              () => _setRadius(km),
            ),
        ],
      );
    } else if (_menu == 'brand') {
      if (_activeChannel == 'gov') {
        body = const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Brand is fixed to CCB. Private brands are not shown in this programme.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        );
      } else {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pick brands (CIC, Hayleys…)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _brands.isEmpty
                      ? null
                      : () => setState(() {
                          _brands.clear();
                          _selected = null;
                          _clusterKey = null;
                        }),
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => setState(() => _menu = null),
                  child: const Text('Done'),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: [
                for (final b in kFertBrands)
                  FilterChip(
                    label: Text(
                      '$b · ${_store.places.where((p) => p.brands.contains(b)).length}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color:
                            _brands.contains(b) ? Colors.white : AppColors.ink,
                      ),
                    ),
                    selected: _brands.contains(b),
                    showCheckmark: true,
                    checkmarkColor: Colors.white,
                    selectedColor: AppColors.green,
                    backgroundColor: const Color(0xFFF4F1E8),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _brands.add(b);
                      } else {
                        _brands.remove(b);
                      }
                      _selected = null;
                      _clusterKey = null;
                    }),
                  ),
              ],
            ),
          ],
        );
      }
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tick the fertilizers you need',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: _kinds.isEmpty
                    ? null
                    : () => setState(() {
                        _kinds.clear();
                        _selected = null;
                        _clusterKey = null;
                      }),
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => setState(() => _menu = null),
                child: const Text('Done'),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final k in kFertKinds)
                FilterChip(
                  label: Text(
                    '$k \u00b7 ${_store.places.where((p) => p.items.any((i) => i.kinds.contains(k))).length}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _kinds.contains(k) ? Colors.white : AppColors.ink,
                    ),
                  ),
                  selected: _kinds.contains(k),
                  showCheckmark: true,
                  checkmarkColor: Colors.white,
                  selectedColor: AppColors.green,
                  backgroundColor: const Color(0xFFF4F1E8),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _kinds.add(k);
                    } else {
                      _kinds.remove(k);
                    }
                    _selected = null;
                    _clusterKey = null;
                  }),
                ),
            ],
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(18),
        color: Colors.white,
        child: Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: body),
      ),
    );
  }

  /// A one-line answer under the filters: how many suppliers are around the estate.
  Widget _nearPill() {
    final n = _within().length;
    final what = _activeChannel == 'gov'
        ? 'CCB'
        : (_activeChannel == 'private' ? 'private' : '');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(99),
            boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.near_me, size: 15, color: AppColors.green),
              const SizedBox(width: 6),
              Text(
                n == 0
                    ? 'No ${what.isEmpty ? '' : '$what '}suppliers within ${_radiusKm.toInt()} km'
                    : '$n ${what.isEmpty ? '' : '$what '}supplier${n == 1 ? '' : 's'} within ${_radiusKm.toInt()} km of your estate',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _groupMarker(String key, List<FertPlace> places) {
    final lead = places.first;
    final on = _clusterKey == key ||
        (_selected != null && places.any((p) => identical(p, _selected)));
    final far = lead.distanceKm > _radiusKm;
    final talking = places.any(
      (p) => (_store.shopTalks[p.id] ?? const []).isNotEmpty,
    );
    // Why: government pins always say CCB; private pins keep the shop name.
    final label = places.first.isGov
        ? 'CCB'
        : (places.length == 1
            ? places.first.company
            : places.map((p) => p.company).join(' · '));

    return Marker(
      point: _at(lead),
      width: 210,
      height: 78,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (places.length > 1) {
              _clusterKey = key;
              _selected = null;
            } else {
              _clusterKey = null;
              _selected = lead;
            }
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: on
                          ? AppColors.green
                          : (lead.isGov
                              ? const Color(0xFF0E3D28)
                              : Colors.white),
                      width: on ? 2 : (far ? 1.5 : 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: on
                            ? const Color(0x55256B45)
                            : const Color(0x30183E29),
                        blurRadius: on ? 14 : 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _pinColor(lead),
                          boxShadow: const [
                            BoxShadow(color: Color(0x33000000), blurRadius: 3),
                          ],
                        ),
                        child: Center(
                          child: CustomPaint(
                            size: const Size(17, 17),
                            painter: _SackPainter(_pinColor(lead)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (places.length > 1)
                  Positioned(
                    top: -7,
                    right: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '${places.length}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3D2A05),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (talking)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF6941A5),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'Negotiating',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (far)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  lead.physical ? 'Delivers far' : 'No shop · delivers',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _clusterPop(List<FertPlace> places) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(22),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '2 suppliers at this place',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _clusterKey = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Pick one. Each has its own brands and prices.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            for (final p in places)
              Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _pinColor(p),
                    child: Text(
                      _pinMark(p),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  title: Text(
                    p.isGov ? 'CCB' : p.company,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${p.brandLine} · ${_priceLines(p).first.$1} LKR ${withCommas(_priceLines(p).first.$2)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() {
                    _selected = p;
                    _clusterKey = null;
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// What the card shows for a supplier: each ticked fertilizer type with the lowest
  /// price this supplier has for it. With nothing ticked, its three cheapest products.
  List<(String, int)> _priceLines(FertPlace p) {
    if (_kinds.isNotEmpty) {
      final out = <(String, int)>[];
      for (final k in kFertKinds) {
        if (!_kinds.contains(k)) continue;
        final prices = p.items.where((i) => i.kinds.contains(k)).map((i) => i.price50);
        if (prices.isEmpty) continue;
        out.add((k, prices.reduce((a, b) => a < b ? a : b)));
      }
      if (out.isNotEmpty) return out;
    }
    final items = [...p.items]..sort((a, b) => a.price50.compareTo(b.price50));
    return [for (final i in items.take(3)) (i.name, i.price50)];
  }

  Widget _placePop(FertPlace p) {
    final far = p.distanceKm > _radiusKm;
    final where = far
        ? (p.physical
            ? '${p.distanceKm} km away · still delivers here'
            : 'No shop here · delivers far')
        : '${p.distanceKm.toStringAsFixed(1)} km';
    final lines = _priceLines(p);

    return Material(
      elevation: 14,
      borderRadius: BorderRadius.circular(22),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 104,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      p.isGov
                          ? 'assets/images/fert-gov.jpg'
                          : 'assets/images/fert-shop.jpg',
                      fit: BoxFit.cover,
                      alignment: p.isGov
                          ? const Alignment(0, -0.3)
                          : Alignment.center,
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xCC000000),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          p.isGov ? 'GOVERNMENT OUTLET' : 'PRIVATE SUPPLIER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _pinColor(p),
                  child: Text(
                    _pinMark(p),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.company,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${p.brandLine} · $where',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F9F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kinds.isEmpty
                        ? 'LOWEST PRICES'
                        : 'YOUR FERTILIZERS \u00b7 LOWEST PRICE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              l.$1,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            'LKR ${withCommas(l.$2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                          const Text(
                            ' / 50 kg',
                            style: TextStyle(fontSize: 10.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 14,
                  child: ElevatedButton(
                    onPressed: () async {
                      // The order sheet first. For a government supplier, Place order
                      // goes on to the request form (estate, NIC and land title).
                      final res = await showModalBottomSheet<Object?>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FertilizerOrderSheet(
                          place: p,
                          // Only the fertilizers the owner filtered stay ticked.
                          preselectedKinds: Set<String>.from(_kinds),
                        ),
                      );
                      if (!mounted) return;
                      if (res is GovOrderDraft) {
                        final sent =
                            await showModalBottomSheet<FertGovRequest>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => FertilizerGovOrderForm(place: p, draft: res),
                        );
                        if (sent == null || !mounted) return;
                        setState(() => _selected = null);
                        if (widget.onGovRequestSent != null) {
                          widget.onGovRequestSent!(sent);
                        } else {
                          showGovSentDialog(context, sent);
                        }
                        return;
                      }
                      if (res is FertOrder) {
                        setState(() => _selected = null);
                        widget.onOrderPlaced?.call(res);
                        return;
                      }
                      setState(() {});
                    },
                    child: const Text('Order now'),
                  ),
                ),
                if (!p.isGov) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 10,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FertilizerTalkPage(place: p),
                          ),
                        );
                        setState(() {});
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Negotiation', maxLines: 1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A small fertilizer bag, drawn in white on the coloured pin circle.
class _SackPainter extends CustomPainter {
  _SackPainter(this.cut);
  final Color cut; // colour of the plus cut into the bag

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 32;
    final bag = ui.Path()
      ..moveTo(11.2 * k, 3.6 * k)
      ..lineTo(20.8 * k, 3.6 * k)
      ..lineTo(19.4 * k, 9 * k)
      ..cubicTo(26.2 * k, 12 * k, 28.4 * k, 19 * k, 26.4 * k, 25 * k)
      ..cubicTo(25.4 * k, 28.4 * k, 22 * k, 29.6 * k, 16 * k, 29.6 * k)
      ..cubicTo(10 * k, 29.6 * k, 6.6 * k, 28.4 * k, 5.6 * k, 25 * k)
      ..cubicTo(3.6 * k, 19 * k, 5.8 * k, 12 * k, 12.6 * k, 9 * k)
      ..close();
    canvas.drawPath(bag, Paint()..color = Colors.white);
    final plus = Paint()
      ..color = cut
      ..strokeWidth = 2.6 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(16 * k, 14 * k), Offset(16 * k, 24 * k), plus);
    canvas.drawLine(Offset(11 * k, 19 * k), Offset(21 * k, 19 * k), plus);
  }

  @override
  bool shouldRepaint(covariant _SackPainter old) => old.cut != cut;
}

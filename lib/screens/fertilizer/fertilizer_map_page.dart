import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';
import 'fertilizer_order_sheet.dart';
import 'fertilizer_orders_page.dart';
import 'fertilizer_talk_page.dart';

/// PickMe-style supplier map — matches the HTML fertilizer demo.
class FertilizerMapPage extends StatefulWidget {
  const FertilizerMapPage({
    super.key,
    this.channel = 'all',
    this.embedded = false,
  });

  /// all | private | gov
  final String channel;
  final bool embedded;

  @override
  State<FertilizerMapPage> createState() => _FertilizerMapPageState();
}

class _FertilizerMapPageState extends State<FertilizerMapPage> {
  final _map = MapController();
  final _store = FertilizerStore.instance;
  final _search = TextEditingController();
  late String _channel;
  double _radiusKm = 15;
  bool _showPrices = true;
  FertPlace? _selected;
  String? _clusterKey;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
  }

  @override
  void didUpdateWidget(covariant FertilizerMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel) {
      _channel = widget.channel;
      _selected = null;
      _clusterKey = null;
    }
  }

  LatLng get _estate {
    final AppUser? me = AuthService.currentUser;
    return LatLng(me?.latitude ?? 7.4863, me?.longitude ?? 80.3647);
  }

  static const double _homeZoom = 11.8;
  LatLng get _home => LatLng(_estate.latitude - 0.04, _estate.longitude);
  LatLng _at(FertPlace p) =>
      LatLng(_estate.latitude + p.dLat, _estate.longitude + p.dLng);

  String _spotKey(FertPlace p) =>
      '${p.dLat.toStringAsFixed(4)}_${p.dLng.toStringAsFixed(4)}';

  List<FertPlace> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _store.places.where((p) {
      if (_channel == 'private' && p.isGov) return false;
      if (_channel == 'gov' && !p.isGov) return false;
      if (q.isNotEmpty) {
        final hay =
            '${p.company} ${p.brandLine} ${p.items.map((i) => i.name).join(' ')}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (p.distanceKm <= _radiusKm) return true;
      return p.willingFar;
    }).toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
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
    final list = _visible;
    // Map fills the screen. List is a bottom sheet — drag/scroll it up to open.
    // Why: keeps the map highlighted; avoids FlutterMap-inside-page-scroll blank bug.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _channel == 'gov'
                          ? 'GOVERNMENT'
                          : _channel == 'private'
                              ? 'PRIVATE SUPPLIERS'
                              : 'ESTATE OWNER',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _channel == 'gov'
                          ? 'Government programme'
                          : 'Suppliers near you',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
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
                  setState(() {});
                },
                child: Text(
                  _pendingMine > 0 ? 'Orders · $_pendingMine' : 'Orders',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _mapBlock(),
                  ),
                ),
              ),
              // Peek shows title + first rows so the list is visible; drag up for more.
              DraggableScrollableSheet(
                initialChildSize: 0.32,
                minChildSize: 0.28,
                maxChildSize: 0.68,
                snap: true,
                snapSizes: const [0.32, 0.5, 0.68],
                builder: (context, scrollController) {
                  return _supplierSheet(list, scrollController);
                },
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return ColoredBox(color: AppColors.cream, child: body);

    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Material(color: AppColors.cream, child: SafeArea(child: body)),
        ),
      ),
    );
  }

  Widget _supplierSheet(List<FertPlace> list, ScrollController scrollController) {
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x33183E29),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Who can supply you',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${list.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? ListView(
                    controller: scrollController,
                    children: const [
                      SizedBox(height: 24),
                      Center(
                        child: Text(
                          'No matches',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final pl = list[i];
                      final on = identical(_selected, pl);
                      final far = pl.distanceKm > _radiusKm;
                      final where = far
                          ? '${pl.distanceKm.toStringAsFixed(0)} km · delivers'
                          : '${pl.distanceKm.toStringAsFixed(1)} km';
                      return Material(
                        color: on ? AppColors.greenSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() {
                            _selected = on ? null : pl;
                            _clusterKey = null;
                          }),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: _pinColor(pl),
                                  child: Text(
                                    _pinMark(pl),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pl.company,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '${pl.brandLine} · $where',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'LKR ${withCommas(pl.minPrice50)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
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
              initialCenter: _home,
              initialZoom: _homeZoom,
              onTap: (_, __) => setState(() {
                _selected = null;
                _clusterKey = null;
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
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _chip('All', _channel == 'all', () {
                      setState(() {
                        _channel = 'all';
                        _selected = null;
                        _clusterKey = null;
                      });
                    }),
                    _chip('Shops', _channel == 'private', () {
                      setState(() {
                        _channel = 'private';
                        _selected = null;
                        _clusterKey = null;
                      });
                    }),
                    _chip('Government', _channel == 'gov', () {
                      setState(() {
                        _channel = 'gov';
                        _selected = null;
                        _clusterKey = null;
                      });
                    }),
                    for (final km in [1.0, 5.0, 15.0, 30.0])
                      _chip('${km.toInt()} km', _radiusKm == km, () {
                        setState(() {
                          _radiusKm = km;
                          _selected = null;
                          _clusterKey = null;
                        });
                      }),
                    _chip(
                      _showPrices ? 'Prices on' : 'Prices off',
                      _showPrices,
                      () => setState(() => _showPrices = !_showPrices),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: 180,
          child: FloatingActionButton.small(
            heroTag: 'fert-recenter',
            backgroundColor: Colors.white,
            onPressed: () => _map.move(_home, _homeZoom),
            child: const Icon(Icons.my_location, color: AppColors.green),
          ),
        ),
        if (_clusterKey != null &&
            _selected == null &&
            (groups[_clusterKey!]?.length ?? 0) > 1)
          Positioned(
            left: 24,
            right: 24,
            bottom: 120,
            child: _clusterPop(groups[_clusterKey!]!),
          ),
        if (_selected != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 120,
            child: _placePop(_selected!),
          ),
      ],
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: on ? AppColors.green : Colors.white,
        elevation: 2,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : AppColors.ink,
              ),
            ),
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
    final brands = places.expand((p) => p.brands).toSet().join(' + ');
    final low = places
        .map((p) => p.minPrice50)
        .reduce((a, b) => a < b ? a : b);
    final label = _showPrices ? '$brands · MIN ${withCommas(low)}' : brands;

    return Marker(
      point: _at(lead),
      width: 168,
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
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: _pinColor(lead),
                        child: Text(
                          _pinMark(lead),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 118),
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
              ListTile(
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
                  p.company,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${p.brandLine} · MIN LKR ${withCommas(p.minPrice50)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() {
                  _selected = p;
                  _clusterKey = null;
                }),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placePop(FertPlace p) {
    final far = p.distanceKm > _radiusKm;
    final where = far
        ? (p.physical
            ? '${p.distanceKm} km away · still delivers here'
            : 'No shop here · delivers far')
        : '${p.distanceKm.toStringAsFixed(1)} km';
    final talks = _store.shopTalks[p.id] ?? const <FertChat>[];

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
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'MIN LKR ${withCommas(p.minPrice50)} ',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                  const TextSpan(
                    text: '/ 50 kg',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (talks.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Negotiation: ${talks.last.text}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 14,
                  child: ElevatedButton(
                    onPressed: () async {
                      await showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FertilizerOrderSheet(place: p),
                      );
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
                      child: const Text('Negotiation'),
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

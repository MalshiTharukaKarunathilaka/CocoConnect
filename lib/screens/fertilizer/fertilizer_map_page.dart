import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/auth_service.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';
import 'fertilizer_order_sheet.dart';
import 'fertilizer_orders_page.dart';
import 'fertilizer_talk_page.dart';
import 'supplier_calendar_page.dart';

/// Estate owner map of nearby fertilizer shops and CDO, styled like machinery.
class FertilizerMapPage extends StatefulWidget {
  const FertilizerMapPage({super.key});

  @override
  State<FertilizerMapPage> createState() => _FertilizerMapPageState();
}

class _FertilizerMapPageState extends State<FertilizerMapPage> {
  final _map = MapController();
  final _store = FertilizerStore.instance;
  String _channel = 'all'; // all | private | gov
  double _radiusKm = 15;
  FertPlace? _selected;

  LatLng get _estate {
    final AppUser? me = AuthService.currentUser;
    return LatLng(me?.latitude ?? 7.4863, me?.longitude ?? 80.3647);
  }

  static const double _homeZoom = 11.8;
  LatLng get _home => LatLng(_estate.latitude - 0.04, _estate.longitude);

  LatLng _at(FertPlace p) =>
      LatLng(_estate.latitude + p.dLat, _estate.longitude + p.dLng);

  List<FertPlace> get _visible {
    return _store.places.where((p) {
      if (_channel == 'private' && p.isGov) return false;
      if (_channel == 'gov' && !p.isGov) return false;
      // Far willing suppliers still show inside a small radius.
      if (p.distanceKm <= _radiusKm) return true;
      return p.willingFar;
    }).toList()..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
  }

  int get _pendingMine => _store
      .ownerOrders('Your Estate')
      .where((o) => o.status == 'Pending Ack' || o.status == 'Negotiating')
      .length;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _visible;
    return OwnerPage(
      child: Column(
        children: [
          OwnerHeader(
            title: 'Fertilizer Near You',
            subtitle: 'SHOPS & GOVERNMENT · 50 KG BASE UNIT',
            actions: [
              IconButton(
                tooltip: 'My orders',
                icon: Badge(
                  isLabelVisible: _pendingMine > 0,
                  label: Text('$_pendingMine'),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: kOwnerGreen,
                  ),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FertilizerOrdersPage(),
                    ),
                  );
                  setState(() {});
                },
              ),
              IconButton(
                tooltip: 'Supplier calendar (demo)',
                icon: const Icon(Icons.calendar_month, color: kOwnerGreen),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SupplierCalendarPage(),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _home,
                    initialZoom: _homeZoom,
                    onTap: (_, __) => setState(() => _selected = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.kapconnect_mobile',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _estate,
                          radius: _radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: kOwnerGreen.withValues(alpha: 0.08),
                          borderColor: kOwnerGreen.withValues(alpha: 0.4),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final p in shown) _marker(p),
                        Marker(
                          point: _estate,
                          width: 120,
                          height: 66,
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: kOwnerGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Your Estate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.location_on,
                                color: kOwnerGreen,
                                size: 36,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(left: 12, right: 12, top: 12, child: _chips()),
                Positioned(
                  right: 12,
                  top: 64,
                  child: FloatingActionButton.small(
                    heroTag: 'fert-recenter',
                    backgroundColor: Colors.white,
                    onPressed: () => _map.move(_home, _homeZoom),
                    child: const Icon(Icons.my_location, color: kOwnerGreen),
                  ),
                ),
                if (_selected != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _sheet(_selected!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(FertPlace p) {
    final on = identical(p, _selected);
    final far = p.distanceKm > _radiusKm;
    return Marker(
      point: _at(p),
      width: 128,
      height: 72,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => setState(() => _selected = p),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: on
                    ? (p.isGov ? kOwnerGreen : kOwnerBrown)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: p.isGov ? kOwnerGreen : kOwnerBrown,
                  width: far ? 1.5 : 1.2,
                ),
              ),
              child: Text(
                '${p.brands.first} · MIN ${withCommas(p.minPrice50)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: on ? Colors.white : kOwnerInk,
                ),
              ),
            ),
            Icon(
              p.isGov ? Icons.account_balance : Icons.storefront,
              color: p.isGov ? kOwnerGreen : kOwnerBrown,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips() {
    Widget channelChip(String code, String label) {
      final on = _channel == code;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? kOwnerGreen : Colors.white,
          shape: const StadiumBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() {
              _channel = code;
              _selected = null;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: on ? Colors.white : kOwnerInk,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget radiusChip(double km) {
      final on = _radiusKm == km;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? kOwnerGreen : Colors.white,
          shape: const StadiumBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() {
              _radiusKm = km;
              _selected = null;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                '${km.toInt()} km',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: on ? Colors.white : kOwnerInk,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          channelChip('all', 'All'),
          channelChip('private', 'Shops'),
          channelChip('gov', 'Government'),
          radiusChip(1),
          radiusChip(5),
          radiusChip(15),
          radiusChip(30),
        ],
      ),
    );
  }

  Widget _sheet(FertPlace p) {
    final far = p.distanceKm > _radiusKm;
    final talks = _store.shopTalks[p.id] ?? const <FertChat>[];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: kOwnerBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: p.isGov ? kOwnerGreenSoft : const Color(0xFFFFF0E4),
                child: Icon(
                  p.isGov ? Icons.account_balance : Icons.storefront,
                  color: p.isGov ? kOwnerGreen : kOwnerBrown,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: kOwnerInk,
                      ),
                    ),
                    Text(
                      '${p.brandLine} · ${far ? (p.physical ? 'Delivers far' : 'No shop · delivers') : '${p.distanceKm.toStringAsFixed(1)} km'}',
                      style: const TextStyle(fontSize: 12, color: kOwnerMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'MIN ${rupees(p.minPrice50)} / 50 kg',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kOwnerGreen,
            ),
          ),
          if (talks.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Negotiation: ${talks.last.text}',
              style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOwnerGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FertilizerOrderSheet(place: p),
                    );
                    setState(() {});
                  },
                  child: const Text(
                    'Order now',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (!p.isGov) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kOwnerGreen,
                      side: const BorderSide(color: kOwnerGreen),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FertilizerTalkPage(place: p),
                        ),
                      );
                      setState(() {});
                    },
                    child: const Text(
                      'Negotiation',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

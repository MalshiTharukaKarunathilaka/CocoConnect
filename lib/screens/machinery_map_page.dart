import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_service.dart';
import '../services/machinery_api.dart';
import '../services/api_client.dart';
import '../widgets/machinery_widgets.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'my_bookings_page.dart';
import 'service_schedule_page.dart';

/// Estate owners see tractors, backhoes and hand tractors around their estate.
/// Pass [type] (TRACTOR / BACKHOE / HAND_TRACTOR) to start on one type.
class MachineryMapPage extends StatefulWidget {
  final String? type;

  const MachineryMapPage({super.key, this.type});

  @override
  State<MachineryMapPage> createState() => MachineInforyMapPageState();
}

class MachineInforyMapPageState extends State<MachineryMapPage> {
  final _map = MapController();
  List<MachineInfo> _machines = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadMachines();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRadius());
  }

  Future<void> _loadMachines() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await const MachineryApi().machines(owner: true);
      if (!mounted) return;
      setState(() {
        _machines = rows.map((row) {
          final services = (row['services'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final location = row['latitude'] == null || row['longitude'] == null
              ? null
              : LatLng(
                  (row['latitude'] as num).toDouble(),
                  (row['longitude'] as num).toDouble(),
                );
          return MachineInfo(
            '${row['name']}',
            '${row['provider_name']}',
            switch (row['category']) {
              'Backhoe' => 'BACKHOE',
              'Hand Tractor' => 'HAND_TRACTOR',
              _ => 'TRACTOR',
            },
            services.map((s) => '${s['name']}').join(' - '),
            double.parse('${services.first['rate']}'),
            '${services.first['unit']}',
            0,
            0,
            0,
            0,
            0,
            databaseId: row['id'] as int,
            location: location,
            liveServices: services,
          );
        }).toList();
        _selected = _shown.isEmpty ? null : _shown.first;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  late String _filter = widget.type ?? 'ALL';

  /// How far from the estate to look, in km. Only used when the owner has a
  /// saved location to measure from.
  static const List<double> _radiusOptions = [2, 5, 10, 25, 50];
  double _radiusKm = 25;
  late MachineInfo? _selected = _shown.isEmpty ? null : _shown.first;

  void _openCalendar(MachineInfo m) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ServiceSchedulePage(
        machineName: m.name,
        provider: m.provider,
        type: m.type,
        info: m,
        machineAt: m.location,
        estateAt: AuthService.currentUser?.hasCoordinates == true
            ? _estate
            : null,
        km: _km(m),
      ),
    ),
  );

  LatLng get _estate {
    final AppUser? me = AuthService.currentUser;
    return LatLng(
      me?.latitude ?? 7.4863, // Kurunegala when no location is saved
      me?.longitude ?? 80.3647,
    );
  }

  /// The bottom card covers the lower part of the map, so look at a point a
  /// little south of the estate; that puts the estate and every machine in
  /// the visible part above the card.
  static const double _homeZoom = 11.5;
  LatLng get _home => LatLng(_estate.latitude - 0.055, _estate.longitude);

  LatLng _at(MachineInfo m) => m.location ?? _estate;

  double _km(MachineInfo m) =>
      m.location == null || AuthService.currentUser?.hasCoordinates != true
      ? double.infinity
      : const Distance().as(LengthUnit.Meter, _estate, _at(m)) / 1000;

  bool get _hasHome => AuthService.currentUser?.hasCoordinates == true;

  bool _inRadius(MachineInfo m) => !_hasHome || _km(m) <= _radiusKm;

  List<MachineInfo> get _shown =>
      _machines
          .where((m) => (_filter == 'ALL' || m.type == _filter) && _inRadius(m))
          .toList()
        ..sort((a, b) => _km(a).compareTo(_km(b)));

  /// How many machines of a type are inside the chosen distance.
  int _countFor(String code) => _machines
      .where((m) => (code == 'ALL' || m.type == code) && _inRadius(m))
      .length;

  /// Zooms the map so the whole search circle is on screen, clear of the chips
  /// at the top and the machine card at the bottom.
  void _fitRadius() {
    if (!_hasHome) {
      _map.move(_home, _homeZoom);
      return;
    }
    final double dLat = _radiusKm / 111.32;
    final double dLng =
        _radiusKm / (111.32 * math.cos(_estate.latitude * math.pi / 180));
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(_estate.latitude - dLat, _estate.longitude - dLng),
            LatLng(_estate.latitude + dLat, _estate.longitude + dLng),
          ),
          padding: const EdgeInsets.fromLTRB(24, 130, 24, 300),
        ),
      );
    } catch (_) {
      // The map is not on screen yet; the next change will fit it.
    }
  }

  void _setRadius(double km) {
    setState(() {
      _radiusKm = km;
      final List<MachineInfo> list = _shown;
      _selected = list.isEmpty ? null : list.first;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitRadius());
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<MachineInfo> shown = _shown;
    return OwnerPage(
      child: Column(
        children: [
          OwnerHeader(
            title: 'Machinery Near You',
            subtitle: 'TRACTORS, BACKHOES & HAND TRACTORS',
            actions: [
              IconButton(
                tooltip: 'My bookings',
                icon: const Icon(
                  Icons.receipt_long_outlined,
                  color: kOwnerGreen,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyBookingsPage(),
                  ),
                ),
              ),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_error!),
                  TextButton(
                    onPressed: _loadMachines,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          if (!_loading && _error == null && shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No registered machinery with service rates is available yet.',
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _home,
                    initialZoom: _homeZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.kapconnect_mobile',
                    ),
                    if (_hasHome)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _estate,
                            radius: _radiusKm * 1000,
                            useRadiusInMeter: true,
                            color: kOwnerGreen.withValues(alpha: 0.08),
                            borderColor: kOwnerGreen.withValues(alpha: 0.5),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final m in shown.where((m) => m.location != null))
                          _marker(m),
                        if (AuthService.currentUser?.hasCoordinates == true)
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
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _chips(),
                      const SizedBox(height: 8),
                      _radiusChips(),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 108,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    backgroundColor: Colors.white,
                    onPressed: _fitRadius,
                    child: const Icon(Icons.my_location, color: kOwnerGreen),
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: _sheet(shown)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Marker _marker(MachineInfo m) {
    final bool on = identical(m, _selected);
    final double size = on ? 54 : 44;
    return Marker(
      point: _at(m),
      width: 110,
      height: size + 26,
      // Keep the icon centred on the machine's position.
      alignment: Alignment(0, (size + 26 - size) / (size + 26)),
      child: GestureDetector(
        onTap: () => setState(() => _selected = m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: on ? kOwnerGreen : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? Colors.white : kOwnerGreen,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                machineIcon(m.type),
                color: on ? Colors.white : kOwnerGreen,
                size: on ? 28 : 22,
              ),
            ),
            const SizedBox(height: 3),
            // Price tag under the icon.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: on ? kOwnerBrown : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kOwnerBrown),
              ),
              child: Text(
                '${rupees(m.rate)}/${m.unit == 'hour' ? 'hr' : 'ac'}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: on ? Colors.white : kOwnerBrown,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Within 2 | 5 | 10 | 25 | 50 km": only machines inside the circle show.
  Widget _radiusChips() {
    if (!_hasHome) {
      return Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        elevation: 2,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Save your estate location in your profile to filter by distance',
            style: TextStyle(fontSize: 11.5, color: kOwnerMuted),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            elevation: 2,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.radar, size: 16, color: kOwnerGreen),
                  SizedBox(width: 5),
                  Text(
                    'Within',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: kOwnerInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          for (final double km in _radiusOptions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: _radiusKm == km ? kOwnerGreen : Colors.white,
                shape: const StadiumBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => _setRadius(km),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '${km.toStringAsFixed(0)} km',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _radiusKm == km ? Colors.white : kOwnerInk,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chips() {
    Widget chip(String code, String label, IconData? icon) {
      final bool on = _filter == code;
      final int count = _countFor(code);
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: on ? kOwnerGreen : Colors.white,
          shape: const StadiumBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => setState(() {
              _filter = code;
              final list = _shown;
              _selected = list.isEmpty ? null : list.first;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 16,
                      color: on ? Colors.white : kOwnerGreen,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    '$label ($count)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: on ? Colors.white : kOwnerInk,
                    ),
                  ),
                ],
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
          chip('ALL', 'All', null),
          chip('TRACTOR', 'Tractors', Icons.agriculture),
          chip('BACKHOE', 'Backhoes', Icons.construction),
          chip('HAND_TRACTOR', 'Hand Tractors', Icons.grass),
        ],
      ),
    );
  }

  Widget _sheet(List<MachineInfo> shown) {
    final MachineInfo? m = _selected;
    final bool nearest =
        m != null && shown.isNotEmpty && identical(m, shown.first);

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(
              _hasHome
                  ? '${shown.length} available within ${_radiusKm.toStringAsFixed(0)} km of your estate · tap a marker'
                  : '${shown.length} available · tap a marker',
              style: const TextStyle(
                fontSize: 12.5,
                color: kOwnerMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (m == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text(
                _hasHome
                    ? 'No machines within ${_radiusKm.toStringAsFixed(0)} km. Try a larger distance.'
                    : 'No machines of this type nearby right now.',
                style: const TextStyle(fontSize: 13.5, color: kOwnerMuted),
              ),
            )
          else ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openCalendar(m),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        MachinePhoto(m, width: 116, height: 116, radius: 14),
                        if (nearest)
                          const Positioned(
                            left: 6,
                            top: 6,
                            child: PhotoChip(
                              'Nearest',
                              icon: Icons.star,
                              filled: true,
                            ),
                          ),
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: PhotoChip(machineLabel(m.type)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 116,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: kOwnerInk,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        m.provider,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: kOwnerMuted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    if (m.databaseId == null)
                                      const Icon(
                                        Icons.verified,
                                        size: 15,
                                        color: kOwnerGreen,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (m.databaseId == null)
                                      const Icon(
                                        Icons.star,
                                        size: 15,
                                        color: Color(0xFFF2A900),
                                      ),
                                    const SizedBox(width: 3),
                                    Text(
                                      (m.databaseId != null
                                          ? 'Registered provider'
                                          : '${m.rating}'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: kOwnerInk,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        (_km(m).isFinite
                                            ? ' - ${_km(m).toStringAsFixed(1)} km straight-line distance'
                                            : ' - Distance unavailable'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: kOwnerMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              m.services,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: kOwnerInk,
                              ),
                            ),
                            Text.rich(
                              TextSpan(
                                text: rupees(m.rate),
                                children: [
                                  TextSpan(
                                    text: ' / ${m.unit}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.normal,
                                      color: kOwnerMuted,
                                    ),
                                  ),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: kOwnerBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: OwnerPrimaryButton(
                label: 'View Calendar & Book',
                arrow: true,
                onPressed: () => _openCalendar(m),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

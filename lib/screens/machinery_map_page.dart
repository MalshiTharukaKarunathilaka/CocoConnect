import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_service.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'service_schedule_page.dart';

/// A machine shown on the demo map.
class _Machine {
  final String name;
  final String provider;
  final String type; // TRACTOR / BACKHOE
  final String services;
  final int rate;
  final String unit;

  /// Offset from the estate, in degrees, so the demo always sits nearby.
  final double dLat;
  final double dLng;

  const _Machine(
    this.name,
    this.provider,
    this.type,
    this.services,
    this.rate,
    this.unit,
    this.dLat,
    this.dLng,
  );
}

// Sample machinery for showing the idea to clients. Not from the database.
const List<_Machine> _machines = [
  _Machine(
    'Massey Ferguson 240',
    'Sunil Machinery',
    'TRACTOR',
    'Slasher · Disc Ploughing · Rotary',
    5000,
    'acre',
    0.018,
    0.022,
  ),
  _Machine(
    'Kubota M6040 4WD',
    'Nimal Farm Mechanization',
    'TRACTOR',
    'Slasher · Trailer haulage',
    4800,
    'acre',
    -0.024,
    0.031,
  ),
  _Machine(
    'Mahindra 575 DI',
    'Dambokka Agro',
    'TRACTOR',
    'Koku Nagula · Rotary',
    4500,
    'acre',
    0.035,
    -0.019,
  ),
  _Machine(
    'Swaraj 744 FE',
    'Ruwan Tractor Service',
    'TRACTOR',
    'Disc Ploughing · Trailer',
    6800,
    'acre',
    -0.041,
    -0.028,
  ),
  _Machine(
    'JCB 3CX',
    'Kithsiri Earthmovers',
    'BACKHOE',
    'Ditch & drainage · Pit digging',
    4200,
    'hour',
    0.006,
    -0.043,
  ),
  _Machine(
    'CAT 424B',
    'Lanka Excavations',
    'BACKHOE',
    'Canal digging · Land clearing',
    6500,
    'hour',
    -0.052,
    0.009,
  ),
];

IconData _iconFor(String type) =>
    type == 'BACKHOE' ? Icons.construction : Icons.agriculture;

/// Estate owners see tractors and backhoes around their estate on a map.
class MachineryMapPage extends StatefulWidget {
  const MachineryMapPage({super.key});

  @override
  State<MachineryMapPage> createState() => _MachineryMapPageState();
}

class _MachineryMapPageState extends State<MachineryMapPage> {
  final _map = MapController();
  String _filter = 'ALL';
  _Machine? _selected = _machines.first;

  LatLng get _estate {
    final AppUser? me = AuthService.currentUser;
    return LatLng(
      me?.latitude ?? 7.4863, // Kurunegala when no location is saved
      me?.longitude ?? 80.3647,
    );
  }

  LatLng _at(_Machine m) =>
      LatLng(_estate.latitude + m.dLat, _estate.longitude + m.dLng);

  double _km(_Machine m) =>
      const Distance().as(LengthUnit.Meter, _estate, _at(m)) / 1000;

  List<_Machine> get _shown =>
      _machines.where((m) => _filter == 'ALL' || m.type == _filter).toList()
        ..sort((a, b) => _km(a).compareTo(_km(b)));

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_Machine> shown = _shown;
    return OwnerPage(
      child: Column(
        children: [
          OwnerHeader(
            title: 'Machinery Near You',
            subtitle: 'TRACTORS & BACKHOES',
            actions: [
              IconButton(
                tooltip: 'Service schedule',
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: kOwnerGreen,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServiceSchedulePage(),
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
                    initialCenter: _estate,
                    initialZoom: 11.6,
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
                          radius: 7000,
                          useRadiusInMeter: true,
                          color: kOwnerGreen.withValues(alpha: 0.08),
                          borderColor: kOwnerGreen.withValues(alpha: 0.4),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        for (final m in shown) _marker(m),
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
                    heroTag: 'recenter',
                    backgroundColor: Colors.white,
                    onPressed: () => _map.move(_estate, 11.6),
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

  Marker _marker(_Machine m) {
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
                _iconFor(m.type),
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

  Widget _chips() {
    Widget chip(String code, String label, IconData? icon) {
      final bool on = _filter == code;
      final int count = code == 'ALL'
          ? _machines.length
          : _machines.where((m) => m.type == code).length;
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
        ],
      ),
    );
  }

  Widget _sheet(List<_Machine> shown) {
    final _Machine? m = _selected;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
          const SizedBox(height: 10),
          Text(
            '${shown.length} available near your estate',
            style: const TextStyle(
              fontSize: 12.5,
              color: kOwnerMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (m != null)
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: kOwnerGreenSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconFor(m.type), color: kOwnerGreen, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: kOwnerInk,
                        ),
                      ),
                      Text(
                        m.provider,
                        style: const TextStyle(
                          fontSize: 13,
                          color: kOwnerMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_km(m).toStringAsFixed(1)} km away · ~${(_km(m) / 20 * 60 + 5).round()} min',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kOwnerGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rupees(m.rate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: kOwnerBrown,
                      ),
                    ),
                    Text(
                      '/ ${m.unit}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: kOwnerMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (m != null) ...[
            const SizedBox(height: 8),
            Text(
              m.services,
              style: const TextStyle(fontSize: 12.5, color: kOwnerInk),
            ),
            const SizedBox(height: 12),
            OwnerPrimaryButton(
              label:
                  'Book ${m.type == 'BACKHOE' ? 'this Backhoe' : 'this Tractor'}',
              arrow: true,
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Booking is coming soon')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

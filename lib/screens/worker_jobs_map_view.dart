import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';
import '../services/worker_service.dart';
import '../widgets/machinery_widgets.dart';
import '../widgets/open_street_map_tiles.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';

/// The three kinds of day job, with the label, the icon on the map and the
/// text a job's category has to contain.
class _JobKind {
  final String code; // what the dashboard filter stores
  final String chip;
  final String title;
  final IconData icon;

  const _JobKind(this.code, this.chip, this.title, this.icon);
}

const List<_JobKind> _kinds = [
  _JobKind('Nut Gatherer', 'Nut Gatherer', 'Nut Gatherer', Icons.eco),
  _JobKind('Manual', 'Manual Worker', 'Manual Worker', Icons.build),
  _JobKind('Machine', 'Machine Weeder', 'Machine Weeder', Icons.agriculture),
];

_JobKind _kindOf(WorkerJob job) {
  final String c = job.category.toLowerCase();
  for (final _JobKind k in _kinds) {
    if (c.contains(k.code.toLowerCase())) return k;
  }
  return _kinds[1];
}

const List<String> _photos = [
  'assets/estates/land-grove.jpg',
  'assets/estates/land-palm.jpg',
  'assets/estates/land-rows.jpg',
  'assets/estates/land-kingcoconut.jpg',
  'assets/estates/land-farmer.jpg',
];

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// One land that has day jobs posted.
class _Land {
  final int id;
  final String name;
  final String owner;
  final String location;
  final LatLng? point;
  final List<WorkerJob> jobs;
  final double km; // straight-line from the worker; infinity when unknown

  _Land(
    this.id,
    this.name,
    this.owner,
    this.location,
    this.point,
    this.jobs,
    this.km,
  );

  Iterable<_JobKind> get kinds =>
      _kinds.where((k) => jobs.any((j) => _kindOf(j) == k));

  double get fromRate => jobs.map((j) => j.dailyRate).reduce(math.min);
  double get toRate => jobs.map((j) => j.dailyRate).reduce(math.max);

  int get openPlaces => jobs.fold(
    0,
    (sum, j) => sum + math.max(0, j.workersNeeded - j.confirmedWorkers),
  );

  /// One line per kind of job: places still open and the day rate.
  List<(_JobKind, int, double, double)> get byKind => [
    for (final _JobKind k in kinds)
      (
        k,
        jobs
            .where((j) => _kindOf(j) == k)
            .fold(
              0,
              (n, j) => n + math.max(0, j.workersNeeded - j.confirmedWorkers),
            ),
        jobs
            .where((j) => _kindOf(j) == k)
            .map((j) => j.dailyRate)
            .reduce(math.min),
        jobs
            .where((j) => _kindOf(j) == k)
            .map((j) => j.dailyRate)
            .reduce(math.max),
      ),
  ];

  DateTime get nextDate =>
      jobs.map((j) => j.requiredDate).reduce((a, b) => a.isBefore(b) ? a : b);
}

/// "Jobs Near You": the same map-and-card layout as Machinery Near You, for the
/// day jobs lands have posted. Each land with jobs shows one pin with an icon
/// for every kind of job it needs. Tapping a pin shows the land's card; the
/// button opens the land's jobs, where the worker applies as before.
class WorkerJobsMapView extends StatefulWidget {
  /// Jobs to show, already limited to the chosen date.
  final List<WorkerJob> jobs;
  final String? category; // null = all kinds
  final int? radiusKm; // null = any distance
  final ValueChanged<String?> onCategory;
  final ValueChanged<int?> onRadius;
  final ValueChanged<String> onOpenLand;
  final VoidCallback onMyJobs;
  final String subtitle;

  const WorkerJobsMapView({
    super.key,
    required this.jobs,
    required this.category,
    required this.radiusKm,
    required this.onCategory,
    required this.onRadius,
    required this.onOpenLand,
    required this.onMyJobs,
    required this.subtitle,
  });

  @override
  State<WorkerJobsMapView> createState() => _WorkerJobsMapViewState();
}

class _WorkerJobsMapViewState extends State<WorkerJobsMapView> {
  final MapController _map = MapController();
  int? _selectedId;

  static const List<int> _radii = [2, 5, 10, 25, 50];

  LatLng? get _home {
    final AppUser? me = AuthService.currentUser;
    return me?.hasCoordinates == true
        ? LatLng(me!.latitude!, me.longitude!)
        : null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  void didUpdateWidget(WorkerJobsMapView old) {
    super.didUpdateWidget(old);
    if (old.category != widget.category || old.radiusKm != widget.radiusKm) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  bool _kindMatches(WorkerJob j) =>
      widget.category == null ||
      j.category.toLowerCase().contains(widget.category!.toLowerCase());

  double _km(WorkerJob j) {
    final LatLng? home = _home;
    if (home != null && j.latitude != null && j.longitude != null) {
      return const Distance().as(
            LengthUnit.Meter,
            home,
            LatLng(j.latitude!, j.longitude!),
          ) /
          1000;
    }
    return j.distanceKm ?? double.infinity;
  }

  bool _inRadius(WorkerJob j) =>
      widget.radiusKm == null || _km(j) <= widget.radiusKm!;

  /// Lands with at least one job that passes the kind and distance filters,
  /// nearest first.
  List<_Land> get _lands {
    final Map<int, List<WorkerJob>> byLand = {};
    for (final WorkerJob j in widget.jobs) {
      if (_kindMatches(j) && _inRadius(j)) {
        byLand.putIfAbsent(j.estateOwnerId, () => []).add(j);
      }
    }
    final List<_Land> out = byLand.entries.map((e) {
      final WorkerJob first = e.value.first;
      final WorkerJob? located = e.value
          .where((j) => j.latitude != null && j.longitude != null)
          .firstOrNull;
      return _Land(
        e.key,
        first.estateName,
        first.estateOwnerName,
        first.estateLocation.isNotEmpty ? first.estateLocation : first.location,
        located == null ? null : LatLng(located.latitude!, located.longitude!),
        e.value,
        e.value.map(_km).reduce(math.min),
      );
    }).toList()..sort((a, b) => a.km.compareTo(b.km));
    return out;
  }

  /// Jobs of one kind that pass the distance filter, for the chip counts.
  int _countFor(String? code) => widget.jobs
      .where(
        (j) =>
            _inRadius(j) &&
            (code == null ||
                j.category.toLowerCase().contains(code.toLowerCase())),
      )
      .length;

  void _fit() {
    // Zoom to the worker and the nearest lands, not the whole island.
    final List<LatLng> points = [
      for (final _Land l in _lands.where((l) => l.point != null).take(8))
        l.point!,
      ?_home,
    ];
    try {
      if (points.isEmpty) {
        _map.move(const LatLng(7.6, 80.7), 7.2);
      } else if (points.length == 1) {
        _map.move(
          LatLng(points.first.latitude - 0.03, points.first.longitude),
          11.5,
        );
      } else {
        _map.fitCamera(
          CameraFit.coordinates(
            coordinates: points,
            padding: const EdgeInsets.fromLTRB(90, 250, 90, 340),
            maxZoom: 14,
          ),
        );
      }
    } catch (_) {
      // The map is not on screen yet; the next change fits it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_Land> lands = _lands;
    final _Land? selected =
        lands.where((l) => l.id == _selectedId).firstOrNull ??
        (lands.isEmpty ? null : lands.first);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Jobs Near You',
                      style: TextStyle(
                        color: kOwnerGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.subtitle,
                        style: const TextStyle(
                          color: kOwnerMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'My jobs',
                icon: const Icon(
                  Icons.receipt_long_outlined,
                  color: kOwnerGreen,
                ),
                onPressed: widget.onMyJobs,
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: const MapOptions(
                  initialCenter: LatLng(7.6, 80.7),
                  initialZoom: 7.2,
                ),
                children: [
                  kapConnectMapTiles(),
                  if (_home != null && widget.radiusKm != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _home!,
                          radius: widget.radiusKm! * 1000.0,
                          useRadiusInMeter: true,
                          color: kOwnerGreen.withValues(alpha: 0.08),
                          borderColor: kOwnerGreen.withValues(alpha: 0.5),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (final _Land l in lands)
                        if (l.point != null) _marker(l, identical(l, selected)),
                      if (_home != null) _youMarker(),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                top: 0,
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
                  heroTag: 'jobs-recenter',
                  backgroundColor: Colors.white,
                  onPressed: _fit,
                  child: const Icon(Icons.my_location, color: kOwnerGreen),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _sheet(lands, selected),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Marker _youMarker() => Marker(
    point: _home!,
    width: 90,
    height: 56,
    alignment: Alignment.topCenter,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: kOwnerBrown,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'You',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Icon(Icons.location_on, color: kOwnerBrown, size: 30),
      ],
    ),
  );

  /// One mark per land that has jobs of the chosen kind: that kind's icon, or
  /// a job icon when all kinds are shown. Hovering or tapping it shows what the
  /// land needs in a bubble above it.
  Marker _marker(_Land l, bool on) {
    final _JobKind? chosen = widget.category == null
        ? null
        : _kinds.where((k) => k.code == widget.category).firstOrNull;
    final double size = on ? 50 : 42;
    return Marker(
      point: l.point!,
      width: 64,
      height: size,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (_selectedId != l.id) setState(() => _selectedId = l.id);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selectedId = l.id),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (on)
                Positioned(
                  bottom: size + 6,
                  left: -100,
                  right: -100,
                  child: Center(child: _bubble(l)),
                ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: on ? kOwnerGreen : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: on ? Colors.white : kOwnerGreen,
                    width: 2.5,
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
                  chosen?.icon ?? Icons.work,
                  color: on ? Colors.white : kOwnerGreen,
                  size: on ? 26 : 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// What a land needs, shown above its pin while it is hovered or selected.
  Widget _bubble(_Land l) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kOwnerGreen.withValues(alpha: 0.4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: kOwnerInk,
          ),
        ),
        const SizedBox(height: 4),
        for (final (_JobKind k, int places, double from, double to) in l.byKind)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(k.icon, size: 14, color: kOwnerGreen),
                const SizedBox(width: 5),
                Text(
                  '${k.title} · $places open · ${rupees(from)}${to > from ? '+' : ''}',
                  softWrap: false,
                  style: const TextStyle(fontSize: 11, color: kOwnerInk),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _pill(Widget child, {bool on = false, VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: on ? kOwnerGreen : Colors.white,
      shape: const StadiumBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: child,
        ),
      ),
    ),
  );

  Widget _chips() {
    Widget chip(String? code, String label, IconData? icon) {
      final bool on = widget.category == code;
      return _pill(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: on ? Colors.white : kOwnerGreen),
              const SizedBox(width: 5),
            ],
            Text(
              '$label (${_countFor(code)})',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: on ? Colors.white : kOwnerInk,
              ),
            ),
          ],
        ),
        on: on,
        onTap: () {
          setState(() => _selectedId = null);
          widget.onCategory(code);
        },
      );
    }

    return Wrap(
      runSpacing: 8,
      children: [
        chip(null, 'All', null),
        for (final _JobKind k in _kinds) chip(k.code, k.chip, k.icon),
      ],
    );
  }

  Widget _radiusChips() {
    if (_home == null) {
      return Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        elevation: 2,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Save your location in your profile to filter by distance',
            style: TextStyle(fontSize: 11.5, color: kOwnerMuted),
          ),
        ),
      );
    }
    return Wrap(
      runSpacing: 8,
      children: [
        _pill(
          const Row(
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
        _pill(
          Text(
            'Any',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: widget.radiusKm == null ? Colors.white : kOwnerInk,
            ),
          ),
          on: widget.radiusKm == null,
          onTap: () => widget.onRadius(null),
        ),
        for (final int km in _radii)
          _pill(
            Text(
              '$km km',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: widget.radiusKm == km ? Colors.white : kOwnerInk,
              ),
            ),
            on: widget.radiusKm == km,
            onTap: () => widget.onRadius(km),
          ),
      ],
    );
  }

  Widget _sheet(List<_Land> lands, _Land? l) {
    final bool nearest =
        l != null && lands.isNotEmpty && identical(l, lands.first);
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
              '${lands.length} land${lands.length == 1 ? '' : 's'} hiring'
              '${widget.radiusKm != null ? ' within ${widget.radiusKm} km' : ''} · tap a pin',
              style: const TextStyle(
                fontSize: 12.5,
                color: kOwnerMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (l == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text(
                'No jobs match right now. Try another job type or a larger distance.',
                style: TextStyle(fontSize: 13.5, color: kOwnerMuted),
              ),
            )
          else
            _landCard(l, nearest),
        ],
      ),
    );
  }

  Widget _landCard(_Land l, bool nearest) {
    final String photo = _photos[l.id.abs() % _photos.length];
    final WorkerJob first = l.jobs.first;
    final double? rating = first.estateOwnerAverageRating;
    final String rate = l.fromRate == l.toRate
        ? rupees(l.fromRate)
        : '${rupees(l.fromRate)} – ${rupees(l.toRate)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onOpenLand(l.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        photo,
                        width: 116,
                        height: 116,
                        fit: BoxFit.cover,
                      ),
                    ),
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
                      child: PhotoChip(
                        '${l.jobs.length} job${l.jobs.length == 1 ? '' : 's'}',
                      ),
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
                              l.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: kOwnerInk,
                              ),
                            ),
                            Text(
                              l.owner,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: kOwnerMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (rating != null) ...[
                                  const Icon(
                                    Icons.star,
                                    size: 15,
                                    color: Color(0xFFF2A900),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: kOwnerInk,
                                    ),
                                  ),
                                ] else
                                  const Text(
                                    'New land',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: kOwnerInk,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    l.km.isFinite
                                        ? ' - ${l.km.toStringAsFixed(1)} km straight-line distance'
                                        : ' - Distance unavailable',
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
                        Text.rich(
                          TextSpan(
                            text: rate,
                            children: const [
                              TextSpan(
                                text: ' / day',
                                style: TextStyle(
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final (_JobKind k, int places, double from, double to)
                      in l.byKind)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kOwnerGreenSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(k.icon, size: 15, color: kOwnerGreen),
                          const SizedBox(width: 6),
                          Text(
                            '${k.title} · $places open · ${rupees(from)}${to > from ? '+' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: kOwnerInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'From ${l.nextDate.day} ${_months[l.nextDate.month - 1]}',
                style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
              ),
              const SizedBox(height: 10),
              OwnerPrimaryButton(
                label: 'View Jobs & Apply',
                arrow: true,
                onPressed: () => widget.onOpenLand(l.name),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

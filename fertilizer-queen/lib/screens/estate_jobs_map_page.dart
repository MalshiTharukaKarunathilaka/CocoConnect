import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_service.dart';
import '../services/worker_service.dart';
import '../widgets/open_street_map_tiles.dart';

class EstateJobsMapPage extends StatefulWidget {
  final List<WorkerJob> jobs;
  final int radiusKm;
  final bool nearbyOnly;

  const EstateJobsMapPage({
    super.key,
    required this.jobs,
    this.radiusKm = 20,
    this.nearbyOnly = false,
  });

  @override
  State<EstateJobsMapPage> createState() => _EstateJobsMapPageState();
}

class _EstateJobsMapPageState extends State<EstateJobsMapPage>
    with WidgetsBindingObserver {
  late Future<List<WorkerEstate>> _estates;
  Timer? _estateRefreshTimer;
  bool _tileLoadFailed = false;
  int _tileGeneration = 0;

  LatLng? get _workerPoint {
    final user = AuthService.currentUser;
    if (user?.latitude == null || user?.longitude == null) return null;
    return LatLng(user!.latitude!, user.longitude!);
  }

  double get _radiusZoom => switch (widget.radiusKm) {
    <= 2 => 13,
    <= 5 => 11.8,
    <= 10 => 10.8,
    <= 20 => 9.8,
    _ => 9.2,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _estates = _loadEstates();
    _estateRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshEstates(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _estateRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshEstates();
  }

  Future<List<WorkerEstate>> _loadEstates() => widget.nearbyOnly
      ? WorkerService.getNearbyEstates(radiusKm: widget.radiusKm)
      : WorkerService.getEstates();

  void _refreshEstates() {
    if (!mounted) return;
    setState(() => _estates = _loadEstates());
  }

  void _handleTileError(TileImage _, Object error, StackTrace? stackTrace) {
    if (_tileLoadFailed || !mounted) return;
    setState(() => _tileLoadFailed = true);
  }

  void _retryMap() {
    setState(() {
      _tileLoadFailed = false;
      _tileGeneration++;
      _estates = _loadEstates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mappedEstates = _mappedEstates();
    // Start zoomed out enough to show Jaffna and the southern estates together.
    const center = LatLng(7.5, 80.7);
    final workerPoint = _workerPoint;

    return FutureBuilder<List<WorkerEstate>>(
      future: _estates,
      builder: (context, estateSnapshot) {
        final estates = estateSnapshot.data ?? const <WorkerEstate>[];
        final estateGroups = _groupNearbyEstates(estates);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.nearbyOnly
                  ? 'Reachable Estates (${widget.radiusKm} km)'
                  : 'All Estates',
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh estates',
                onPressed: _refreshEstates,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: widget.nearbyOnly && workerPoint != null
                      ? workerPoint
                      : center,
                  initialZoom: widget.nearbyOnly && workerPoint != null
                      ? _radiusZoom
                      : 7,
                  minZoom: 6,
                  maxZoom: 18,
                ),
                children: [
                  kapConnectMapTiles(
                    key: ValueKey(_tileGeneration),
                    onTileError: _handleTileError,
                  ),
                  if (widget.nearbyOnly && workerPoint != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: workerPoint,
                          radius: widget.radiusKm * 1000,
                          useRadiusInMeter: true,
                          color: const Color(0x22256B45),
                          borderColor: const Color(0xAA256B45),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (widget.nearbyOnly && workerPoint != null)
                        Marker(
                          point: workerPoint,
                          width: 54,
                          height: 54,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF256B45),
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Color(0xFF256B45),
                              size: 38,
                            ),
                          ),
                        ),
                      for (final group in estateGroups)
                        _estateGroupMarker(context, group),
                      if (!widget.nearbyOnly && estates.isEmpty)
                        for (final estate in mappedEstates)
                          _marker(
                            context,
                            point: estate.point,
                            name: estate.job.estateName,
                            location: estate.job.location,
                          ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
              if (estateSnapshot.connectionState == ConnectionState.waiting)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
              if (estateSnapshot.hasError)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 28,
                  child: _mapMessage(
                    _workerPoint == null && widget.nearbyOnly
                        ? 'Set your worker location to find reachable estates.'
                        : 'Could not load estates. Check the connection and retry.',
                    showRetry: true,
                  ),
                )
              else if (widget.nearbyOnly &&
                  estateSnapshot.connectionState == ConnectionState.done &&
                  estates.isEmpty)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 28,
                  child: _mapMessage(
                    'No estates are within ${widget.radiusKm} km of your location.',
                  ),
                ),
              if (_tileLoadFailed)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Material(
                    elevation: 3,
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, color: Colors.orange),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Some map tiles could not load.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: _retryMap,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_EstateGroup> _groupNearbyEstates(List<WorkerEstate> estates) {
    final candidates = estates
        .where((estate) => _pointForEstate(estate) != null)
        .toList();
    final groups = <_EstateGroup>[];
    final clusterDistanceKm = widget.nearbyOnly ? 5.0 : 30.0;
    const distance = Distance();

    while (candidates.isNotEmpty) {
      final seed = candidates.removeAt(0);
      final seedPoint = _pointForEstate(seed)!;
      final members = <WorkerEstate>[seed];
      for (var index = candidates.length - 1; index >= 0; index--) {
        final point = _pointForEstate(candidates[index])!;
        final km = distance.as(
          LengthUnit.Kilometer,
          seedPoint,
          point,
        );
        if (km <= clusterDistanceKm) {
          members.add(candidates.removeAt(index));
        }
      }
      final points = members.map(_pointForEstate).whereType<LatLng>().toList();
      groups.add(
        _EstateGroup(
          estates: members,
          point: LatLng(
            points.fold(0.0, (sum, point) => sum + point.latitude) /
                points.length,
            points.fold(0.0, (sum, point) => sum + point.longitude) /
                points.length,
          ),
        ),
      );
    }
    return groups;
  }

  Marker _estateGroupMarker(BuildContext context, _EstateGroup group) {
    if (group.estates.length == 1) {
      final estate = group.estates.single;
      return _marker(
        context,
        point: group.point,
        name: estate.estateName,
        location: estate.location,
        distanceKm: estate.distanceKm,
      );
    }

    final names = group.estates.map((estate) => estate.estateName).join(' + ');
    return Marker(
      point: group.point,
      width: 230,
      height: 78,
      child: GestureDetector(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${group.estates.length} nearby estates',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                for (final estate in group.estates)
                  ListTile(
                    leading: const Icon(
                      Icons.park,
                      color: Color(0xFF256B45),
                    ),
                    title: Text(estate.estateName),
                    subtitle: Text(
                      estate.distanceKm == null
                          ? estate.location
                          : '${estate.location}\n'
                                '${estate.distanceKm!.toStringAsFixed(1)} km away',
                    ),
                  ),
              ],
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF256B45)),
              ),
              child: Text(
                names,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.park, color: Color(0xFF256B45), size: 34),
          ],
        ),
      ),
    );
  }

  Marker _marker(
    BuildContext context, {
    required LatLng point,
    required String name,
    required String location,
    double? distanceKm,
  }) {
    final distanceLabel = distanceKm == null
        ? null
        : '${distanceKm.toStringAsFixed(1)} km away';
    return Marker(
      point: point,
      width: 190,
      height: 70,
      child: GestureDetector(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => ListTile(
            leading: const Icon(Icons.park),
            title: Text(name),
            subtitle: Text(
              distanceLabel == null ? location : '$location\n$distanceLabel',
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                distanceLabel == null ? name : '$name • $distanceLabel',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const Icon(Icons.park, color: Color(0xFF256B45), size: 34),
          ],
        ),
      ),
    );
  }

  Widget _mapMessage(String message, {bool showRetry = false}) {
    return Material(
      elevation: 3,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF256B45)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (showRetry)
              TextButton(onPressed: _retryMap, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  List<_MappedEstate> _mappedEstates() {
    final byEstate = <String, WorkerJob>{};
    for (final job in widget.jobs) {
      if (_pointFor(job) != null) {
        byEstate.putIfAbsent(job.estateName, () => job);
      }
    }

    final usedPoints = <String, int>{};
    return byEstate.values.map((job) {
      final base = _pointFor(job)!;
      final key = '${base.latitude},${base.longitude}';
      final duplicateIndex = usedPoints.update(
        key,
        (count) => count + 1,
        ifAbsent: () => 0,
      );
      // Keep estates with the same fallback/GPS point visible as separate markers.
      final point = duplicateIndex == 0
          ? base
          : LatLng(base.latitude, base.longitude + duplicateIndex * 0.015);
      return _MappedEstate(job: job, point: point);
    }).toList();
  }

  LatLng? _pointFor(WorkerJob job) {
    if (job.latitude != null && job.longitude != null) {
      return LatLng(job.latitude!, job.longitude!);
    }

    final place = '${job.estateName} ${job.location}'.toLowerCase();
    if (place.contains('jaffna')) {
      return const LatLng(9.6615, 80.0255);
    }
    if (place.contains('walasmulla')) {
      return const LatLng(6.1447, 80.6851);
    }
    if (place.contains('middeniya')) {
      return const LatLng(6.2730, 80.7670);
    }
    if (place.contains('hambantota')) {
      return const LatLng(6.1241, 81.1185);
    }
    return null;
  }

  LatLng? _pointForEstate(WorkerEstate estate) {
    if (estate.latitude != null && estate.longitude != null) {
      return LatLng(estate.latitude!, estate.longitude!);
    }
    final place = '${estate.estateName} ${estate.location}'.toLowerCase();
    if (place.contains('jaffna')) return const LatLng(9.6615, 80.0255);
    if (place.contains('walasmulla')) return const LatLng(6.1447, 80.6851);
    if (place.contains('middeniya')) return const LatLng(6.2730, 80.7670);
    if (place.contains('hambantota')) return const LatLng(6.1241, 81.1185);
    return null;
  }
}

class _MappedEstate {
  final WorkerJob job;
  final LatLng point;

  const _MappedEstate({required this.job, required this.point});
}

class _EstateGroup {
  final List<WorkerEstate> estates;
  final LatLng point;

  const _EstateGroup({required this.estates, required this.point});
}

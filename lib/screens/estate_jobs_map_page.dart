import '../widgets/mobile_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/worker_service.dart';
import '../widgets/open_street_map_tiles.dart';
import '../widgets/role_navigation_page.dart';

class EstateJobsMapPage extends StatefulWidget {
  final List<WorkerJob> jobs;
  final int radiusKm;
  final bool nearbyOnly;
  final int? initialEstateId;
  final String? initialEstateName;

  const EstateJobsMapPage({
    super.key,
    required this.jobs,
    this.radiusKm = 20,
    this.nearbyOnly = false,
    this.initialEstateId,
    this.initialEstateName,
  });

  @override
  State<EstateJobsMapPage> createState() => _EstateJobsMapPageState();
}

class _EstateJobsMapPageState extends State<EstateJobsMapPage>
    with WidgetsBindingObserver {
  late Future<List<WorkerEstate>> _estates;
  final MapController _map = MapController();
  Timer? _estateRefreshTimer;
  bool _tileLoadFailed = false;
  int _tileGeneration = 0;
  int? _selectedEstateId;
  bool _initialFocusHandled = false;

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
    _map.dispose();
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
    setState(() {
      _estates = _loadEstates();
    });
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
        _focusInitialEstateWhenReady(estateSnapshot, estates);
        return RoleNavigationPage(
          chatScope: ChatScope.dayJobs,
          current: AppTab.dashboard,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.nearbyOnly
                    ? 'Reachable Lands (${widget.radiusKm} km)'
                    : 'All Lands',
              ),
              actions: [
                IconButton(
                  tooltip: 'Refresh lands',
                  onPressed: _refreshEstates,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: widget.nearbyOnly && workerPoint != null
                        ? workerPoint
                        : center,
                    initialZoom: widget.nearbyOnly && workerPoint != null
                        ? _radiusZoom
                        : 7,
                    minZoom: 6,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onTap: (_, _) => setState(() => _selectedEstateId = null),
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
                        for (final group in _groupNearbyEstates(estates))
                          if (group.estates.any(
                            (estate) => estate.id == _selectedEstateId,
                          ))
                            for (final estate in group.estates)
                              _estateMarker(estate, _pointForEstate(estate)!)
                          else
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
                Positioned(
                  right: 12,
                  bottom: 28,
                  child: Column(
                    children: [
                      _mapControl(
                        tooltip: 'Zoom in',
                        icon: Icons.add,
                        onPressed: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 8),
                      _mapControl(
                        tooltip: 'Zoom out',
                        icon: Icons.remove,
                        onPressed: () => _zoomBy(-1),
                      ),
                      const SizedBox(height: 8),
                      _mapControl(
                        tooltip: 'Show all lands',
                        icon: Icons.fit_screen,
                        onPressed: () => _fitAllEstates(estates),
                      ),
                      if (workerPoint != null) ...[
                        const SizedBox(height: 8),
                        _mapControl(
                          tooltip: 'My location',
                          icon: Icons.my_location,
                          onPressed: () => _map.move(workerPoint, 15),
                        ),
                      ],
                    ],
                  ),
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
                          ? 'Set your worker location to find reachable lands.'
                          : 'Could not load lands. Check the connection and retry.',
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
                      'No lands are within ${widget.radiusKm} km of your location.',
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
        final km = distance.as(LengthUnit.Kilometer, seedPoint, point);
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
      return _estateMarker(estate, group.point);
    }

    final names = group.estates.map((estate) => estate.estateName).join(' + ');
    return Marker(
      point: group.point,
      width: 230,
      height: 78,
      child: GestureDetector(
        onTap: () => showModalBottomSheet<void>(
          isScrollControlled: true,
          useSafeArea: true,
          context: context,
          showDragHandle: true,
          builder: mobileSheetBuilder(
            (_) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${group.estates.length} nearby lands',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final estate in group.estates)
                    ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _focusEstate(estate, _pointForEstate(estate)!);
                      },
                      leading: const Icon(Icons.park, color: Color(0xFF256B45)),
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

  Marker _estateMarker(WorkerEstate estate, LatLng point) {
    final selected = estate.id == _selectedEstateId;
    return Marker(
      point: point,
      width: 190,
      height: selected ? 86 : 80,
      alignment: Alignment.bottomCenter,
      child: Semantics(
        button: true,
        label: '${estate.estateName}, ${estate.location}',
        child: Tooltip(
          message: estate.estateName,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusEstate(estate, point),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 184),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFFB45C)
                          : const Color(0xFF256B45),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    estate.location.trim().isEmpty
                        ? estate.estateName
                        : '${estate.estateName}\n${estate.location}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: selected ? 44 : 38,
                  height: selected ? 44 : 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFB45C)
                        : const Color(0xFF256B45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x44000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.park, color: Colors.white, size: 23),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _focusInitialEstateWhenReady(
    AsyncSnapshot<List<WorkerEstate>> snapshot,
    List<WorkerEstate> estates,
  ) {
    if (_initialFocusHandled ||
        snapshot.connectionState != ConnectionState.done ||
        estates.isEmpty ||
        (widget.initialEstateId == null && widget.initialEstateName == null)) {
      return;
    }
    WorkerEstate? target;
    for (final estate in estates) {
      if ((widget.initialEstateId != null &&
              estate.id == widget.initialEstateId) ||
          (widget.initialEstateName != null &&
              estate.estateName == widget.initialEstateName)) {
        target = estate;
        break;
      }
    }
    _initialFocusHandled = true;
    final point = target == null ? null : _pointForEstate(target);
    if (target == null || point == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusEstate(target!, point, showSheet: false);
    });
  }

  Future<void> _focusEstate(
    WorkerEstate estate,
    LatLng fallbackPoint, {
    bool showSheet = true,
  }) async {
    var selectedEstate = estate;
    var point = fallbackPoint;
    String? locationWarning;

    if (estate.id > 0) {
      try {
        selectedEstate = await WorkerService.getEstateLocation(estate.id);
        final exactPoint = _pointForEstate(selectedEstate);
        if (exactPoint != null) point = exactPoint;
      } on ApiException catch (error) {
        locationWarning = error.message;
      }
    }
    if (!mounted) return;
    setState(() => _selectedEstateId = estate.id);
    _map.move(point, 15);
    if (showSheet) {
      await _showEstateLocation(selectedEstate, point, locationWarning);
    }
  }

  Future<void> _showEstateLocation(
    WorkerEstate estate,
    LatLng point,
    String? warning,
  ) async {
    final coordinates =
        '${point.latitude.toStringAsFixed(6)}, '
        '${point.longitude.toStringAsFixed(6)}';
    await showModalBottomSheet<void>(
      isScrollControlled: true,
      useSafeArea: true,
      context: context,
      showDragHandle: true,
      builder: mobileSheetBuilder(
        (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estate.estateName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Land owner: ${estate.ownerName}'),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: Color(0xFF256B45),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        estate.location.trim().isEmpty
                            ? coordinates
                            : '${estate.location}\n$coordinates',
                      ),
                    ),
                  ],
                ),
                if (estate.distanceKm != null) ...[
                  const SizedBox(height: 8),
                  Text('${estate.distanceKm!.toStringAsFixed(1)} km away'),
                ],
                if (warning != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$warning. Showing the approximate map position.',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _map.move(point, 17);
                        },
                        icon: const Icon(Icons.zoom_in_map),
                        label: const Text('Zoom Here'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(
                              text: '${estate.location}\n$coordinates',
                            ),
                          );
                          if (!mounted || !sheetContext.mounted) return;
                          Navigator.pop(sheetContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Land location copied.'),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF256B45),
                        ),
                        icon: const Icon(Icons.content_copy),
                        label: const Text('Copy Location'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _zoomBy(double amount) {
    final nextZoom = (_map.camera.zoom + amount).clamp(6.0, 18.0).toDouble();
    _map.move(_map.camera.center, nextZoom);
  }

  void _fitAllEstates(List<WorkerEstate> estates) {
    final points = estates.map(_pointForEstate).whereType<LatLng>().toList();
    if (points.isEmpty) return;
    if (points.length == 1) {
      _map.move(points.single, 15);
      return;
    }
    _map.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
        maxZoom: 15,
      ),
    );
  }

  Widget _mapControl({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: const Color(0xFF256B45)),
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
          isScrollControlled: true,
          useSafeArea: true,
          context: context,
          builder: mobileSheetBuilder(
            (_) => ListTile(
              leading: const Icon(Icons.park),
              title: Text(name),
              subtitle: Text(
                distanceLabel == null ? location : '$location\n$distanceLabel',
              ),
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

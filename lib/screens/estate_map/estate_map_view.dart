import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/estate_geometry.dart';
import '../../models/estate_plants.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/open_street_map_tiles.dart';
import 'plant_sheet.dart';
import 'plant_widgets.dart';

const String _satelliteUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/'
    'MapServer/tile/{z}/{y}/{x}';

/// The estate map with its three tabs: Map (tap to mark), Records (a grid to
/// add, change and delete) and Summary (what the admin dashboard will see).
/// Used inside the sign-up set-up and as a page of its own.
class EstateMapView extends StatefulWidget {
  const EstateMapView({super.key});

  @override
  State<EstateMapView> createState() => _EstateMapViewState();
}

class _EstateMapViewState extends State<EstateMapView> {
  final EstateMapStore _store = EstateMapStore.instance;
  final MapController _map = MapController();

  int _tab = 0;
  bool _satellite = true;
  bool _locating = false;
  PlantGroup? _filter;

  EstatePlan get _plan => _store.plan!;

  @override
  void initState() {
    super.initState();
    _store.addListener(_changed);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    _map.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  // ---- geometry: the real shape if the owner drew it, else a square of the right area ----

  EstateGeometry get _geo => EstateGeometry(_plan);
  LatLngBounds get _bounds => _geo.bounds;
  List<LatLng> get _boundary => _geo.outline;

  /// The grid over the land, cut off at its edge so it follows any shape.
  List<Polyline> get _gridLines => [
    for (final l in _geo.gridLines())
      Polyline(
        points: l,
        color: _satellite ? const Color(0x66FFFFFF) : const Color(0x45256B45),
        strokeWidth: 1,
      ),
  ];

  bool _insideEstate(LatLng p) => _geo.contains(p);

  void _fit() => _map.fitCamera(
    CameraFit.bounds(bounds: _bounds, padding: const EdgeInsets.all(28)),
  );

  // ---- drawing the real shape of the estate ----

  bool _drawing = false;
  final List<LatLng> _draft = [];

  /// While set, every tap on the map places one more plant like this one.
  PlantMark? _brush;

  void _startDrawing() {
    setState(() {
      _drawing = true;
      _draft.clear();
      _tab = 0;
    });
    _toast('Tap each corner of your estate, one after another.');
  }

  void _stopDrawing() => setState(() {
    _drawing = false;
    _draft.clear();
  });

  Future<void> _saveShape() async {
    if (_draft.length < 3) {
      _toast('Tap at least 3 corners.', bad: true);
      return;
    }
    final double acres = EstateGeometry.areaAcres(_draft).clamp(0.1, 5000.0);
    await _store.setPlan(_plan.withShape(List.of(_draft), acres));
    if (!mounted) return;
    _stopDrawing();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fit();
    });
    _toast('Estate shape saved: ${acres.toStringAsFixed(1)} acres.');
  }

  Future<void> _backToSquare() async {
    await _store.setPlan(_plan.withoutShape());
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fit();
    });
    _toast('The estate is drawn as a square again.');
  }

  // ---- adding, changing and deleting ----

  void _toast(String text, {bool bad = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: bad ? AppColors.danger : AppColors.ink,
        ),
      );
  }

  Future<void> _open(LatLng point, {PlantMark? existing}) async {
    final PlantSheetResult? result = await showPlantSheet(
      context,
      point: point,
      newId: _store.newId(),
      existing: existing,
    );
    if (result == null || !mounted) return;
    if (result.delete && existing != null) {
      await _store.remove(existing.id);
      if (mounted) _toast('Mark removed');
      return;
    }
    final PlantMark? mark = result.mark;
    if (mark == null) return;
    if (existing == null) {
      if (_store.marks.length >= _maxMarks) {
        _toast('An estate map holds up to $_maxMarks marks.', bad: true);
        return;
      }
      await _store.add(mark);
    } else {
      await _store.update(mark);
    }
    if (!mounted) return;
    if (result.repeat) {
      setState(() => _brush = mark);
      _toast(
        'Tap the map to place each ${mark.info.name.toLowerCase()}. '
        'Press Done when you are finished.',
      );
      return;
    }
    // Validation is not connected yet, so for now this only says it will be.
    _toast(
      '${mark.info.name} saved. It will be checked by your CDO once '
      'validation is switched on.',
    );
  }

  static const int _maxMarks = 3000;

  /// Tapping a plant on the map: a small card with Edit and Remove, so
  /// neither needs a long form. Remove can be undone from the message.
  Future<void> _quickActions(PlantMark m) async {
    final PlantKind k = m.info;
    final String detail = m.age != null
        ? '${m.age} yrs · ${ageRange(m.age!).stage}'
        : '${m.severity ?? ''} severity';
    final String? pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PlantBadge(kind: k, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          k.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  MarkStatusPill(m.status),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx, 'remove'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx, 'edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || pick == null) return;
    if (pick == 'edit') {
      await _open(LatLng(m.lat, m.lng), existing: m);
      return;
    }
    await _store.remove(m.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${k.name} removed'),
          backgroundColor: AppColors.ink,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () => _store.add(m),
          ),
        ),
      );
  }

  Future<void> _placeLikeBrush(LatLng p) async {
    final PlantMark? b = _brush;
    if (b == null) return;
    if (_store.marks.length >= _maxMarks) {
      _toast('An estate map holds up to $_maxMarks marks.', bad: true);
      return;
    }
    await _store.add(
      PlantMark(
        id: _store.newId(),
        kind: b.kind,
        lat: p.latitude,
        lng: p.longitude,
        count: 1,
        age: b.age,
        severity: b.severity,
        note: b.note,
        updated: DateTime.now(),
      ),
    );
  }

  void _onMapTap(LatLng p) {
    if (_drawing) {
      setState(() => _draft.add(p));
      return;
    }
    if (_brush != null) {
      if (!_insideEstate(p)) {
        _toast('That is outside your estate.', bad: true);
        return;
      }
      _placeLikeBrush(p);
      return;
    }
    if (!_insideEstate(p)) {
      _toast('That is outside your estate. Tap inside the white line.',
          bad: true);
      return;
    }
    _open(p);
  }

  Future<void> _addHere() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.currentPosition();
      if (!mounted) return;
      final LatLng here = LatLng(pos.latitude, pos.longitude);
      if (!_insideEstate(here)) {
        _toast(
          'You are not at your estate right now. Tap the map where the '
          'plant is instead.',
          bad: true,
        );
        return;
      }
      _map.move(here, math.max(_map.camera.zoom, 18));
      await _open(here);
    } on LocationProblem catch (p) {
      if (mounted) _toast(p.message, bad: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  List<PlantMark> get _filtered => [
    for (final m in _store.marks)
      if (_filter == null || m.info.group == _filter) m,
  ];

  // ---- build ----

  @override
  Widget build(BuildContext context) {
    if (!_store.ready) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        _stats(),
        _tabs(),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [_mapTab(), _recordsTab(), _summaryTab()],
          ),
        ),
      ],
    );
  }

  Widget _stats() {
    Widget chip(IconData i, Color c, String big, String small) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(i, size: 18, color: c),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    big,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    small,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final int pending = _store.marks
        .where((m) => m.status == kPendingValidation)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          chip(Icons.park, AppColors.green, '${_store.totalTrees}', 'trees marked'),
          const SizedBox(width: 8),
          chip(Icons.warning_amber_rounded, AppColors.danger,
              '${_store.threatSpots}', 'pest / weed spots'),
          const SizedBox(width: 8),
          chip(Icons.hourglass_top, AppColors.warning, '$pending', 'to validate'),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(int i, IconData icon, String label) {
      final bool on = _tab == i;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _tab = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? AppColors.green : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: on ? Colors.white : AppColors.muted),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          tab(0, Icons.map_outlined, 'Map'),
          tab(1, Icons.grid_view_rounded, 'Records'),
          tab(2, Icons.insights_outlined, 'Summary'),
        ],
      ),
    );
  }

  // ---- Map tab ----

  Widget _mapTab() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: _bounds,
                padding: const EdgeInsets.all(28),
              ),
              minZoom: 3,
              maxZoom: 21,
              backgroundColor: const Color(0xFFE6EFD8),
              onTap: (_, p) => _onMapTap(p),
            ),
            children: [
              if (_satellite)
                TileLayer(
                  urlTemplate: _satelliteUrl,
                  userAgentPackageName: 'lk.cococonnect.mobile',
                  maxNativeZoom: 18,
                ),
              // The grid, laid over the land and cut off at its edge.
              PolylineLayer(polylines: _gridLines),
              PolygonLayer(
                polygons: [
                  Polygon(
                    points: _boundary,
                    color: AppColors.green.withValues(alpha: 0.10),
                    borderColor: _satellite ? Colors.white : AppColors.green,
                    borderStrokeWidth: 3,
                  ),
                ],
              ),
              if (_drawing && _draft.isNotEmpty) ...[
                if (_draft.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _draft,
                        color: const Color(0x33FFC107),
                        borderColor: const Color(0xFFFFC107),
                        borderStrokeWidth: 3,
                      ),
                    ],
                  )
                else
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _draft,
                        color: const Color(0xFFFFC107),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    for (var i = 0; i < _draft.length; i++)
                      Marker(
                        point: _draft[i],
                        width: 26,
                        height: 26,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC107),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              Builder(
                builder: (context) {
                  final double px = treePixels(MapCamera.of(context));
                  return MarkerLayer(
                    markers: [
                      for (final m in _store.marks)
                        Marker(
                          point: LatLng(m.lat, m.lng),
                          width: px + 12,
                          height: px + 12,
                          child: IgnorePointer(
                            // While adding many, taps place new ones instead.
                            ignoring: _brush != null,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _quickActions(m),
                              child: Center(
                                child: PlantBadge(
                                  kind: m.info,
                                  size: px,
                                  count: m.count,
                                  shadow: true,
                                  flag: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (_satellite)
                const Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      'Imagery: Esri, Maxar',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 3)],
                      ),
                    ),
                  ),
                )
              else
                const KapConnectMapAttribution(),
            ],
          ),
        ),
        Positioned(
          left: 10,
          top: 10,
          right: 70,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined,
                      size: 18, color: AppColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _brush != null
                          ? 'Adding ${_brush!.info.name.toLowerCase()}. One tap places one plant.'
                          : _drawing
                          ? 'Tap each corner of your land in order. '
                              '${_draft.length} corners'
                              '${_draft.length >= 3 ? ' · ${EstateGeometry.areaAcres(_draft).toStringAsFixed(1)} acres' : ''}'
                          : _store.marks.isEmpty
                              ? 'Tap the map to place one tree, pest or weed.'
                              : 'Tap an empty spot to add one. Tap a plant to change it.',
                      style: const TextStyle(fontSize: 11.5, height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_brush != null)
          Positioned(
            left: 10,
            top: 58,
            child: Material(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(99),
              elevation: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => setState(() => _brush = null),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PlantBadge(kind: _brush!.info, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        '${_store.marks.length} marked · Done',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (!_drawing && _brush == null)
          Positioned(
            left: 10,
            top: 58,
            child: Material(
              color: _plan.hasShape ? Colors.white : AppColors.green,
              borderRadius: BorderRadius.circular(99),
              elevation: 3,
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: _startDrawing,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.polyline,
                        size: 16,
                        color: _plan.hasShape ? AppColors.green : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _plan.hasShape
                            ? 'Redraw estate shape'
                            : 'Draw your real estate shape',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color:
                              _plan.hasShape ? AppColors.green : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          right: 10,
          top: 10,
          child: Column(
            children: [
              _roundButton(
                _satellite ? Icons.grid_on : Icons.satellite_alt,
                _satellite ? 'Plan view' : 'Satellite view',
                () => setState(() => _satellite = !_satellite),
              ),
              const SizedBox(height: 8),
              _roundButton(Icons.center_focus_strong, 'Show whole estate', _fit),
              if (_plan.hasShape && !_drawing) ...[
                const SizedBox(height: 8),
                _roundButton(
                  Icons.crop_square,
                  'Draw as a square again',
                  _backToSquare,
                ),
              ],
            ],
          ),
        ),
        if (_drawing)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: _stopDrawing,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _draft.isEmpty
                      ? null
                      : () => setState(() => _draft.removeLast()),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Undo'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _draft.length >= 3 ? _saveShape : null,
                    child: const Text('Save estate shape'),
                  ),
                ),
              ],
            ),
          )
        else
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: ElevatedButton.icon(
            onPressed: _locating ? null : _addHere,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: const Text('I am standing here: add a mark'),
          ),
        ),
      ],
    );
  }

  Widget _roundButton(IconData icon, String tip, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.green, size: 20),
      ),
    );
  }

  // ---- Records tab ----

  Widget _recordsTab() {
    final list = _filtered;
    Widget chip(String label, PlantGroup? g) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == g,
        onSelected: (_) => setState(() => _filter = g),
      ),
    );
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              chip('All (${_store.marks.length})', null),
              chip('Trees and crops', PlantGroup.crop),
              chip('Invasive plants', PlantGroup.invasive),
              chip('Pests', PlantGroup.pest),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? _empty()
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 176,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _recordCard(list[i]),
                ),
        ),
      ],
    );
  }

  Widget _empty() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_location_alt_outlined,
              size: 44, color: AppColors.greenMid),
          const SizedBox(height: 10),
          const Text(
            'Nothing marked yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Marks you add on the map appear here as cards you can change or '
            'remove.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => setState(() => _tab = 0),
            child: const Text('Open the map'),
          ),
        ],
      ),
    ),
  );

  Widget _recordCard(PlantMark m) {
    final PlantKind k = m.info;
    final String detail = m.age != null
        ? '${m.age} yrs · ${ageRange(m.age!).stage}'
        : '${m.severity ?? ''} severity';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(LatLng(m.lat, m.lng), existing: m),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlantBadge(kind: k, size: 36),
                  const Spacer(),
                  Text(
                    '${m.count}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: k.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                k.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: m.severity == null
                      ? AppColors.muted
                      : severityColor(m.severity!),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              MarkStatusPill(m.status),
              const Spacer(),
              Row(
                children: [
                  Text(
                    shortDay(m.updated),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _open(LatLng(m.lat, m.lng), existing: m),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined,
                          size: 18, color: AppColors.green),
                    ),
                  ),
                  InkWell(
                    onTap: () => _confirmDelete(m),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 18, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(PlantMark m) async {
    final bool? yes = await showThemedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this mark?'),
        content: Text('${m.count} × ${m.info.name} will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await _store.remove(m.id);
      if (mounted) _toast('Mark removed');
    }
  }

  // ---- Summary tab ----

  Widget _summaryTab() {
    final crops = kPlantKinds.where((k) => k.isCrop && _store.countOf(k.id) > 0);
    final threats = _store.marks.where((m) => m.info.isThreat).toList()
      ..sort(
        (a, b) => kSeverities
            .indexOf(b.severity ?? 'Low')
            .compareTo(kSeverities.indexOf(a.severity ?? 'Low')),
      );
    final int topCount = crops.fold(
      1,
      (t, k) => math.max(t, _store.countOf(k.id)),
    );
    final Map<String, int> ages = _store.ageSpread();
    final int topAge = ages.values.fold(1, math.max);

    Widget title(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(t,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.infoSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.dashboard_outlined, color: AppColors.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'This is the summary your CDO and the admin dashboard will '
                  'see: cultivation, tree ages and threats on your estate.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
        ),
        title('What grows on your estate'),
        if (crops.isEmpty)
          const Text('No trees marked yet.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        for (final k in crops)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                PlantBadge(kind: k, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k.name,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _store.countOf(k.id) / topCount,
                          minHeight: 8,
                          color: k.color,
                          backgroundColor: AppColors.line,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text('${_store.countOf(k.id)}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        title('How old the trees are'),
        SizedBox(
          height: 132,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final a in kAgeRanges)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${ages[a.id]}',
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 6 + 74 * (ages[a.id]! / topAge),
                          decoration: BoxDecoration(
                            color: AppColors.greenMid,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(a.id,
                            style: const TextStyle(
                                fontSize: 9.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        title('Pests and invasive plants'),
        if (threats.isEmpty)
          const Text('None marked. Good news.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        for (final m in threats)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: severityColor(m.severity ?? 'Low').withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                PlantBadge(kind: m.info, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.info.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      Text(
                        m.note.isEmpty ? m.info.note : m.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                StatusPill(
                  m.severity ?? 'Low',
                  fg: severityColor(m.severity ?? 'Low'),
                  bg: severityColor(m.severity ?? 'Low').withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

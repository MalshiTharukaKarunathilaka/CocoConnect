

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/estate_geometry.dart';
import '../../models/estate_plants.dart';
import '../../theme/app_theme.dart';
import 'estate_map_page.dart';
import 'plant_widgets.dart';

const String _satelliteUrl =
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/'
    'MapServer/tile/{z}/{y}/{x}';

/// A read-only picture of the estate with everything the owner marked on it.
/// Used on the profile page and on the last set-up step. It does not move or
/// take taps on the map itself; [onTap] (when given) opens the editable map.
class EstateMapPreview extends StatefulWidget {
  final double height;
  final VoidCallback? onTap;

  /// Load the owner's saved estate first. Off when the caller already did.
  final bool load;

  const EstateMapPreview({
    super.key,
    this.height = 230,
    this.onTap,
    this.load = true,
  });

  @override
  State<EstateMapPreview> createState() => _EstateMapPreviewState();
}

class _EstateMapPreviewState extends State<EstateMapPreview> {
  final EstateMapStore _store = EstateMapStore.instance;
  late final Future<void> _ready = widget.load
      ? ensureEstatePlan()
      : Future<void>.value();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(
            height: widget.height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return ListenableBuilder(
          listenable: _store,
          builder: (context, _) => _store.ready ? _content() : _empty(),
        );
      },
    );
  }

  Widget _empty() => InkWell(
    onTap: widget.onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: widget.height * 0.6,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Your estate map is not drawn yet. Tap to start.',
        style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _content() {
    final EstatePlan plan = _store.plan!;
    // The real shape if the owner drew it, otherwise a square of the right area.
    final EstateGeometry geo = EstateGeometry(plan);
    final bounds = geo.bounds;
    final List<Polyline> grid = [
      for (final l in geo.gridLines())
        Polyline(points: l, color: const Color(0x66FFFFFF), strokeWidth: 1),
    ];

    // The kinds that are on the map, biggest first, for the key under it.
    final kinds = [
      for (final k in kPlantKinds)
        if (_store.countOf(k.id) > 0 || _store.marks.any((m) => m.kind == k.id))
          k,
    ]..sort((a, b) => _store.countOf(b.id).compareTo(_store.countOf(a.id)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: widget.height,
              child: Stack(
                children: [
                  FlutterMap(
                    // A new key when the estate changes, so the picture refits.
                    key: ValueKey(
                      '${plan.lat}|${plan.lng}|${plan.acres}|${plan.boundary?.length}|${_store.marks.length}',
                    ),
                    options: MapOptions(
                      initialCameraFit: CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(22),
                      ),
                      maxZoom: 21,
                      backgroundColor: const Color(0xFFE6EFD8),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _satelliteUrl,
                        userAgentPackageName: 'lk.cococonnect.mobile',
                        maxNativeZoom: 18,
                      ),
                      PolylineLayer(polylines: grid),
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: geo.outline,
                            color: AppColors.green.withValues(alpha: 0.10),
                            borderColor: Colors.white,
                            borderStrokeWidth: 3,
                          ),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final double px = treePixels(MapCamera.of(context));
                          return MarkerLayer(
                            markers: [
                              for (final m in _store.marks)
                                Marker(
                                  point: LatLng(m.lat, m.lng),
                                  width: px + 8,
                                  height: px + 8,
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
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${plan.name} · '
                        '${plan.acres.toStringAsFixed(plan.acres % 1 == 0 ? 0 : 1)} acres',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (_store.marks.isEmpty)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 12,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xE6FFFFFF),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              'Nothing marked yet',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    bottom: 4,
                    child: Text(
                      'Grid: each square ${geo.gridMetres.toStringAsFixed(0)} m',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 3)],
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 6,
                    bottom: 4,
                    child: Text(
                      'Imagery: Esri, Maxar',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 3)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (kinds.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final k in kinds)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PlantBadge(kind: k, size: 22),
                    const SizedBox(width: 5),
                    Text(
                      '${_store.countOf(k.id)} ${k.name.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }
}

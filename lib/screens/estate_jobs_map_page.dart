import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/worker_service.dart';

class EstateJobsMapPage extends StatelessWidget {
  final List<WorkerJob> jobs;
  final int radiusKm;
  final bool nearbyOnly;

  const EstateJobsMapPage({super.key, required this.jobs, this.radiusKm = 20, this.nearbyOnly = false});

  @override
  Widget build(BuildContext context) {
    final mappedEstates = _mappedEstates();
    // Start zoomed out enough to show Jaffna and the southern estates together.
    const center = LatLng(7.5, 80.7);

    return FutureBuilder<List<WorkerEstate>>(
      future: nearbyOnly ? WorkerService.getNearbyEstates(radiusKm: radiusKm) : WorkerService.getEstates(),
      builder: (context, estateSnapshot) {
        final estates = estateSnapshot.data ?? const <WorkerEstate>[];
        return Scaffold(
      appBar: AppBar(title: Text(nearbyOnly ? 'Reachable Estates (20 km)' : 'All Estates')),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 7),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.kapconnect_mobile',
          ),
          MarkerLayer(
            markers: [
              for (final estate in estates)
                if (_pointForEstate(estate) != null)
                  Marker(
                    point: _pointForEstate(estate)!,
                    width: 190,
                    height: 70,
                    child: GestureDetector(
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => ListTile(
                          leading: const Icon(Icons.park),
                          title: Text(estate.estateName),
                          subtitle: Text(estate.location),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                            child: Text(estate.estateName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          const Icon(Icons.park, color: Color(0xFF256B45), size: 34),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('OpenStreetMap contributors')],
          ),
        ],
      ),
        );
      },
    );
  }

  List<_MappedEstate> _mappedEstates() {
    final byEstate = <String, WorkerJob>{};
    for (final job in jobs) {
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

import 'package:latlong2/latlong.dart';

import '../services/worker_service.dart';

LatLng? workerJobMapPoint(WorkerJob job) {
  if (job.latitude != null && job.longitude != null) {
    return LatLng(job.latitude!, job.longitude!);
  }
  return _knownLocationPoint(
    '${job.estateName} ${job.estateLocation} ${job.location}',
  );
}

LatLng? workerEstateMapPoint(WorkerEstate estate) {
  if (estate.latitude != null && estate.longitude != null) {
    return LatLng(estate.latitude!, estate.longitude!);
  }
  return _knownLocationPoint('${estate.estateName} ${estate.location}');
}

LatLng? _knownLocationPoint(String value) {
  final place = value.toLowerCase();
  if (place.contains('jaffna')) return const LatLng(9.6615, 80.0255);
  if (place.contains('walasmulla')) return const LatLng(6.1447, 80.6851);
  if (place.contains('middeniya')) return const LatLng(6.2730, 80.7670);
  if (place.contains('hambantota')) return const LatLng(6.1241, 81.1185);
  return null;
}

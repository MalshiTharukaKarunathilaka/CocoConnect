import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

const _openStreetMapUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

/// Shared, policy-compliant OpenStreetMap tile configuration for KapConnect.
TileLayer kapConnectMapTiles({Key? key, ErrorTileCallBack? onTileError}) {
  return TileLayer(
    key: key,
    urlTemplate: _openStreetMapUrl,
    userAgentPackageName: 'lk.cococonnect.mobile',
    maxNativeZoom: 19,
    panBuffer: 1,
    keepBuffer: 2,
    evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
    errorTileCallback: onTileError,
  );
}

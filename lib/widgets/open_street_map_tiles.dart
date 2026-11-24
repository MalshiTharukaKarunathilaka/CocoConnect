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

class KapConnectMapAttribution extends StatelessWidget {
  const KapConnectMapAttribution({super.key});
  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.bottomRight,
    child: Padding(
      padding: EdgeInsets.all(3),
      child: ColoredBox(
        color: Color(0xDDFFFFFF),
        child: Padding(
          padding: EdgeInsets.all(3),
          child: Text(
            '? OpenStreetMap contributors',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 9, color: Color(0xFF222222)),
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';

/// What a mark on the estate map is: something planted, an invasive plant, or
/// a pest. The admin dashboard's cultivation pages read the same three groups.
enum PlantGroup { crop, invasive, pest }

class PlantKind {
  final String id;
  final String name;
  final String note;
  final PlantGroup group;
  final Color color;

  /// A picture with a see-through background, in assets/plants/.
  final String asset;

  const PlantKind(
    this.id,
    this.name,
    this.note,
    this.group,
    this.color,
    this.asset,
  );

  bool get isCrop => group == PlantGroup.crop;
  bool get isThreat => group != PlantGroup.crop;
}

const List<PlantKind> kPlantKinds = [
  // Planted: the owner gives a count and an age range.
  PlantKind('coconut', 'Coconut tree', 'Tall coconut', PlantGroup.crop,
      Color(0xFF2F8A4F), 'assets/plants/coconut.png'),
  PlantKind('king', 'King coconut', 'Orange thambili', PlantGroup.crop,
      Color(0xFFD99A0B), 'assets/plants/king.png'),
  PlantKind('pepper', 'Pepper', 'Climbs the coconut trees', PlantGroup.crop,
      Color(0xFF9C2A23), 'assets/plants/pepper.png'),
  PlantKind('banana', 'Banana', 'Intercrop', PlantGroup.crop,
      Color(0xFFC9A800), 'assets/plants/banana.png'),
  PlantKind('cinnamon', 'Cinnamon', 'Spice tree', PlantGroup.crop,
      Color(0xFF8B5A2B), 'assets/plants/cinnamon.png'),
  PlantKind('cocoa', 'Cocoa', 'Shade-loving', PlantGroup.crop,
      Color(0xFFD2691E), 'assets/plants/cocoa.png'),
  // Invasive plants: the owner says how bad it is.
  PlantKind('guinea', 'Guinea grass', 'Spreads fast under coconut trees',
      PlantGroup.invasive, Color(0xFF6B8E23), 'assets/plants/guinea.png'),
  PlantKind('mana', 'Mana grass', 'Takes over open ground',
      PlantGroup.invasive, Color(0xFF7D9A1F), 'assets/plants/mana.png'),
  // Pests.
  PlantKind('mite', 'Coconut mite', 'Scars and shrinks the nuts',
      PlantGroup.pest, Color(0xFFB08A3E), 'assets/plants/mite.png'),
  PlantKind('whitefly', 'Whitefly', 'White coating on the fronds',
      PlantGroup.pest, Color(0xFFC9A100), 'assets/plants/whitefly.png'),
];

PlantKind plantKind(String id) => kPlantKinds.firstWhere(
  (k) => k.id == id,
  orElse: () => kPlantKinds.first,
);

String groupTitle(PlantGroup g) => switch (g) {
  PlantGroup.crop => 'Trees and crops',
  PlantGroup.invasive => 'Invasive plants',
  PlantGroup.pest => 'Pests',
};

/// The same seven age bands as the admin dashboard's tree-age chart.
class AgeRange {
  final String id;
  final String stage;
  final String note;

  const AgeRange(this.id, this.stage, this.note);
}

const List<AgeRange> kAgeRanges = [
  AgeRange('0-5', 'Seedling', 'just planted'),
  AgeRange('6-15', 'Young tree', 'growing up'),
  AgeRange('16-25', 'Early bearing', 'first nuts'),
  AgeRange('26-40', 'Prime bearing', 'best yields'),
  AgeRange('41-50', 'Mature', 'full height'),
  AgeRange('51-60', 'Aged', 'yields falling'),
  AgeRange('61+', 'Old tree', 'due for replanting'),
];

AgeRange ageRange(String id) =>
    kAgeRanges.firstWhere((a) => a.id == id, orElse: () => kAgeRanges.first);

const List<String> kSeverities = ['Low', 'Medium', 'High'];

Color severityColor(String s) => switch (s) {
  'High' => const Color(0xFFC62828),
  'Medium' => const Color(0xFFE08A1E),
  _ => const Color(0xFF6B8E23),
};

/// Every mark waits for the CDO to check it. Until that part is built the app
/// only says so.
const String kPendingValidation = 'Pending validation';

/// One spot on the estate map. [count] is how many plants it stands for, so a
/// row of 40 coconut trees is one mark.
class PlantMark {
  final String id;
  final String kind;
  final double lat;
  final double lng;
  final int count;
  final String? age; // crops only: an id from [kAgeRanges]
  final String? severity; // invasive plants and pests only
  final String note;
  final DateTime updated;
  final String status;

  const PlantMark({
    required this.id,
    required this.kind,
    required this.lat,
    required this.lng,
    required this.count,
    required this.updated,
    this.age,
    this.severity,
    this.note = '',
    this.status = kPendingValidation,
  });

  PlantKind get info => plantKind(kind);

  PlantMark copyWith({
    String? kind,
    double? lat,
    double? lng,
    int? count,
    String? age,
    String? severity,
    String? note,
    String? status,
  }) => PlantMark(
    id: id,
    kind: kind ?? this.kind,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    count: count ?? this.count,
    age: age,
    severity: severity,
    note: note ?? this.note,
    updated: DateTime.now(),
    status: status ?? kPendingValidation,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'lat': lat,
    'lng': lng,
    'count': count,
    'age': age,
    'severity': severity,
    'note': note,
    'updated': updated.toIso8601String(),
    'status': status,
  };

  factory PlantMark.fromJson(Map<String, dynamic> j) => PlantMark(
    id: '${j['id']}',
    kind: '${j['kind']}',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    count: (j['count'] as num?)?.toInt() ?? 1,
    age: j['age'] as String?,
    severity: j['severity'] as String?,
    note: '${j['note'] ?? ''}',
    updated: DateTime.tryParse('${j['updated']}') ?? DateTime.now(),
    status: '${j['status'] ?? kPendingValidation}',
  );
}

/// The estate being mapped: its name, size and middle point. [boundary] is the
/// real shape of the land, drawn by the owner corner by corner; until it is
/// drawn the estate is shown as a square with the estate's area.
class EstatePlan {
  final String name;
  final double acres;
  final double lat;
  final double lng;
  final String place;
  final List<LatLng>? boundary;

  const EstatePlan({
    required this.name,
    required this.acres,
    required this.lat,
    required this.lng,
    this.place = '',
    this.boundary,
  });

  bool get hasShape => boundary != null && boundary!.length >= 3;

  /// Pulls the number out of text such as "25 acres".
  static double acresFrom(String text, {double fallback = 5}) {
    final m = RegExp(r'\d+(\.\d+)?').firstMatch(text);
    final v = m == null ? null : double.tryParse(m.group(0)!);
    return (v == null || v <= 0) ? fallback : v.clamp(0.25, 2000.0).toDouble();
  }

  /// Half the side of the square that has the estate's area, in metres.
  double get halfSideMetres => math.sqrt(acres * 4046.86) / 2;

  /// The same estate with its real shape. The middle point and the size
  /// follow the shape.
  EstatePlan withShape(List<LatLng> points, double measuredAcres) {
    final double cLat =
        points.fold(0.0, (t, p) => t + p.latitude) / points.length;
    final double cLng =
        points.fold(0.0, (t, p) => t + p.longitude) / points.length;
    return EstatePlan(
      name: name,
      acres: measuredAcres,
      lat: cLat,
      lng: cLng,
      place: place,
      boundary: List<LatLng>.unmodifiable(points),
    );
  }

  /// The same estate drawn as a square again.
  EstatePlan withoutShape() =>
      EstatePlan(name: name, acres: acres, lat: lat, lng: lng, place: place);

  Map<String, dynamic> toJson() => {
    'name': name,
    'acres': acres,
    'lat': lat,
    'lng': lng,
    'place': place,
    if (hasShape)
      'boundary': [
        for (final p in boundary!) [p.latitude, p.longitude],
      ],
  };

  factory EstatePlan.fromJson(Map<String, dynamic> j) => EstatePlan(
    name: '${j['name'] ?? ''}',
    acres: (j['acres'] as num?)?.toDouble() ?? 5,
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    place: '${j['place'] ?? ''}',
    boundary: (j['boundary'] as List?)
        ?.map(
          (e) => LatLng(
            ((e as List)[0] as num).toDouble(),
            (e[1] as num).toDouble(),
          ),
        )
        .toList(),
  );
}

/// The estate map's records. They are kept on the phone and saved to the
/// server (GET and PUT /api/owner/estate-map), so the map follows the account
/// to any device. Each login has its own copy. With no network the app keeps
/// working from the phone's copy and sends it when it can.
class EstateMapStore extends ChangeNotifier {
  EstateMapStore._();
  static final EstateMapStore instance = EstateMapStore._();

  String _key = '';
  EstatePlan? plan;
  final List<PlantMark> marks = [];

  /// Changes the server has not received yet.
  bool _dirty = false;
  Future<void> _queue = Future<void>.value();

  bool get ready => plan != null;

  /// Opens one login's map: the phone's copy first, then the server's copy.
  /// Pass [sync] false to stay on the phone (used by tests).
  Future<void> load(String userKey, {bool sync = true}) async {
    _key = userKey;
    plan = null;
    marks.clear();
    _dirty = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('estate_map_v1_$_key');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _dirty = data['dirty'] == true;
        if (data['plan'] != null) {
          plan = EstatePlan.fromJson(data['plan'] as Map<String, dynamic>);
        }
        _addMarks(data['marks'] as List? ?? const []);
      }
    } catch (_) {
      // A damaged record starts the map empty instead of crashing.
    }
    notifyListeners();
    if (sync) await _sync();
  }

  void _addMarks(List raw) {
    for (final m in raw) {
      try {
        final mark = PlantMark.fromJson(m as Map<String, dynamic>);
        if (kPlantKinds.any((k) => k.id == mark.kind)) marks.add(mark);
      } catch (_) {
        // Skip a mark that cannot be read.
      }
    }
  }

  /// Brings the phone and the server together. A change the server has not
  /// received yet wins; otherwise the server's copy is the one that follows
  /// the account. An empty server gets the phone's copy.
  Future<void> _sync() async {
    final String keyAtStart = _key;
    try {
      if (_dirty) {
        await _push();
        return;
      }
      final data = await ApiClient.get('/api/owner/estate-map');
      if (keyAtStart != _key || data is! Map<String, dynamic>) return;
      final remotePlan = data['plan'];
      final remoteMarks = data['marks'] as List? ?? const [];
      if (remotePlan == null && remoteMarks.isEmpty) {
        if (plan != null || marks.isNotEmpty) await _push();
        return;
      }
      plan = remotePlan == null
          ? null
          : EstatePlan.fromJson(remotePlan as Map<String, dynamic>);
      marks.clear();
      _addMarks(remoteMarks);
      await _saveLocal();
      notifyListeners();
    } catch (_) {
      // Offline, or not signed in: the phone's copy is used as it is.
    }
  }

  Map<String, dynamic> _document() => {
    'plan': plan?.toJson(),
    'marks': [for (final m in marks) m.toJson()],
  };

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'estate_map_v1_$_key',
        jsonEncode({..._document(), 'dirty': _dirty}),
      );
    } catch (_) {
      // Storage can be unavailable (private window); the map still works.
    }
  }

  /// Sends the whole map to the server, one send at a time and in order.
  Future<void> _push() {
    _queue = _queue.then((_) async {
      try {
        await ApiClient.put('/api/owner/estate-map', _document());
        _dirty = false;
      } catch (_) {
        _dirty = true; // tried again the next time the map is opened
      }
      await _saveLocal();
    });
    return _queue;
  }

  /// Keeps the change on the phone straight away and sends it to the server
  /// without making the screen wait.
  Future<void> _save() async {
    _dirty = true;
    await _saveLocal();
    unawaited(_push());
  }

  Future<void> setPlan(EstatePlan p) async {
    plan = p;
    notifyListeners();
    await _save();
  }

  Future<void> add(PlantMark m) async {
    marks.add(m);
    notifyListeners();
    await _save();
  }

  Future<void> update(PlantMark m) async {
    final i = marks.indexWhere((x) => x.id == m.id);
    if (i < 0) return;
    marks[i] = m;
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    marks.removeWhere((m) => m.id == id);
    notifyListeners();
    await _save();
  }

  String newId() => 'M${DateTime.now().microsecondsSinceEpoch}';

  // ---- Summary figures, the same ones the admin dashboard will show ----

  int countOf(String kindId) => marks
      .where((m) => m.kind == kindId)
      .fold(0, (s, m) => s + m.count);

  int get totalTrees => marks
      .where((m) => m.info.isCrop)
      .fold(0, (s, m) => s + m.count);

  int get threatSpots => marks.where((m) => m.info.isThreat).length;

  /// Plants per age range, for the crops that have one.
  Map<String, int> ageSpread() {
    final out = {for (final a in kAgeRanges) a.id: 0};
    for (final m in marks) {
      if (m.info.isCrop && m.age != null && out.containsKey(m.age)) {
        out[m.age!] = out[m.age!]! + m.count;
      }
    }
    return out;
  }
}

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kapconnect_mobile/models/estate_geometry.dart';
import 'package:latlong2/latlong.dart';
import 'package:kapconnect_mobile/models/estate_plants.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  PlantMark mark(String id, String kind, int count, {String? age, String? sev}) =>
      PlantMark(
        id: id,
        kind: kind,
        lat: 7.5,
        lng: 80.3,
        count: count,
        age: age,
        severity: sev,
        updated: DateTime(2026, 11, 25),
      );

  test('acres are read from the text the owner typed', () {
    expect(EstatePlan.acresFrom('5 acres'), 5);
    expect(EstatePlan.acresFrom('12.5 ac'), 12.5);
    expect(EstatePlan.acresFrom('', fallback: 0), 0);
  });

  test('an irregular shape: area, which points are on the land, and the grid', () {
    // An L-shaped estate about 100 m by 100 m with a 50 m by 50 m corner cut out.
    const lat0 = 7.5, lng0 = 80.3;
    const mLat = 111320.0;
    final mLng = 111320.0 * math.cos(lat0 * math.pi / 180);
    LatLng at(double e, double n) => LatLng(lat0 + n / mLat, lng0 + e / mLng);
    final corners = [
      at(0, 0), at(100, 0), at(100, 50), at(50, 50), at(50, 100), at(0, 100),
    ];
    final plan = const EstatePlan(name: 'L', acres: 1, lat: lat0, lng: lng0)
        .withShape(corners, EstateGeometry.areaAcres(corners));
    // 7,500 square metres is about 1.85 acres.
    expect(plan.acres, closeTo(1.85, 0.02));
    expect(plan.hasShape, isTrue);

    final geo = EstateGeometry(plan);
    expect(geo.contains(at(20, 20), slack: 1.0), isTrue); // on the land
    expect(geo.contains(at(80, 80), slack: 1.0), isFalse); // in the cut-out corner
    expect(geo.contains(at(400, 400), slack: 1.0), isFalse); // far away

    // Every grid line lies on the land: none runs through the cut-out corner.
    final lines = geo.gridLines();
    expect(lines, isNotEmpty);
    for (final l in lines) {
      final mid = LatLng(
        (l.first.latitude + l.last.latitude) / 2,
        (l.first.longitude + l.last.longitude) / 2,
      );
      expect(geo.contains(mid, slack: 1.0), isTrue);
    }

    // The shape survives being saved and read back.
    final back = EstatePlan.fromJson(plan.toJson());
    expect(back.boundary!.length, 6);
    expect(back.withoutShape().hasShape, isFalse);
  });

  test('marks can be added, changed, deleted and are kept per login', () async {
    final store = EstateMapStore.instance;
    await store.load('u1', sync: false);
    await store.setPlan(
      const EstatePlan(name: 'Green Valley', acres: 5, lat: 7.5, lng: 80.3),
    );
    await store.add(mark('a', 'coconut', 40, age: '41-50'));
    await store.add(mark('b', 'mite', 3, sev: 'High'));
    expect(store.totalTrees, 40);
    expect(store.threatSpots, 1);
    expect(store.ageSpread()['41-50'], 40);

    final changed = store.marks.first.copyWith(count: 55, age: '26-40');
    await store.update(changed);
    expect(store.countOf('coconut'), 55);
    expect(store.ageSpread()['26-40'], 55);
    expect(store.marks.first.status, kPendingValidation);

    // A second login sees nothing; the first login still has its marks.
    await store.load('u2', sync: false);
    expect(store.marks, isEmpty);
    await store.load('u1', sync: false);
    expect(store.marks.length, 2);
    expect(store.plan?.name, 'Green Valley');

    await store.remove('b');
    expect(store.threatSpots, 0);
  });
}

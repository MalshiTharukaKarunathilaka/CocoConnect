import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'estate_plants.dart';

/// The shape of an estate on the map: its outline (the owner's drawn boundary,
/// or a square of the right area until then), a grid laid over it, and
/// whether a point is on the land. Works in metres around the estate's middle
/// so the grid squares are really the same size on the ground.
class EstateGeometry {
  final EstatePlan plan;

  EstateGeometry(this.plan);

  static const double _mPerDegLat = 111320;
  double get _mPerDegLng => _mPerDegLat * math.cos(plan.lat * math.pi / 180);

  /// The corners of the land, in order.
  List<LatLng> get outline {
    if (plan.hasShape) return plan.boundary!;
    final double dLat = plan.halfSideMetres / _mPerDegLat;
    final double dLng = plan.halfSideMetres / _mPerDegLng;
    return [
      LatLng(plan.lat - dLat, plan.lng - dLng),
      LatLng(plan.lat - dLat, plan.lng + dLng),
      LatLng(plan.lat + dLat, plan.lng + dLng),
      LatLng(plan.lat + dLat, plan.lng - dLng),
    ];
  }

  LatLngBounds get bounds => LatLngBounds.fromPoints(outline);

  // ---- local metres: x to the east, y to the north, from the middle ----

  ({double x, double y}) _local(LatLng p) => (
    x: (p.longitude - plan.lng) * _mPerDegLng,
    y: (p.latitude - plan.lat) * _mPerDegLat,
  );

  LatLng _back(double x, double y) =>
      LatLng(plan.lat + y / _mPerDegLat, plan.lng + x / _mPerDegLng);

  /// Area of a drawn shape in acres.
  static double areaAcres(List<LatLng> points) {
    if (points.length < 3) return 0;
    final double lat0 =
        points.fold(0.0, (t, p) => t + p.latitude) / points.length;
    final double lng0 =
        points.fold(0.0, (t, p) => t + p.longitude) / points.length;
    final double mLng = _mPerDegLat * math.cos(lat0 * math.pi / 180);
    double twice = 0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final double ax = (a.longitude - lng0) * mLng;
      final double ay = (a.latitude - lat0) * _mPerDegLat;
      final double bx = (b.longitude - lng0) * mLng;
      final double by = (b.latitude - lat0) * _mPerDegLat;
      twice += ax * by - bx * ay;
    }
    return twice.abs() / 2 / 4046.86;
  }

  /// True when [p] is on the land. [slack] widens the land a little so a mark
  /// right on the edge still counts.
  bool contains(LatLng p, {double slack = 1.12}) {
    final pts = [
      for (final c in outline)
        (
          x: _local(c).x * slack,
          y: _local(c).y * slack,
        ),
    ];
    final q = _local(p);
    var inside = false;
    for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      final a = pts[i];
      final b = pts[j];
      final bool crosses = (a.y > q.y) != (b.y > q.y) &&
          q.x < (b.x - a.x) * (q.y - a.y) / (b.y - a.y) + a.x;
      if (crosses) inside = !inside;
    }
    return inside;
  }

  /// Side of one grid square in metres: a round number that gives about
  /// eight to ten squares across the land.
  double get gridMetres {
    final b = bounds;
    final double w =
        (b.east - b.west).abs() * _mPerDegLng;
    final double h = (b.north - b.south).abs() * _mPerDegLat;
    final double want = math.max(w, h) / 9;
    for (final double step in [5, 10, 20, 25, 50, 100, 200, 250, 500, 1000]) {
      if (step >= want) return step;
    }
    return 1000;
  }

  /// Grid lines, cut off at the edge of the land so an irregular shape gets
  /// a grid that follows its outline.
  List<List<LatLng>> gridLines() {
    final double g = gridMetres;
    final pts = [for (final c in outline) _local(c)];
    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;
    for (final p in pts) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }

    final lines = <List<LatLng>>[];

    // Where a line at [c] (a y, or an x when [vertical]) is inside the shape.
    void sweep(double c, bool vertical) {
      final cuts = <double>[];
      for (var i = 0; i < pts.length; i++) {
        final a = pts[i];
        final b = pts[(i + 1) % pts.length];
        final double a1 = vertical ? a.x : a.y;
        final double b1 = vertical ? b.x : b.y;
        if ((a1 <= c && b1 > c) || (b1 <= c && a1 > c)) {
          final double t = (c - a1) / (b1 - a1);
          cuts.add(
            vertical ? a.y + t * (b.y - a.y) : a.x + t * (b.x - a.x),
          );
        }
      }
      cuts.sort();
      for (var i = 0; i + 1 < cuts.length; i += 2) {
        lines.add(
          vertical
              ? [_back(c, cuts[i]), _back(c, cuts[i + 1])]
              : [_back(cuts[i], c), _back(cuts[i + 1], c)],
        );
      }
    }

    for (double y = (minY / g).ceil() * g; y < maxY; y += g) {
      sweep(y, false);
    }
    for (double x = (minX / g).ceil() * g; x < maxX; x += g) {
      sweep(x, true);
    }
    return lines;
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapCamera;

import '../../models/estate_plants.dart';
import '../../theme/app_theme.dart';

/// The picture of one kind of plant, pest or weed: just the artwork, with no
/// circle or coloured background. On the map [shadow] lifts it off the
/// satellite image, and [flag] adds a small red "!" to pests and weeds.
class PlantBadge extends StatelessWidget {
  final PlantKind kind;
  final double size;
  final int? count;
  final bool shadow;
  final bool flag;

  const PlantBadge({
    super.key,
    required this.kind,
    this.size = 40,
    this.count,
    this.shadow = false,
    this.flag = false,
  });

  @override
  Widget build(BuildContext context) {
    final Image raw = Image.asset(
      kind.asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: kind.name,
    );
    // The coconut tree is a tall, narrow picture, so it is drawn a little bigger to look
    // as large as the others.
    final Widget picture = kind.id == 'coconut'
        ? Transform.scale(scale: 1.5, child: raw)
        : raw;
    return RepaintBoundary(
      child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (shadow)
            // A soft oval on the ground under the plant. It is cheap to draw, unlike a
            // blurred copy of the picture, which is slow with many plants on the map.
            Positioned(
              left: size * 0.18,
              right: size * 0.18,
              bottom: size * 0.02,
              height: size * 0.2,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.all(Radius.elliptical(40, 20)),
                  color: Color(0x40000000),
                ),
              ),
            ),
          Positioned.fill(child: picture),
          if (flag && kind.isThreat)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: size * 0.34,
                height: size * 0.34,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.24,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          if (count != null && count! > 1)
            Positioned(
              bottom: -5,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: kind.color, width: 1.2),
                ),
                child: Text(
                  count! > 9999 ? '9999+' : '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: kind.color,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

/// A small pill such as "Pending validation".
class MarkStatusPill extends StatelessWidget {
  final String status;

  const MarkStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final bool pending = status == kPendingValidation;
    return StatusPill(
      status,
      fg: pending ? AppColors.warning : AppColors.green,
      bg: pending ? AppColors.warningSoft : AppColors.greenSoft,
    );
  }
}

/// "12 Mar" style short date without needing the intl package.
String shortDay(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${m[d.month - 1]}';
}

/// How big to draw one plant on the map: about the width of a tree crown (7 m)
/// on the ground, kept between a readable minimum and a sensible maximum. The
/// pictures grow as the owner zooms in.
double treePixels(MapCamera camera) {
  final double metresPerPixel =
      156543.03392 *
      math.cos(camera.center.latitude * math.pi / 180) /
      math.pow(2, camera.zoom);
  return (7 / metresPerPixel).clamp(14.0, 54.0).toDouble();
}

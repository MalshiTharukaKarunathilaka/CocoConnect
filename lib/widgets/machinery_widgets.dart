import 'package:flutter/material.dart';
import 'owner_widgets.dart';

/// One service a machine offers (from machinery_services).
class MachineService {
  final int id;
  final String name;
  final String unit; // acre / hour / day
  final int rate;

  const MachineService({
    required this.id,
    required this.name,
    required this.unit,
    required this.rate,
  });

  factory MachineService.fromJson(Map<String, dynamic> json) => MachineService(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    unit: json['unit'] as String? ?? 'acre',
    rate: (json['rate'] as num?)?.toInt() ?? 0,
  );
}

/// A machine shown on the map, calendar and chat. Comes from the backend
/// (`GET /api/machinery/machines`).
class MachineInfo {
  final int id;
  final String name;
  final String provider;
  final String type; // TRACTOR / BACKHOE / HAND_TRACTOR
  final String services;
  final int rate;
  final String unit; // acre / hour

  /// Where the machine is based.
  final double lat;
  final double lng;

  final double? rating;
  final int jobs;

  /// Picks which tractor photo to show (tractors only).
  final int photo;

  /// Everything the machine does, with its rate. Bookings are made from these.
  final List<MachineService> serviceList;

  /// How far from where it is based the provider will travel.
  final int? radiusKm;

  const MachineInfo({
    required this.id,
    required this.name,
    required this.provider,
    required this.type,
    required this.services,
    required this.rate,
    required this.unit,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.jobs,
    required this.photo,
    this.serviceList = const [],
    this.radiusKm,
  });

  factory MachineInfo.fromJson(Map<String, dynamic> json) => MachineInfo(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    provider: json['provider'] as String? ?? '',
    type: json['type'] as String? ?? 'TRACTOR',
    services: json['services'] as String? ?? '',
    rate: (json['rate'] as num?)?.toInt() ?? 0,
    unit: json['unit'] as String? ?? 'acre',
    lat: (json['latitude'] as num).toDouble(),
    lng: (json['longitude'] as num).toDouble(),
    rating: (json['rating'] as num?)?.toDouble(),
    jobs: (json['jobs'] as num?)?.toInt() ?? 0,
    photo: (json['photo'] as num?)?.toInt() ?? 0,
    serviceList: [
      for (final s in (json['service_list'] as List? ?? const []))
        MachineService.fromJson(s as Map<String, dynamic>),
    ],
    radiusKm: (json['radius_km'] as num?)?.toInt(),
  );

  /// "4.8" or "New" for a machine nobody has rated yet.
  String get ratingText => rating == null ? 'New' : rating!.toStringAsFixed(1);
}

IconData machineIcon(String type) => switch (type) {
  'BACKHOE' => Icons.construction,
  'HAND_TRACTOR' => Icons.grass,
  _ => Icons.agriculture,
};

String machineLabel(String type) => switch (type) {
  'BACKHOE' => 'Backhoe',
  'HAND_TRACTOR' => 'Hand Tractor',
  _ => 'Tractor',
};

/// One colour per machine type, used for calendar dots and card edges so a
/// day with a tractor and a backhoe shows two different dots.
Color machineColor(String type) => switch (type) {
  'BACKHOE' => const Color(0xFF8E44AD),
  'HAND_TRACTOR' => const Color(0xFF8B4A1C),
  _ => const Color(0xFF0288D1),
};

const List<String> _tractorPhotos = [
  'disc_plough',
  'rotary',
  'slasher',
  'koku_nagula',
];

/// The machine's photo. Tractors use the photos in assets/services/; backhoes
/// and hand tractors look for assets/machines/backhoe.jpg and
/// assets/machines/hand_tractor.jpg, and show a plain placeholder until those
/// photos are added.
class MachinePhoto extends StatelessWidget {
  final MachineInfo machine;
  final double? width;
  final double height;
  final double radius;

  const MachinePhoto(
    this.machine, {
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  String get _path => switch (machine.type) {
    'BACKHOE' => 'assets/machines/backhoe.jpg',
    'HAND_TRACTOR' => 'assets/machines/hand_tractor.jpg',
    _ => 'assets/services/${_tractorPhotos[machine.photo % 4]}.jpg',
  };

  Widget _placeholder() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE3F0E6), Color(0xFFC9E3D0)],
      ),
    ),
    child: Center(
      child: Icon(
        machineIcon(machine.type),
        size: height * 0.42,
        color: kOwnerGreen.withValues(alpha: 0.8),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          _path,
          fit: BoxFit.cover,
          alignment: machine.type == 'HAND_TRACTOR'
              ? const Alignment(0.7, 0)
              : Alignment.center,
          errorBuilder: (context, error, stack) => _placeholder(),
        ),
      ),
    );
  }
}

/// Small white pill that sits on top of a photo.
class PhotoChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool filled;

  const PhotoChip(this.text, {super.key, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final Color fg = filled ? Colors.white : kOwnerInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? kOwnerGreen : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: filled ? Colors.white : kOwnerGreen),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

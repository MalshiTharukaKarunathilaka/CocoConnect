import 'package:flutter/material.dart';
import 'owner_widgets.dart';
import 'package:latlong2/latlong.dart';

/// A machine shown on the map, calendar and chat. Demo data, not from the
/// database.
class MachineInfo {
  final int? databaseId;
  final LatLng? location;
  final List<Map<String, dynamic>> liveServices;
  final String name;
  final String provider;
  final String type; // TRACTOR / BACKHOE / HAND_TRACTOR
  final String services;
  final num rate;
  final String unit; // acre / hour

  /// Offset from the estate, in degrees, so the demo always sits nearby.
  final double dLat;
  final double dLng;

  final double rating;
  final int jobs;

  /// Picks which tractor photo to show (tractors only).
  final int photo;

  const MachineInfo(
    this.name,
    this.provider,
    this.type,
    this.services,
    this.rate,
    this.unit,
    this.dLat,
    this.dLng,
    this.rating,
    this.jobs,
    this.photo, {
    this.databaseId,
    this.location,
    this.liveServices = const [],
  });
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

// Sample machinery for showing the idea to clients. Not from the database.
const List<MachineInfo> demoMachines = [
  MachineInfo(
    'Massey Ferguson 240',
    'Sunil Machinery',
    'TRACTOR',
    'Slasher · Disc Ploughing · Rotary',
    5000,
    'acre',
    0.018,
    0.022,
    4.8,
    126,
    0,
  ),
  MachineInfo(
    'Kubota M6040 4WD',
    'Nimal Farm Mechanization',
    'TRACTOR',
    'Slasher · Trailer haulage',
    4800,
    'acre',
    -0.024,
    0.031,
    4.7,
    98,
    1,
  ),
  MachineInfo(
    'Mahindra 575 DI',
    'Dambokka Agro',
    'TRACTOR',
    'Koku Nagula · Rotary',
    4500,
    'acre',
    0.035,
    -0.019,
    4.6,
    74,
    2,
  ),
  MachineInfo(
    'Swaraj 744 FE',
    'Ruwan Tractor Service',
    'TRACTOR',
    'Disc Ploughing · Trailer',
    6800,
    'acre',
    -0.041,
    -0.028,
    4.5,
    52,
    3,
  ),
  MachineInfo(
    'Kubota Power Tiller',
    'Saman Agro Services',
    'HAND_TRACTOR',
    'Weeding · Inter-row tilling',
    3200,
    'acre',
    0.027,
    0.004,
    4.9,
    114,
    0,
  ),
  MachineInfo(
    'Yanmar 2-Wheel Tractor',
    'Perera Farm Tools',
    'HAND_TRACTOR',
    'Tilling · Small trailer',
    3000,
    'acre',
    -0.013,
    -0.036,
    4.6,
    61,
    0,
  ),
  MachineInfo(
    'JCB 3CX',
    'Kithsiri Earthmovers',
    'BACKHOE',
    'Ditch & drainage · Pit digging',
    4200,
    'hour',
    0.006,
    -0.043,
    4.8,
    88,
    0,
  ),
  MachineInfo(
    'CAT 424B',
    'Lanka Excavations',
    'BACKHOE',
    'Canal digging · Land clearing',
    6500,
    'hour',
    -0.052,
    0.009,
    4.7,
    67,
    0,
  ),
];

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

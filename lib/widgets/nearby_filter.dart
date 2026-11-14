import 'package:flutter/material.dart';
import '../screens/location_picker_page.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

/// Distance choices for the "near me" filters; null means any distance.
const List<int?> kRadiusOptions = [null, 10, 25, 50];

/// "7.4 km away", or null when either side has no location.
String? distanceLabel(double? km) {
  if (km == null) return null;
  if (km < 1) return 'Less than 1 km away';
  return '${km < 10 ? km.toStringAsFixed(1) : km.round()} km away';
}

/// Lets the logged-in user move their saved location on the map. Returns
/// true when it changed.
Future<bool> changeMyLocation(BuildContext context) async {
  final AppUser? user = AuthService.currentUser;
  if (user == null) return false;

  final PickedLocation? picked = await pickLocation(
    context,
    initial: user.hasCoordinates
        ? PickedLocation(
            name: user.location ?? '',
            latitude: user.latitude!,
            longitude: user.longitude!,
          )
        : null,
  );
  if (picked == null || !context.mounted) return false;

  try {
    await AuthService.updateProfile(
      name: user.name,
      location: picked.name,
      latitude: picked.latitude,
      longitude: picked.longitude,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Location set to ${picked.name}')));
    }
    return true;
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    }
    return false;
  }
}

/// "Near Colombo · Change" with Any / 10 / 25 / 50 km chips.
class NearbyFilter extends StatelessWidget {
  final int? radiusKm;
  final ValueChanged<int?> onRadiusChanged;

  /// Called after the user moves their location, so lists can reload.
  final VoidCallback onLocationChanged;
  final Color accent;

  const NearbyFilter({
    super.key,
    required this.radiusKm,
    required this.onRadiusChanged,
    required this.onLocationChanged,
    this.accent = const Color(0xFF2E7D32),
  });

  Future<void> _change(BuildContext context) async {
    if (await changeMyLocation(context)) onLocationChanged();
  }

  Future<void> _select(BuildContext context, int? km) async {
    final AppUser? user = AuthService.currentUser;
    // A distance needs a starting point: ask for one first.
    if (km != null && !(user?.hasCoordinates ?? false)) {
      if (!await changeMyLocation(context)) return;
      onLocationChanged();
    }
    onRadiusChanged(km);
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = AuthService.currentUser;
    final bool located = user?.hasCoordinates ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.my_location, size: 15, color: accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                located
                    ? 'Near ${user!.location ?? 'your location'}'
                    : 'Set your location to see distances',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3A3A3A),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _change(context),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Text(located ? 'Change' : 'Set location'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final int? km in kRadiusOptions)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: km == null ? 'Any distance' : 'Within $km km',
                    selected: km == radiusKm,
                    accent: accent,
                    onTap: () => _select(context, km),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : const Color(0xFFDADADA),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : const Color(0xFF5A5A5A),
          ),
        ),
      ),
    );
  }
}

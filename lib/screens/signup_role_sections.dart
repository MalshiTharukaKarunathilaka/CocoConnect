import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../utils/sri_lanka_nic.dart';
import '../widgets/auth_widgets.dart';

const List<String> kSignupDistricts = [
  'Ampara',
  'Anuradhapura',
  'Badulla',
  'Batticaloa',
  'Colombo',
  'Galle',
  'Gampaha',
  'Hambantota',
  'Jaffna',
  'Kalutara',
  'Kandy',
  'Kegalle',
  'Kilinochchi',
  'Kurunegala',
  'Mannar',
  'Matale',
  'Matara',
  'Monaragala',
  'Mullaitivu',
  'Nuwara Eliya',
  'Polonnaruwa',
  'Puttalam',
  'Ratnapura',
  'Trincomalee',
  'Vavuniya',
];
const List<int> kSignupRadii = [5, 10, 15, 25];

/// What the sign-up form asks for beyond the shared fields (name, phone,
/// location, password). One per screen; the screen disposes it.
class SignupExtras {
  // Service provider
  final nic = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  String? district;
  int radius = 5;
  bool agreed = false;

  // Estate owner
  final estateName = TextEditingController();
  final estateArea = TextEditingController();
  final estateCrop = TextEditingController(text: 'Coconut');

  void dispose() {
    for (final c in [nic, email, address, estateName, estateArea, estateCrop]) {
      c.dispose();
    }
  }
}

/// A tinted, titled panel that holds the fields for the chosen role.
class RoleSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const RoleSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E6D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kAuthGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: kAuthGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

Widget _labelled(String label, Widget field) => Padding(
  padding: const EdgeInsets.only(top: 14),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AuthLabel(text: label),
      const SizedBox(height: 8),
      field,
    ],
  ),
);

InputDecoration _dropDecoration(String hint, IconData icon) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
  prefixIcon: Icon(icon, size: 20, color: kAuthGreen),
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kAuthBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: kAuthGreen),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFC62828)),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: Color(0xFFC62828)),
  ),
);

Icon _icon(IconData i) => Icon(i, size: 20, color: kAuthGreen);

/// Machinery provider details, shown under the shared fields.
class ProviderSignupSection extends StatelessWidget {
  final SignupExtras extras;
  final VoidCallback onChanged;

  /// The place picked at the top of the form: the base the radius is around.
  final PickedLocation? location;

  const ProviderSignupSection({
    super.key,
    required this.extras,
    required this.onChanged,
    this.location,
  });

  @override
  Widget build(BuildContext context) {
    return RoleSectionCard(
      icon: Icons.agriculture_outlined,
      title: 'Machinery provider details',
      subtitle: 'Estate owners find and book you from the map',
      children: [
        _labelled(
          'NIC Number',
          AuthTextField(
            controller: extras.nic,
            hint: 'Old: 821940129V · New: 198219400129',
            prefixIcon: _icon(Icons.contact_mail_outlined),
            validator: nicError,
          ),
        ),
        _labelled(
          'Email (optional)',
          AuthTextField(
            controller: extras.email,
            hint: 'e.g. sunil.mendis@gmail.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: _icon(Icons.mail_outline),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return null;
              if (value.length > 254 ||
                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 18),
          child: Text(
            'After registration, add your machinery and set service rates '
            'from your calendar page.',
          ),
        ),
        _labelled(
          'Operating district',
          DropdownButtonFormField<String>(
            initialValue: extras.district,
            isExpanded: true,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
            hint: const Text(
              'Select district',
              style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
            ),
            decoration: _dropDecoration('', Icons.location_city_outlined),
            items: [
              for (final d in kSignupDistricts)
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: (v) {
              extras.district = v;
              onChanged();
            },
            validator: (v) =>
                v == null ? 'Select your operating district' : null,
          ),
        ),
        _labelled(
          'Base yard / dispatch address',
          AuthTextField(
            controller: extras.address,
            hint: 'No. 42, Dambokka Junction, Kurunegala',
            prefixIcon: _icon(Icons.home_work_outlined),
            validator: (v) => (v ?? '').trim().isEmpty
                ? 'Enter your base yard or dispatch address'
                : null,
          ),
        ),
        _ServiceRadius(
          radius: extras.radius,
          location: location,
          onChanged: (r) {
            extras.radius = r;
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Estate details, saved to the new estate right after the account is made.
class EstateOwnerSignupSection extends StatelessWidget {
  final SignupExtras extras;

  const EstateOwnerSignupSection({super.key, required this.extras});

  @override
  Widget build(BuildContext context) {
    return RoleSectionCard(
      icon: Icons.park_outlined,
      title: 'Your estate',
      subtitle: 'Buyers see this on your listings. You can edit it later.',
      children: [
        _labelled(
          'Estate name',
          AuthTextField(
            controller: extras.estateName,
            hint: 'e.g. Green Valley Estate',
            prefixIcon: _icon(Icons.landscape_outlined),
          ),
        ),
        _labelled(
          'Total land area',
          AuthTextField(
            controller: extras.estateArea,
            hint: 'e.g. 25 acres',
            prefixIcon: _icon(Icons.crop_square_outlined),
          ),
        ),
        _labelled(
          'Primary crop',
          AuthTextField(
            controller: extras.estateCrop,
            hint: 'e.g. Coconut',
            prefixIcon: _icon(Icons.eco_outlined),
          ),
        ),
      ],
    );
  }
}

/// Roles with nothing extra to fill in: say what they get.
class RoleNoteSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const RoleNoteSection({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return RoleSectionCard(icon: icon, title: title, subtitle: text);
  }
}

/// Service radius chips with a map preview of the area covered.
class _ServiceRadius extends StatelessWidget {
  final int radius;
  final PickedLocation? location;
  final ValueChanged<int> onChanged;

  const _ServiceRadius({
    required this.radius,
    required this.location,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final PickedLocation? place = location;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: AuthLabel(text: 'Service Radius Range')),
              Text(
                '$radius km${radius == 5 ? ' default' : ''}',
                style: const TextStyle(
                  color: kAuthGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final r in kSignupRadii)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: r == kSignupRadii.last ? 0 : 8,
                    ),
                    child: GestureDetector(
                      onTap: () => onChanged(r),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: radius == r ? kAuthGreen : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: radius == r ? kAuthGreen : kAuthBorder,
                          ),
                        ),
                        child: Text(
                          '$r km',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: radius == r ? Colors.white : kAuthGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 190,
              child: place == null ? _placeholder() : _map(place),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Active Match Zone: 0 - $radius km',
            style: const TextStyle(
              color: kAuthGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => const ColoredBox(
    color: Colors.white,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: kAuthGrey, size: 30),
            SizedBox(height: 8),
            Text(
              'Pick your location at the top of the form to preview '
              'the area you cover.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kAuthGrey),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _map(PickedLocation place) {
    final LatLng centre = LatLng(place.latitude, place.longitude);
    const Distance distance = Distance();
    final double metres = radius * 1000.0;
    final LatLngBounds bounds = LatLngBounds.fromPoints([
      distance.offset(centre, metres, 0),
      distance.offset(centre, metres, 90),
      distance.offset(centre, metres, 180),
      distance.offset(centre, metres, 270),
    ]);
    return FlutterMap(
      key: ValueKey('${place.latitude},${place.longitude},$radius'),
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(24),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.kapconnect_mobile',
        ),
        CircleLayer(
          circles: [
            CircleMarker(
              point: centre,
              radius: metres,
              useRadiusInMeter: true,
              color: kAuthGreen.withAlpha(45),
              borderColor: kAuthGreen.withAlpha(120),
              borderStrokeWidth: 2,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: centre,
              child: const Icon(Icons.location_on, color: kAuthGreen, size: 36),
            ),
          ],
        ),
        const SimpleAttributionWidget(
          source: Text('OpenStreetMap contributors'),
        ),
      ],
    );
  }
}

/// "I confirm my details are accurate..." tick box, asked of every role.
class SignupAgreement extends StatelessWidget {
  final SignupExtras extras;
  final VoidCallback onChanged;

  const SignupAgreement({
    super.key,
    required this.extras,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<bool>(
      initialValue: false,
      validator: (_) =>
          extras.agreed ? null : 'Please accept the agreement to continue',
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              extras.agreed = !extras.agreed;
              state.didChange(extras.agreed);
              onChanged();
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: extras.agreed,
                  activeColor: kAuthGreen,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) {
                    extras.agreed = v ?? false;
                    state.didChange(extras.agreed);
                    onChanged();
                  },
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'I confirm my details are accurate and agree to '
                      'the CocoConnect Service Terms and Code of Conduct.',
                      style: TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                state.errorText!,
                style: const TextStyle(color: Color(0xFFC62828), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

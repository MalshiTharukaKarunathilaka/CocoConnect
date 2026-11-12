import 'package:flutter/material.dart';
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
const List<String> kSignupMachines = ['Tractor', 'Backhoe', 'Hand Tractor'];
const List<int> kSignupRadii = [5, 10, 15, 25];

/// What the sign-up form asks for beyond the shared fields (name, phone,
/// location, password). One per screen; the screen disposes it.
class SignupExtras {
  // Service provider
  final nic = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  String? district;
  String machinery = kSignupMachines.first;
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

  const ProviderSignupSection({
    super.key,
    required this.extras,
    required this.onChanged,
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
        _labelled(
          'Machinery type',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in kSignupMachines)
                RoleChip(
                  label: m,
                  isSelected: extras.machinery == m,
                  onTap: () {
                    extras.machinery = m;
                    onChanged();
                  },
                ),
            ],
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
        _labelled(
          'How far will you travel?',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in kSignupRadii)
                RoleChip(
                  label: '$r km',
                  isSelected: extras.radius == r,
                  onTap: () {
                    extras.radius = r;
                    onChanged();
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Measured from the location you picked on the map above.',
            style: const TextStyle(fontSize: 12, color: kAuthGrey),
          ),
        ),
        FormField<bool>(
          initialValue: false,
          validator: (_) =>
              extras.agreed ? null : 'Please accept the agreement to continue',
          builder: (state) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
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
                      style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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

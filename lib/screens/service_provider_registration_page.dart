import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_client.dart';
import '../widgets/owner_widgets.dart';
import 'auth_gate.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import 'location_picker_page.dart';
import 'login_page.dart';

const _green = kOwnerGreen;
const _fill = kOwnerPanel;

class ServiceProviderRegistrationPage extends StatefulWidget {
  final Future<RegistrationStorage> Function()? storageLoader;
  const ServiceProviderRegistrationPage({super.key, this.storageLoader});
  @override
  State<ServiceProviderRegistrationPage> createState() => _RegistrationState();
}

class _RegistrationState extends State<ServiceProviderRegistrationPage> {
  final _form = GlobalKey<FormState>();
  late Future<RegistrationStorage> _storage;
  @override
  void initState() {
    super.initState();
    _storage = (widget.storageLoader ?? AuthService.registrationStorage)();
  }

  Widget _storageBanner() => FutureBuilder<RegistrationStorage>(
    future: _storage,
    builder: (context, snapshot) {
      final status = snapshot.data;
      final text = snapshot.connectionState != ConnectionState.done
          ? 'Checking account storage...'
          : snapshot.hasError
          ? 'Cannot verify account storage. Restart or reconnect the backend.'
          : status?.ready != true
          ? 'Registration database setup is incomplete. Check the backend.'
          : status!.persistent
          ? 'Connected to shared database. Your account will be saved.'
          : 'Temporary preview mode. Accounts are NOT saved to Supabase and disappear when the backend restarts.';
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OwnerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                text,
                key: const Key('registration-storage-status'),
                style: TextStyle(
                  fontSize: 13,
                  color: status?.persistent == true && status?.ready == true
                      ? _green
                      : kOwnerBrown,
                ),
              ),
              if (snapshot.hasError || status?.ready == false)
                TextButton(
                  onPressed: () => setState(() {
                    _storage =
                        (widget.storageLoader ??
                        AuthService.registrationStorage)();
                  }),
                  child: const Text('Check connection again'),
                ),
            ],
          ),
        ),
      );
    },
  );
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _nic = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _address = TextEditingController();
  final _map = MapController();
  final _fieldKeys = <String, GlobalKey<FormFieldState<String>>>{};
  Map<String, String> _serverErrors = {};
  late final _fieldNames = <TextEditingController, String>{
    _name: 'name',
    _phone: 'phone',
    _nic: 'identity_number',
    _email: 'email',
    _password: 'password',
    _confirm: 'confirm_password',
    _address: 'address',
  };
  GlobalKey<FormFieldState<String>> _fieldKey(String name) =>
      _fieldKeys.putIfAbsent(name, () => GlobalKey<FormFieldState<String>>());

  void _revealFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final key in _fieldKeys.values) {
        if (key.currentState?.hasError == true && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            alignment: .15,
            duration: const Duration(milliseconds: 250),
          );
          return;
        }
      }
    });
  }

  PickedLocation? _location;
  String? _district;
  String _machinery = 'Tractor';
  int _radius = 5;
  bool _hidden = true, _confirmHidden = true, _agreed = false;
  bool _saving = false, _locating = false;
  static const _districts = [
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
  static const _machines = ['Tractor', 'Backhoe', 'Hand Tractor'];

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _nic,
      _email,
      _password,
      _confirm,
      _address,
    ]) {
      c.dispose();
    }
    _map.dispose();
    super.dispose();
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pick({bool gps = false}) async {
    FocusScope.of(context).unfocus();
    setState(() => _locating = true);
    try {
      PickedLocation? place;
      if (gps) {
        final point = await LocationService.currentPosition();
        final name = await LocationService.placeName(
          point.latitude,
          point.longitude,
        );
        place = PickedLocation(
          name: name ?? 'Selected GPS location',
          latitude: point.latitude,
          longitude: point.longitude,
        );
      } else {
        place = await pickLocation(context, initial: _location);
      }
      if (!mounted || place == null) return;
      final hadLocation = _location != null;
      setState(() {
        _location = place;
        if (_address.text.trim().isEmpty) _address.text = place!.name;
      });
      if (hadLocation) _map.move(LatLng(place.latitude, place.longitude), 11);
    } on LocationProblem catch (e) {
      if (mounted) _message(e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) {
      _revealFirstError();
      return;
    }
    if (_location == null) {
      _message('Select your operating base using GPS or the map.');
      return;
    }
    if (!_agreed) {
      _message('Please accept the agreement to continue.');
      return;
    }
    setState(() => _saving = true);
    try {
      final storage = await _storage;
      if (!mounted) return;
      if (!storage.ready) {
        _message(
          'Registration database setup is incomplete. Check the backend.',
        );
        return;
      }
      final user = await AuthService.signup(
        name: _name.text.trim(),
        phone: _phone.text,
        password: _password.text,
        role: 'Service Provider',
        location: _address.text.trim(),
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        serviceProvider: {
          'identity_number': _nic.text.trim(),
          'email': _email.text.trim(),
          'category': 'Machinery',
          'machinery_type': _machinery,
          'district': _district,
          'address': _address.text.trim(),
          'radius_km': _radius,
          'terms_accepted': _agreed,
        },
      );
      if (!mounted) return;
      openHomeFor(context, user);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _serverErrors = e.fieldErrors);
      _form.currentState!.validate();
      _revealFirstError();
      _message(e.message);
    } catch (_) {
      if (mounted) {
        _message('Could not complete registration. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF7B847C)),
        suffixIcon: suffix,
        filled: true,
        fillColor: _fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;
  Widget _field(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon, {
    TextInputType? keyboard,
    bool secret = false,
    bool hidden = false,
    VoidCallback? toggle,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 5),
        TextFormField(
          key: _fieldKey(_fieldNames[controller]!),
          controller: controller,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (_) {
            _serverErrors.remove(_fieldNames[controller]);
          },
          keyboardType: keyboard,
          obscureText: hidden,
          enableSuggestions: !secret,
          autocorrect: !secret,
          decoration: _decoration(
            hint,
            icon,
            suffix: toggle == null
                ? null
                : IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    onPressed: toggle,
                    icon: Icon(
                      hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  ),
          ),
          validator: (value) {
            final field = _fieldNames[controller]!;
            if (field == 'identity_number' &&
                (value ?? '').trim().length > 40) {
              return 'Use at most 40 characters';
            }
            if (field == 'email' && (value ?? '').trim().length > 254) {
              return 'Use at most 254 characters';
            }
            return (validator ?? _required)(value) ?? _serverErrors[field];
          },
        ),
      ],
    ),
  );
  Widget _card(
    String title,
    IconData icon,
    List<Widget> children, {
    String? subtitle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: kOwnerGreenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _green, size: 21),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: kOwnerInk,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kOwnerMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          ...children,
        ],
      ),
    ),
  );
  Widget _dropdown(
    String label,
    String? value,
    List<String> values,
    IconData icon,
    ValueChanged<String?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          key: _fieldKey(
            label == 'Machinery Category *' ? 'machinery_type' : 'district',
          ),
          initialValue: value,
          isExpanded: true,
          decoration: _decoration('Select district', icon),
          items: values
              .map(
                (v) => DropdownMenuItem(
                  value: v,
                  child: Text(v, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (value) {
            _serverErrors.remove(
              label == 'Machinery Category *' ? 'machinery_type' : 'district',
            );
            changed(value);
          },
          validator: (value) =>
              _required(value) ??
              _serverErrors[label == 'Machinery Category *'
                  ? 'machinery_type'
                  : 'district'],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final point = _location == null
        ? null
        : LatLng(_location!.latitude, _location!.longitude);
    return OwnerPage(
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: _green)),
        child: Column(
          children: [
            const OwnerHeader(
              title: 'Provider Registration',
              subtitle: 'MACHINERY SERVICES',
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _saving,
                child: Form(
                  key: _form,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          margin: const EdgeInsets.only(bottom: 26),
                          decoration: BoxDecoration(
                            color: _fill,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Join the KapConnect\nMachinery Network',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              color: kOwnerInk,
                            ),
                          ),
                        ),
                        _storageBanner(),
                        _card(
                          'Account Information',
                          Icons.badge_outlined,
                          [
                            _field(
                              'Full Name *',
                              _name,
                              'e.g. Sunil Mendis',
                              Icons.person_outline,
                              keyboard: TextInputType.name,
                            ),
                            _field(
                              'Mobile Number *',
                              _phone,
                              '+94  77 123 4567',
                              Icons.phone_outlined,
                              keyboard: TextInputType.phone,
                              validator: (v) =>
                                  RegExp(r'^(?:0|94|\+94)?7\d{8}$').hasMatch(
                                    (v ?? '').replaceAll(RegExp(r'[\s-]'), ''),
                                  )
                                  ? null
                                  : 'Enter a valid Sri Lankan mobile number',
                            ),
                            _field(
                              'NIC or Driving License No. *',
                              _nic,
                              'e.g. 821940129V or 198219400129',
                              Icons.contact_mail_outlined,
                            ),
                            _field(
                              'Email Address (Optional)',
                              _email,
                              'e.g. sunil.mendis@gmail.com',
                              Icons.mail_outline,
                              keyboard: TextInputType.emailAddress,
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ||
                                      RegExp(
                                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                      ).hasMatch(v!.trim())
                                  ? null
                                  : 'Enter a valid email address',
                            ),
                            _field(
                              'Account Password *',
                              _password,
                              'Min. 8 characters',
                              Icons.lock_outline,
                              secret: true,
                              hidden: _hidden,
                              toggle: () => setState(() => _hidden = !_hidden),
                              validator: (v) => (v ?? '').length >= 8
                                  ? null
                                  : 'Use at least 8 characters',
                            ),
                            _field(
                              'Confirm Password *',
                              _confirm,
                              'Re-enter password',
                              Icons.lock_reset,
                              secret: true,
                              hidden: _confirmHidden,
                              toggle: () => setState(
                                () => _confirmHidden = !_confirmHidden,
                              ),
                              validator: (v) =>
                                  v == _password.text && (v ?? '').isNotEmpty
                                  ? null
                                  : 'Passwords do not match',
                            ),
                          ],
                          subtitle: 'Personal & official verification details',
                        ),
                        _card(
                          'Service Category & Equipment Details',
                          Icons.agriculture_outlined,
                          [
                            const SizedBox(height: 16),
                            const Text(
                              'Primary Service Category *',
                              style: TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Chip(
                                avatar: Icon(
                                  Icons.agriculture_outlined,
                                  color: _green,
                                  size: 18,
                                ),
                                label: Text('Machinery'),
                                backgroundColor: kOwnerGreenSoft,
                              ),
                            ),
                            _dropdown(
                              'Machinery Category *',
                              _machinery,
                              _machines,
                              Icons.local_shipping_outlined,
                              (v) => setState(() => _machinery = v!),
                            ),
                          ],
                        ),
                        _card(
                          'Operating Base & Coverage Area',
                          Icons.pin_drop_outlined,
                          [
                            _dropdown(
                              'Operating District *',
                              _district,
                              _districts,
                              Icons.location_city,
                              (v) => setState(() => _district = v),
                            ),
                            _field(
                              'Base Yard / Dispatch Address *',
                              _address,
                              'No. 42, Dambokka Junction, Kurunegala',
                              Icons.home_work_outlined,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: _locating
                                        ? null
                                        : () => _pick(gps: true),
                                    icon: const Icon(
                                      Icons.my_location,
                                      size: 17,
                                    ),
                                    label: Text(
                                      _locating
                                          ? 'Locating...'
                                          : 'Use Current GPS',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: _locating ? null : () => _pick(),
                                    icon: const Icon(
                                      Icons.place_outlined,
                                      size: 17,
                                    ),
                                    label: const Text(
                                      'Pick on Map',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Service Radius Range',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_radius km${_radius == 5 ? ' default' : ''}',
                                  style: const TextStyle(
                                    color: _green,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (final r in [5, 10, 15, 25])
                                  ChoiceChip(
                                    showCheckmark: false,
                                    label: Text('$r km'),
                                    selected: _radius == r,
                                    selectedColor: _green,
                                    labelStyle: TextStyle(
                                      color: _radius == r
                                          ? Colors.white
                                          : kOwnerInk,
                                    ),
                                    onSelected: (_) =>
                                        setState(() => _radius = r),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 220,
                                child: point == null
                                    ? ColoredBox(
                                        color: _fill,
                                        child: Center(
                                          child: TextButton.icon(
                                            onPressed: _locating
                                                ? null
                                                : () => _pick(),
                                            icon: const Icon(
                                              Icons.map_outlined,
                                            ),
                                            label: const Text(
                                              'Select your base to preview coverage',
                                            ),
                                          ),
                                        ),
                                      )
                                    : FlutterMap(
                                        mapController: _map,
                                        options: MapOptions(
                                          initialCenter: point,
                                          initialZoom: 11,
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName:
                                                'com.example.kapconnect_mobile',
                                          ),
                                          CircleLayer(
                                            circles: [
                                              CircleMarker(
                                                point: point,
                                                radius: _radius * 1000,
                                                useRadiusInMeter: true,
                                                color: _green.withAlpha(45),
                                                borderColor: _green.withAlpha(
                                                  100,
                                                ),
                                                borderStrokeWidth: 2,
                                              ),
                                            ],
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: point,
                                                child: const Icon(
                                                  Icons.location_on,
                                                  color: _green,
                                                  size: 38,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SimpleAttributionWidget(
                                            source: Text(
                                              'OpenStreetMap contributors',
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Active Match Zone: 0 - $_radius km',
                              style: const TextStyle(
                                color: _green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        _card('Agreement & Verification', Icons.gavel_outlined, [
                          const SizedBox(height: 14),
                          FormField<bool>(
                            initialValue: false,
                            validator: (_) =>
                                _agreed ? null : 'Please accept the agreement',
                            builder: (state) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 28,
                                      child: Checkbox(
                                        value: _agreed,
                                        activeColor: _green,
                                        onChanged: (v) {
                                          setState(() => _agreed = v!);
                                          state.didChange(v);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'I confirm that the personal information provided is accurate and I agree to the CocoConnect Service Terms and Agrarian Code of Conduct.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          height: 1.5,
                                          color: Color(0xFF455148),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (state.hasError)
                                  Text(
                                    state.errorText!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ]),
                        FilledButton(
                          onPressed: _saving ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: FutureBuilder<RegistrationStorage>(
                            future: _storage,
                            builder: (context, snapshot) => Text(
                              _saving
                                  ? 'Creating account...'
                                  : snapshot.data?.persistent == false
                                  ? 'Create Temporary Account'
                                  : 'Complete & Register Account',
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _openLogin,
                          child: const Text(
                            'Already have an account? Log In',
                            style: TextStyle(color: _green),
                          ),
                        ),
                      ],
                    ),
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

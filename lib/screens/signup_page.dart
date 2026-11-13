import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/owner_service.dart';
import '../widgets/auth_widgets.dart';
import 'auth_gate.dart';
import 'location_picker_page.dart';
import 'signup_role_sections.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  static const List<String> _roles = [
    'Estate Owner',
    'Estate Manager',
    'Buyer',
    'Service Provider',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _locationController = TextEditingController();
  final SignupExtras _extras = SignupExtras();

  /// Where the user is; required, used for "near me" filters.
  PickedLocation? _location;

  /// The address filled in from the location, so a hand-typed one is kept.
  String? _autoAddress;

  String _selectedRole = _roles.first;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _locationController.dispose();
    _extras.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final PickedLocation? picked = await pickLocation(
      context,
      initial: _location,
    );
    if (picked == null) return;
    setState(() {
      _location = picked;
      _locationController.text = picked.name;
      // The provider's base address follows the picked place until they
      // type their own.
      if (_extras.address.text.trim().isEmpty ||
          _extras.address.text == _autoAddress) {
        _extras.address.text = picked.name;
        _autoAddress = picked.name;
      }
    });
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    final bool isProvider = _selectedRole == 'Service Provider';
    setState(() => _loading = true);

    try {
      final user = await AuthService.signup(
        name: _nameController.text.trim(),
        phone: _phoneController.text,
        password: _passwordController.text,
        role: _selectedRole,
        location: _location!.name,
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        serviceProvider: isProvider
            ? {
                'identity_number': _extras.nic.text.trim(),
                'email': _extras.email.text.trim(),
                'category': 'Machinery',
                'machinery_type': _extras.machinery,
                'district': _extras.district,
                'address': _extras.address.text.trim(),
                'radius_km': _extras.radius,
                'terms_accepted': _extras.agreed,
              }
            : null,
      );
      if (_selectedRole == 'Estate Owner' &&
          _extras.estateName.text.trim().isNotEmpty) {
        try {
          await OwnerService.updateEstate(
            estateName: _extras.estateName.text.trim(),
            location: _location!.name,
            totalLandArea: _extras.estateArea.text.trim(),
            primaryCrop: _extras.estateCrop.text.trim(),
          );
        } catch (_) {
          // The account exists; the estate can be filled in from the profile.
        }
      }
      if (!mounted) return;
      openHomeFor(context, user);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The fields that belong to the chosen role, shown under the role chips.
  Widget _roleSection() {
    switch (_selectedRole) {
      case 'Service Provider':
        return ProviderSignupSection(
          extras: _extras,
          location: _location,
          onChanged: () => setState(() {}),
        );
      case 'Estate Owner':
        return EstateOwnerSignupSection(extras: _extras);
      case 'Estate Manager':
        return const RoleNoteSection(
          icon: Icons.assignment_ind_outlined,
          title: 'Estate manager',
          text: 'Run day-to-day sales and bookings for your estate.',
        );
      default:
        return const RoleNoteSection(
          icon: Icons.shopping_basket_outlined,
          title: 'Buyer',
          text: 'Post what you need and get offers from nearby estates.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const SizedBox(height: 40),

        const AuthHeading(
          title: 'Create Account',
          subtitle: 'Enter your details to get started',
        ),

        const SizedBox(height: 28),

        AuthCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthLabel(text: 'Full Name'),
                const SizedBox(height: 8),
                AuthTextField(
                  controller: _nameController,
                  hint: 'Enter your full name',
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                const AuthLabel(text: 'Phone Number'),
                const SizedBox(height: 8),
                AuthPhoneField(controller: _phoneController),

                const SizedBox(height: 18),

                const AuthLabel(text: 'Location'),
                const SizedBox(height: 8),
                AuthTextField(
                  controller: _locationController,
                  hint: 'Pick your location on the map',
                  readOnly: true,
                  onTap: _pickLocation,
                  prefixIcon: const Icon(
                    Icons.place_outlined,
                    size: 20,
                    color: kAuthGreen,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Open map',
                    icon: const Icon(
                      Icons.map_outlined,
                      size: 20,
                      color: kAuthGrey,
                    ),
                    onPressed: _pickLocation,
                  ),
                  validator: (_) => _location == null
                      ? 'Pick your location so nearby buyers and estates '
                            'can find you'
                      : null,
                ),

                const SizedBox(height: 18),

                const AuthLabel(text: 'I am a'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _roles.map((role) {
                    return RoleChip(
                      label: role,
                      isSelected: _selectedRole == role,
                      onTap: () => setState(() => _selectedRole = role),
                    );
                  }).toList(),
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: KeyedSubtree(
                      key: ValueKey(_selectedRole),
                      child: _roleSection(),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                const AuthLabel(text: 'Password'),
                const SizedBox(height: 8),
                AuthTextField(
                  controller: _passwordController,
                  hint: 'Enter your password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: kAuthGrey,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return 'Password is required';
                    }
                    final int least = _selectedRole == 'Service Provider'
                        ? 8
                        : 6;
                    if ((value ?? '').length < least) {
                      return 'Use at least $least characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 18),

                const AuthLabel(text: 'Confirm Password'),
                const SizedBox(height: 8),
                AuthTextField(
                  controller: _confirmController,
                  hint: 'Re-enter your password',
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: kAuthGrey,
                    ),
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                SignupAgreement(
                  extras: _extras,
                  onChanged: () => setState(() {}),
                ),

                const SizedBox(height: 14),

                AuthPrimaryButton(
                  label: _loading ? 'Creating account...' : 'Sign Up',
                  onPressed: _loading ? null : _submit,
                ),

                const SizedBox(height: 18),

                const AuthOrDivider(),

                const SizedBox(height: 6),

                AuthSecondaryAction(
                  icon: Icons.mail_outline,
                  label: 'Sign Up with Email/Password',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        AuthBottomPrompt(
          question: 'Already have an account? ',
          action: 'Login',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

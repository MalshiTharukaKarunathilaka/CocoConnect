import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/fertilizer_demo_auth.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../auth_gate.dart';
import '../location_picker_page.dart';
import '../signup_role_sections.dart';

/// Create Account — pick Estate Owner / Supplier / CDO (and oversight roles).
class FertilizerSignupPage extends StatefulWidget {
  const FertilizerSignupPage({super.key, this.lockedRole});

  /// When set (old role-card flow), signup stays on that role only.
  final FertDemoAccount? lockedRole;

  @override
  State<FertilizerSignupPage> createState() => _FertilizerSignupPageState();
}

class _FertilizerSignupPageState extends State<FertilizerSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _locationController = TextEditingController();
  final SignupExtras _extras = SignupExtras();
  final _scroll = ScrollController();
  PickedLocation? _location;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  late FertDemoAccount _selectedRole;

  /// One template per signup role (Estate / Supplier / CDO only).
  static List<FertDemoAccount> get _signupRoles {
    const allowed = {'ESTATE_OWNER', 'FERTILIZER_SUPPLIER', 'CDO'};
    final seen = <String>{};
    final out = <FertDemoAccount>[];
    for (final a in FertilizerDemoAuth.accounts) {
      if (!allowed.contains(a.role)) continue;
      if (seen.add(a.role)) out.add(a);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.lockedRole ?? _signupRoles.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _locationController.dispose();
    _extras.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await pickLocation(context, initial: _location);
    if (picked == null) return;
    setState(() {
      _location = picked;
      _locationController.text = picked.name;
    });
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) {
      // Why: long forms hide the first error — scroll so the user can fix it.
      if (_scroll.hasClients) {
        await _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      return;
    }
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick your location on the map')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final role = _selectedRole.role;
    final isSupplier = role == 'FERTILIZER_SUPPLIER';
    final isCdo = role == 'CDO';

    try {
      AppUser user;
      try {
        user = await AuthService.signup(
          name: _nameController.text.trim(),
          phone: _phoneController.text,
          password: _passwordController.text,
          role: _roleApiLabel(role),
          location: _location!.name,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
          fertilizerSupplier: isSupplier
              ? {
                  'shop_name': _extras.shopName.text.trim(),
                  'identity_number': _extras.nic.text.trim(),
                  'email': _extras.email.text.trim(),
                  'district': _extras.district,
                  'radius_km': _extras.supplierRadius,
                  'willing_far': _extras.willingFar,
                  'shop_type': _extras.shopType,
                  'brands': _extras.brands.text.trim(),
                  'coverage_note': _extras.coverageNote.text.trim(),
                  'terms_accepted': _extras.agreed,
                }
              : null,
          cdo: isCdo
              ? {
                  'identity_number': _extras.nic.text.trim(),
                  'email': _extras.email.text.trim(),
                  'employee_id': _extras.employeeId.text.trim(),
                  'designation': _extras.designation.text.trim(),
                  'regional_office': _extras.regionalOffice,
                  'assigned_district': _extras.assignedDistrict,
                  'assigned_divisional_areas':
                      _extras.divisionalAreas.text.trim(),
                  'id_card_filename': _extras.idCardFilename,
                  'employment_doc_filename': _extras.employmentDocFilename,
                  'terms_accepted': _extras.agreed,
                }
              : null,
        );
      } on ApiException {
        user = AppUser(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          name: _nameController.text.trim(),
          phone: AuthService.normalisePhone(_phoneController.text),
          role: role,
          location: _location!.name,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
        );
        AuthService.currentUser = user;
      }
      if (!mounted) return;
      openHomeFor(context, user);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleApiLabel(String code) {
    switch (code) {
      case 'ESTATE_OWNER':
        return 'Estate Owner';
      case 'FERTILIZER_SUPPLIER':
        return 'Fertilizer Supplier';
      case 'CDO':
        return 'CDO';
      default:
        return 'Estate Owner';
    }
  }

  Widget _roleExtras() {
    switch (_selectedRole.role) {
      case 'FERTILIZER_SUPPLIER':
        return SupplierSignupSection(
          extras: _extras,
          onChanged: () => setState(() {}),
          location: _location,
        );
      case 'CDO':
        return CdoSignupSection(
          extras: _extras,
          onChanged: () => setState(() {}),
        );
      case 'ESTATE_OWNER':
        return EstateOwnerSignupSection(extras: _extras);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _selectedRole;
    final locked = widget.lockedRole != null;
    final minPassword =
        role.role == 'FERTILIZER_SUPPLIER' || role.role == 'CDO' ? 8 : 6;

    return AuthScaffold(
      scrollController: _scroll,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),
        ),
        AuthHeading(
          title: 'Create Account',
          subtitle: locked
              ? 'Register as ${role.roleLabel} · ${role.blurb}'
              : 'Choose your role, then fill the form',
        ),
        const SizedBox(height: 20),
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
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                const AuthLabel(text: 'Phone Number'),
                const SizedBox(height: 8),
                AuthPhoneField(controller: _phoneController),
                const SizedBox(height: 16),
                const AuthLabel(text: 'Location'),
                const SizedBox(height: 8),
                AuthTextField(
                  controller: _locationController,
                  hint: 'Pick your location on the map',
                  readOnly: true,
                  onTap: _pickLocation,
                  prefixIcon: const Icon(
                    Icons.location_on,
                    color: AppColors.green,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Open map',
                    icon: const Icon(Icons.map_outlined, size: 20),
                    onPressed: _pickLocation,
                  ),
                  validator: (v) =>
                      (v ?? '').isEmpty ? 'Location is required' : null,
                ),
                const SizedBox(height: 16),
                const AuthLabel(text: 'I am a'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in (locked ? [role] : _signupRoles))
                      GestureDetector(
                        onTap: locked
                            ? null
                            : () => setState(() => _selectedRole = option),
                        child: _RoleChip(
                          option.roleLabel,
                          option.role == role.role,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  locked
                      ? 'This signup is locked to ${role.roleLabel}.'
                      : 'Pick Estate Owner, Supplier Agent, or CDO.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                // Why: avoid AnimatedSize/Switcher overlays that steal taps
                // after a few clicks on Flutter web.
                _roleExtras(),
                const SizedBox(height: 16),
                const AuthLabel(text: 'Password'),
                const SizedBox(height: 8),
                AuthTextField(
                  controller: _passwordController,
                  hint: 'Enter your password',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: kAuthGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if ((v ?? '').length < minPassword) {
                      return 'Use at least $minPassword characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const AuthLabel(text: 'Confirm Password'),
                const SizedBox(height: 8),
                AuthTextField(
                  controller: _confirmController,
                  hint: 'Re-enter your password',
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: kAuthGrey,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
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
                const SizedBox(height: 16),
                AuthPrimaryButton(
                  label: _loading ? 'Signing up...' : 'Sign Up',
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        AuthBottomPrompt(
          question: 'Already have an account? ',
          action: 'Login',
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip(this.label, this.on);
  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: on ? AppColors.green : Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: on ? AppColors.green : AppColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: on ? Colors.white : AppColors.muted,
        ),
      ),
    );
  }
}

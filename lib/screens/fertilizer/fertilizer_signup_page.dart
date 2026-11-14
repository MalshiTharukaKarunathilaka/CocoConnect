import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/fertilizer_demo_auth.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../auth_gate.dart';
import '../location_picker_page.dart';

/// Create Account for one fertilizer role — matches the signup screenshot.
class FertilizerSignupPage extends StatefulWidget {
  const FertilizerSignupPage({super.key, required this.lockedRole});

  final FertDemoAccount lockedRole;

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
  PickedLocation? _location;
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
    if (_loading || !_formKey.currentState!.validate()) return;
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick your location on the map')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      AppUser user;
      try {
        user = await AuthService.signup(
          name: _nameController.text.trim(),
          phone: _phoneController.text,
          password: _passwordController.text,
          role: _roleApiLabel(widget.lockedRole.role),
          location: _location!.name,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
        );
      } on ApiException {
        // Offline demo: create a local session with this role.
        user = AppUser(
          id: DateTime.now().millisecondsSinceEpoch % 100000,
          name: _nameController.text.trim(),
          phone: AuthService.normalisePhone(_phoneController.text),
          role: widget.lockedRole.role,
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

  /// Backend expects friendly labels like "Fertilizer Supplier".
  String _roleApiLabel(String code) {
    switch (code) {
      case 'ESTATE_OWNER':
        return 'Estate Owner';
      case 'FERTILIZER_SUPPLIER':
        return 'Fertilizer Supplier';
      case 'CDO':
        return 'CDO';
      case 'REGIONAL_MANAGER':
        return 'Estate Manager';
      case 'CHAIRMAN':
        return 'Estate Manager';
      default:
        return 'Estate Owner';
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.lockedRole;
    return AuthScaffold(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),
        ),
        const AuthHeading(
          title: 'Create Account',
          subtitle: 'Enter your details to get started',
        ),
        const SizedBox(height: 24),
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
                  suffixIcon: const Icon(Icons.map_outlined, size: 20),
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
                    _RoleChip(role.roleLabel, true),
                    const _RoleChip('Estate Owner', false),
                    const _RoleChip('Buyer', false),
                    const _RoleChip('Service Provider', false),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'This signup is locked to ${role.roleLabel} for the fertilizer demo.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
                const SizedBox(height: 16),
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
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if ((v ?? '').length < 6) {
                      return 'Use at least 6 characters';
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
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _loading ? 'Signing up...' : 'Sign Up',
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
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

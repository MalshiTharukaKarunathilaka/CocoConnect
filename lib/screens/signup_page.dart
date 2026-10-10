import 'package:flutter/material.dart';
import '../widgets/auth_widgets.dart';

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

  String _selectedRole = _roles.first;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // No backend yet - confirm the form is valid so the flow can be demoed.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Creating $_selectedRole account'),
        backgroundColor: kAuthGreen,
      ),
    );
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
                    if ((value ?? '').length < 6) {
                      return 'Use at least 6 characters';
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

                const SizedBox(height: 22),

                AuthPrimaryButton(
                  label: 'Sign Up',
                  onPressed: _submit,
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

import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'auth_gate.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final user = await AuthService.login(
        phone: _phoneController.text,
        password: _passwordController.text,
      );
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

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const SizedBox(height: 60),

        const AuthHeading(
          title: 'Welcome Back',
          subtitle: 'Enter your phone number to continue',
        ),

        const SizedBox(height: 32),

        AuthCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthLabel(text: 'Phone Number'),
                const SizedBox(height: 8),
                AuthPhoneField(controller: _phoneController),

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
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: kAuthGreen,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                AuthPrimaryButton(
                  label: _loading ? 'Logging in...' : 'Login',
                  onPressed: _loading ? null : _submit,
                ),

                const SizedBox(height: 18),

                const AuthOrDivider(),

                const SizedBox(height: 6),

                AuthSecondaryAction(
                  icon: Icons.mail_outline,
                  label: 'Login with Email/Password',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        AuthBottomPrompt(
          question: "Don't have an account? ",
          action: 'Sign Up',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignupPage()),
            );
          },
        ),
      ],
    );
  }
}

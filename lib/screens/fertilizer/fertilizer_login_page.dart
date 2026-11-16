import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/fertilizer_demo_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../auth_gate.dart';
import 'fertilizer_signup_page.dart';

/// Role-specific login — same layout as the “Welcome Back” screenshot.
class FertilizerLoginPage extends StatefulWidget {
  const FertilizerLoginPage({super.key, required this.account});

  final FertDemoAccount account;

  @override
  State<FertilizerLoginPage> createState() => _FertilizerLoginPageState();
}

class _FertilizerLoginPageState extends State<FertilizerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Prefill demo phone so you can just type the password (or tap Login).
    _phoneController = TextEditingController(
      text: widget.account.phone.replaceFirst(RegExp(r'^0'), ''),
    );
    _passwordController = TextEditingController(text: FertilizerDemoAuth.passwordHint);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      AppUser? user;

      // 1) Try live API (backend memory seed uses the same phones/passwords).
      try {
        user = await AuthService.login(
          phone: _phoneController.text,
          password: _passwordController.text,
        );
        // If they logged into the wrong role on the API, reject.
        if (user.role != widget.account.role &&
            !(widget.account.role == 'FERTILIZER_SUPPLIER' &&
                user.role == 'SERVICE_PROVIDER')) {
          await AuthService.logout();
          throw const ApiException(
            'This phone is registered as a different role. Pick the matching card.',
          );
        }
      } on ApiException {
        // 2) Offline / wrong API → local demo login (shared fertilizer store).
        user = FertilizerDemoAuth.tryLogin(
          phone: _phoneController.text,
          password: _passwordController.text,
          expectedRole: widget.account.role,
        );
        if (user == null) {
          throw const ApiException('Incorrect phone number or password');
        }
        AuthService.currentUser = user;
      }

      if (!mounted) return;
      openHomeFor(context, user!);
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

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return AuthScaffold(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 12),
        AuthHeading(
          title: 'Welcome Back',
          subtitle: 'Sign in as ${a.roleLabel} · ${a.name}',
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            a.roleLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
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
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Password is required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Demo password: ${FertilizerDemoAuth.passwordHint}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
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
                  icon: Icons.flash_on_outlined,
                  label: 'Quick demo login',
                  onTap: _loading
                      ? () {}
                      : () {
                          _passwordController.text =
                              FertilizerDemoAuth.passwordHint;
                          _submit();
                        },
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
              MaterialPageRoute(
                builder: (_) => FertilizerSignupPage(lockedRole: a),
              ),
            );
          },
        ),
      ],
    );
  }
}

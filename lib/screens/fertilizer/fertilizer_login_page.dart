import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/fertilizer_demo_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../auth_gate.dart';
import 'fertilizer_signup_page.dart';

/// Direct fertilizer login — phone + password (role comes from the phone).
class FertilizerLoginPage extends StatefulWidget {
  const FertilizerLoginPage({super.key, this.account});

  /// Optional: when opened from an old role card. Direct home login leaves this null.
  final FertDemoAccount? account;

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
    final a = widget.account;
    _phoneController = TextEditingController(
      text: a == null ? '' : a.phone.replaceFirst(RegExp(r'^0'), ''),
    );
    _passwordController = TextEditingController(
      text: FertilizerDemoAuth.passwordHint,
    );
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
      final expected = widget.account?.role;

      try {
        user = await AuthService.login(
          phone: _phoneController.text,
          password: _passwordController.text,
        );
        if (expected != null &&
            user.role != expected &&
            !(expected == 'FERTILIZER_SUPPLIER' &&
                user.role == 'SERVICE_PROVIDER')) {
          await AuthService.logout();
          throw const ApiException(
            'This phone is registered as a different role.',
          );
        }
      } on ApiException {
        user = FertilizerDemoAuth.tryLogin(
          phone: _phoneController.text,
          password: _passwordController.text,
          expectedRole: expected,
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
        if (a != null && Navigator.of(context).canPop()) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            ),
          ),
          const SizedBox(height: 12),
        ],
        AuthHeading(
          title: 'Welcome Back',
          subtitle: a == null
              ? 'Sign in with your phone · KapConnect fertilizer'
              : 'Sign in as ${a.roleLabel} · ${a.name}',
        ),
        if (a != null) ...[
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
        ],
        const SizedBox(height: 20),
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
                const SizedBox(height: 18),
                AuthPrimaryButton(
                  label: _loading ? 'Logging in...' : 'Login',
                  onPressed: _loading ? null : _submit,
                ),
                const SizedBox(height: 12),
                AuthSecondaryAction(
                  icon: Icons.flash_on_outlined,
                  label: 'Quick land demo login',
                  onTap: _loading
                      ? () {}
                      : () {
                          _phoneController.text = '711000001';
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
                builder: (_) => FertilizerSignupPage(
                  lockedRole: a ?? FertilizerDemoAuth.accounts.first,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

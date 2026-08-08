import 'package:flutter/material.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'buyer/buyer_categories_page.dart';
import 'buyer/marketplace_page.dart';
import 'buyer/estate_owner_request_page.dart';
import 'buyer/buyer_negotiation_page.dart';

/// Demo launcher - lets every screen on this branch be opened directly,
/// for showing the work without walking the full navigation flow.
class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          height: double.infinity,
          color: const Color(0xFFFDF9F1),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CocoConnect',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Screens by Senuji',
                    style: TextStyle(fontSize: 13, color: Color(0xFF777777)),
                  ),

                  const SizedBox(height: 26),

                  const _GroupLabel(text: 'AUTHENTICATION'),
                  const SizedBox(height: 10),
                  _DemoTile(
                    icon: Icons.login,
                    title: 'Login',
                    subtitle: 'Phone number + password',
                    color: const Color(0xFF2E7D32),
                    onTap: () => _open(context, const LoginPage()),
                  ),
                  _DemoTile(
                    icon: Icons.person_add_alt,
                    title: 'Sign Up',
                    subtitle: 'Create account with role',
                    color: const Color(0xFF2E7D32),
                    onTap: () => _open(context, const SignupPage()),
                  ),

                  const SizedBox(height: 22),

                  const _GroupLabel(text: 'BUYER'),
                  const SizedBox(height: 10),
                  _DemoTile(
                    icon: Icons.grid_view,
                    title: 'Buying Categories',
                    subtitle: 'Start of the buyer flow',
                    color: const Color(0xFFB26A2C),
                    onTap: () => _open(context, const BuyerCategoriesPage()),
                  ),
                  _DemoTile(
                    icon: Icons.storefront,
                    title: 'Marketplace',
                    subtitle: 'Request form + nearby listings',
                    color: const Color(0xFFB26A2C),
                    onTap: () => _open(context, const MarketplacePage()),
                  ),
                  _DemoTile(
                    icon: Icons.description_outlined,
                    title: 'Estate Owner Request',
                    subtitle: 'Full request detail',
                    color: const Color(0xFFB26A2C),
                    onTap: () =>
                        _open(context, const EstateOwnerRequestPage()),
                  ),
                  _DemoTile(
                    icon: Icons.forum_outlined,
                    title: 'Negotiation',
                    subtitle: 'Offer thread + actions',
                    color: const Color(0xFFB26A2C),
                    onTap: () => _open(context, const BuyerNegotiationPage()),
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'Tip: the buyer flow also links together - open '
                    'Buying Categories and tap through Coconuts.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.45,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.1,
        color: Color(0xFF999999),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DemoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 13),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFFAAAAAA),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

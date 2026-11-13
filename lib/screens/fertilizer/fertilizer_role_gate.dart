import 'package:flutter/material.dart';
import '../../services/fertilizer_demo_auth.dart';
import '../../theme/app_theme.dart';
import 'fertilizer_login_page.dart';

/// Pick who you are, then open that role’s login (same look as the app screenshots).
class FertilizerRoleGate extends StatelessWidget {
  const FertilizerRoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Material(
            color: AppColors.cream,
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                children: [
                  Text(
                    'KapConnect',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fertilizer login',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose a role. Each login uses phone + password. '
                    'Orders stay in one shared demo store so data syncs when you switch.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Demo password for every role: demo123',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final a in FertilizerDemoAuth.accounts) ...[
                    _RoleCard(account: a),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.account});
  final FertDemoAccount account;

  IconData get _icon {
    switch (account.role) {
      case 'ESTATE_OWNER':
        return Icons.home_work_outlined;
      case 'FERTILIZER_SUPPLIER':
        return Icons.storefront_outlined;
      case 'CDO':
        return Icons.account_balance_outlined;
      case 'REGIONAL_MANAGER':
        return Icons.map_outlined;
      case 'CHAIRMAN':
        return Icons.apartment_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FertilizerLoginPage(account: account),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: AppColors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.roleLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.blurb,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phone ${account.phone}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

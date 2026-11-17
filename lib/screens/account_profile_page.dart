import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/profile_widgets.dart';
import 'account_dialogs.dart';

/// Account profile for roles without a dedicated activity summary.
class AccountProfilePage extends StatefulWidget {
  const AccountProfilePage({super.key});

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  Future<void> _edit() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final saved = await showThemedDialog<bool>(
      context: context,
      builder: (_) => EditProfileDialog(user: user),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return BuyerScaffold(
      bottomNavigation: const SizedBox.shrink(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, color: kBuyerGreen),
            ),
          ),
          const ProfileTitle(),
          const SizedBox(height: 16),
          if (user != null)
            ProfileIdentityCard(
              name: user.name,
              role: roleLabel(user.role),
              phone: user.phone,
              location: user.location,
            ),
          const SizedBox(height: 18),
          const ProfileSectionLabel('ACCOUNT'),
          const SizedBox(height: 8),
          ProfileAccountCard(
            onEdit: user == null ? null : _edit,
            showLogout: user != null,
          ),
        ],
      ),
    );
  }
}

void openAccountProfile(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AccountProfilePage()));
}

import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/buyer_service.dart';
import '../../widgets/buyer_widgets.dart';
import '../account_dialogs.dart';
import '../../widgets/app_bottom_nav.dart';

/// Opens the profile from any buyer screen's PROFILE tab, on top of
/// Buying Categories rather than stacking copies.
void openBuyerProfile(BuildContext context) {
  final NavigatorState navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  navigator.push(
    MaterialPageRoute(builder: (context) => const BuyerProfilePage()),
  );
}

class BuyerProfilePage extends StatefulWidget {
  const BuyerProfilePage({super.key});

  @override
  State<BuyerProfilePage> createState() => _BuyerProfilePageState();
}

class _BuyerProfilePageState extends State<BuyerProfilePage> {
  late Future<BuyerSummary> _summary = BuyerService.getSummary();

  Future<void> _reload() async {
    final Future<BuyerSummary> next = BuyerService.getSummary();
    setState(() {
      _summary = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown in the stats area.
    }
  }

  Future<void> _editProfile(AppUser user) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
    // AuthService.currentUser is already updated; redraw the header.
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = AuthService.currentUser;

    return BuyerScaffold(
      bottomNavigation: const AppBottomNav(current: AppTab.profile),
      body: RefreshIndicator(
        color: kBuyerGreen,
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            if (user != null) _IdentityCard(user: user),
            const SizedBox(height: 18),
            const _SectionLabel('MY ACTIVITY'),
            const SizedBox(height: 8),
            FutureBuilder<BuyerSummary>(
              future: _summary,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox(
                    height: 150,
                    child: Center(
                      child: CircularProgressIndicator(color: kBuyerGreen),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  final Object error = snapshot.error!;
                  return BuyerCard(
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_outlined, color: kBuyerGrey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error is ApiException
                                ? error.message
                                : 'Could not load your activity',
                            style: const TextStyle(color: kBuyerGrey),
                          ),
                        ),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                return _StatsGrid(summary: snapshot.data!);
              },
            ),
            const SizedBox(height: 18),
            const _SectionLabel('ACCOUNT'),
            const SizedBox(height: 8),
            BuyerCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.edit_outlined,
                    label: 'Edit profile',
                    subtitle: 'Name and location',
                    onTap: user == null ? null : () => _editProfile(user),
                  ),
                  const Divider(height: 1, indent: 56, color: kBuyerBorder),
                  _ActionRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'My Orders',
                    subtitle: 'Pending orders, deals and transactions',
                    onTap: () => openTab(context, AppTab.orders),
                  ),
                  const Divider(height: 1, indent: 56, color: kBuyerBorder),
                  _ActionRow(
                    icon: Icons.logout,
                    label: 'Log out',
                    color: const Color(0xFFC62828),
                    onTap: () => confirmLogOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final AppUser user;

  const _IdentityCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final String? location = user.location;

    return BuyerCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kBuyerGreen,
              shape: BoxShape.circle,
            ),
            child: Text(
              initialsOf(user.name),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 6),
                BuyerPill(
                  text: roleLabel(user.role).toUpperCase(),
                  background: const Color(0xFFDDEEE0),
                  foreground: kBuyerGreen,
                ),
                const SizedBox(height: 10),
                _InfoLine(icon: Icons.phone_outlined, text: user.phone),
                const SizedBox(height: 4),
                _InfoLine(
                  icon: Icons.location_on_outlined,
                  text: location == null || location.isEmpty
                      ? 'No location added'
                      : location,
                  muted: location == null || location.isEmpty,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;

  const _InfoLine({required this.icon, required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: kBuyerGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: muted ? const Color(0xFFAAAAAA) : const Color(0xFF3A3A3A),
              fontStyle: muted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final BuyerSummary summary;

  const _StatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: summary.openRequests,
                label: 'Open requests',
                icon: Icons.post_add,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                value: summary.openChats,
                label: 'Open negotiations',
                icon: Icons.forum_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                value: summary.ordersActive,
                label: 'Orders to collect',
                icon: Icons.local_shipping_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                value: summary.ordersCompleted,
                label: 'Completed orders',
                icon: Icons.check_circle_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return BuyerCard(
      onTap: () => openTab(context, AppTab.orders),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kBuyerBrown),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: kBuyerGrey)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: kBuyerGrey,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    this.color = const Color(0xFF1A1A1A),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: color == const Color(0xFF1A1A1A) ? kBuyerGreen : color,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: kBuyerGrey),
            ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFFBBBBBB)),
    );
  }
}

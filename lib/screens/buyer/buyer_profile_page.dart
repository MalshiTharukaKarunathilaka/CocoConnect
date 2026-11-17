import '../../widgets/profile_widgets.dart';
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
            const ProfileSectionLabel('MY ACTIVITY'),
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
            const ProfileSectionLabel('ACCOUNT'),
            const SizedBox(height: 8),
            ProfileAccountCard(
              onEdit: user == null ? null : () => _editProfile(user),
              actions: [
                ProfileActionRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'My Orders',
                  subtitle: 'Pending orders, deals and transactions',
                  onTap: () => openTab(context, AppTab.orders),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final BuyerSummary summary;

  const _StatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ProfileStatsGrid(
      children: [
        ProfileStatTile(
          value: '${summary.openRequests}',
          label: 'Open requests',
          icon: Icons.post_add,
          onTap: () => openTab(context, AppTab.orders),
        ),
        ProfileStatTile(
          value: '${summary.openChats}',
          label: 'Open negotiations',
          icon: Icons.forum_outlined,
          onTap: () => openTab(context, AppTab.orders),
        ),
        ProfileStatTile(
          value: '${summary.ordersActive}',
          label: 'Orders to collect',
          icon: Icons.shopping_basket_outlined,
          onTap: () => openTab(context, AppTab.orders),
        ),
        ProfileStatTile(
          value: '${summary.ordersCompleted}',
          label: 'Completed orders',
          icon: Icons.check_circle_outline,
          onTap: () => openTab(context, AppTab.orders),
        ),
      ],
    );
  }
}

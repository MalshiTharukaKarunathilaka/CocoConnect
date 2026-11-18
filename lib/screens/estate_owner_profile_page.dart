import '../widgets/profile_widgets.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/owner_service.dart';
import 'account_dialogs.dart';
import '../theme/app_theme.dart';

const Color _darkGreen = Color(0xFF1F6B3D);
const Color _ink = Color(0xFF222222);
const Color _muted = Color(0xFF6B6B6B);

class EstateOwnerProfilePage extends StatefulWidget {
  const EstateOwnerProfilePage({super.key});

  @override
  State<EstateOwnerProfilePage> createState() => _EstateOwnerProfilePageState();
}

class _EstateOwnerProfilePageState extends State<EstateOwnerProfilePage> {
  late Future<OwnerSummary> _summary = OwnerService.getSummary();

  Future<void> _reload() async {
    final Future<OwnerSummary> next = OwnerService.getSummary();
    setState(() {
      _summary = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _editEstate(Estate estate, {EstateField? focus}) async {
    final bool? saved = await showThemedDialog<bool>(
      context: context,
      builder: (context) => EditEstateDialog(
        estate: estate,
        focus: focus,
        fallbackLocation: AuthService.currentUser?.location,
      ),
    );
    if (saved == true) _reload();
  }

  Future<void> _editAccount() async {
    final AppUser? user = AuthService.currentUser;
    if (user == null) return;
    final bool? saved = await showThemedDialog<bool>(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => BuyerScaffold(
    bottomNavigation: const AppBottomNav(current: AppTab.profile),
    body: RefreshIndicator(
      color: _darkGreen,
      onRefresh: _reload,
      child: FutureBuilder<OwnerSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(child: CircularProgressIndicator(color: _darkGreen)),
              ],
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error!;
            return _ErrorView(
              message: error is ApiException
                  ? error.message
                  : 'Could not load your profile',
              onRetry: _reload,
            );
          }
          return _buildProfile(snapshot.data!);
        },
      ),
    ),
  );

  Widget _buildProfile(OwnerSummary summary) {
    final Estate estate = summary.estate;
    final AppUser? user = AuthService.currentUser;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const ProfileTitle(),
        const SizedBox(height: 16),
        ProfileIdentityCard(
          name: user?.name ?? estate.ownerName,
          role: 'Land Owner',
          phone: user?.phone ?? '',
          location: user?.location ?? estate.location,
        ),
        const SizedBox(height: 18),
        const ProfileSectionLabel('MY ACTIVITY'),
        const SizedBox(height: 8),
        ProfileStatsGrid(
          children: [
            ProfileStatTile(
              value: '${summary.activeListings}',
              label: 'Active listings',
              icon: Icons.storefront_outlined,
            ),
            ProfileStatTile(
              value: '${summary.openChats}',
              label: 'Open chats',
              icon: Icons.forum_outlined,
            ),
            ProfileStatTile(
              value: '${summary.ordersCompleted}',
              label: 'Completed orders',
              icon: Icons.check_circle_outline,
            ),
          ],
        ),
        if (summary.offersWaiting > 0 || summary.ordersActive > 0) ...[
          const SizedBox(height: 8),
          _Banner(
            text: [
              if (summary.offersWaiting > 0)
                '${summary.offersWaiting} offer'
                    '${summary.offersWaiting == 1 ? '' : 's'} waiting for a '
                    'buyer',
              if (summary.ordersActive > 0)
                '${summary.ordersActive} order'
                    '${summary.ordersActive == 1 ? '' : 's'} in progress',
            ].join('  ·  '),
            onTap: () => Navigator.pushNamed(context, '/owner-activity'),
          ),
        ],
        const SizedBox(height: 10),

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trust Score',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                summary.averageRating == null
                    ? 'Not rated yet'
                    : '${summary.averageRating!.toStringAsFixed(1)} / 5.0',
                style: const TextStyle(
                  fontSize: 24,
                  color: _darkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${summary.ratingCount} received rating${summary.ratingCount == 1 ? '' : 's'} across completed workflows',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 8),
              const Text(
                'Every received rating counts equally. Unrated work does not lower your score.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              for (final source in summary.ratingSources) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(source.label)),
                    Text(
                      source.averageRating == null
                          ? 'Not rated yet'
                          : '${source.averageRating!.toStringAsFixed(1)} / 5 (${source.ratingCount})',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Estate details
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Land Details',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _editEstate(estate),
                    child: const Text(
                      'Edit',
                      style: TextStyle(
                        color: _darkGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              EstateDetailItem(
                icon: Icons.storefront_outlined,
                title: 'Land Name',
                value: estate.estateName,
                onTap: () => _editEstate(estate, focus: EstateField.name),
              ),
              const SizedBox(height: 12),
              EstateDetailItem(
                icon: Icons.location_on_outlined,
                title: 'Location',
                // The estate's own location, otherwise the one on the account.
                value: (estate.location ?? '').trim().isNotEmpty
                    ? estate.location!
                    : (AuthService.currentUser?.location ?? ''),
                note:
                    (estate.location ?? '').trim().isEmpty &&
                        (AuthService.currentUser?.location ?? '')
                            .trim()
                            .isNotEmpty
                    ? 'from your account. Tap to save it on your land'
                    : null,
                onTap: () => _editEstate(estate, focus: EstateField.location),
              ),
              const SizedBox(height: 12),
              EstateDetailItem(
                icon: Icons.terrain_outlined,
                title: 'Total Land Area',
                value: estate.totalLandArea ?? '',
                onTap: () => _editEstate(estate, focus: EstateField.area),
              ),
              const SizedBox(height: 12),
              EstateDetailItem(
                icon: Icons.eco_outlined,
                title: 'Primary Crop',
                value: estate.primaryCrop ?? '',
                onTap: () => _editEstate(estate, focus: EstateField.crop),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const ProfileSectionLabel('ACCOUNT'),
        const SizedBox(height: 8),
        ProfileAccountCard(
          onEdit: _editAccount,
          actions: [
            ProfileActionRow(
              icon: Icons.receipt_long_outlined,
              label: 'My Orders',
              subtitle: 'Pending orders, deals and transactions',
              onTap: () => Navigator.pushNamed(context, '/owner-activity'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return BuyerCard(child: child);
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _Banner({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 17,
              color: _darkGreen,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  color: _darkGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: _darkGreen),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 20),
      children: [
        const Icon(Icons.cloud_off_outlined, size: 34, color: _muted),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted),
        ),
        Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
            style: TextButton.styleFrom(foregroundColor: _darkGreen),
          ),
        ),
        // Never leave the user stuck on an account that can't load.
        Center(
          child: TextButton.icon(
            onPressed: () => confirmLogOut(context),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Log out'),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
        ),
      ],
    );
  }
}

class EstateDetailItem extends StatelessWidget {
  final IconData icon;
  final String title;

  /// Empty shows a muted "Tap to add".
  final String value;

  /// A small line under the value, e.g. where it came from.
  final String? note;

  /// Tapping the row edits this detail.
  final VoidCallback? onTap;

  const EstateDetailItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool empty = value.trim().isEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF7A837A), size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF4A4A4A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    empty ? 'Tap to add' : value,
                    style: TextStyle(
                      color: empty ? const Color(0xFFAAAAAA) : _ink,
                      fontSize: 13,
                      fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                  if (note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note!,
                        style: const TextStyle(
                          color: Color(0xFFB26A2C),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 6, top: 2),
                child: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: Color(0xFF9AA39A),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

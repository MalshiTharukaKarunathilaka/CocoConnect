import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/owner_service.dart';
import '../widgets/reusable_widgets.dart';
import 'account_dialogs.dart';

const Color _darkGreen = Color(0xFF1F6B3D);
const Color _ink = Color(0xFF222222);
const Color _muted = Color(0xFF6B6B6B);
const Color _cardBorder = Color(0xFFE4E4E4);

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

  Future<void> _editEstate(Estate estate) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => EditEstateDialog(estate: estate),
    );
    if (saved == true) _reload();
  }

  Future<void> _editAccount() async {
    final AppUser? user = AuthService.currentUser;
    if (user == null) return;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
    if (saved == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          height: double.infinity,
          color: const Color(0xFFFCF8EF),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCF8EF),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE8E2D6)),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1B5E20),
                          size: 21,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'KapConnect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Text(
                        'EN | SI | TA',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    color: _darkGreen,
                    onRefresh: _reload,
                    child: FutureBuilder<OwnerSummary>(
                      future: _summary,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(color: _darkGreen),
                          );
                        }
                        if (snapshot.hasError) {
                          final Object error = snapshot.error!;
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
                ),

                const CustomBottomNavigation(currentIndex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(OwnerSummary summary) {
    final Estate estate = summary.estate;
    final AppUser? user = AuthService.currentUser;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      children: [
        // Identity
        Center(
          child: Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3F8B5F),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              initialsOf(estate.estateName),
              style: const TextStyle(
                color: Color(0xFFD5F5D8),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          estate.estateName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          estate.location == null || estate.location!.isEmpty
              ? 'Estate Owner  ·  ${estate.ownerName}'
              : '${estate.ownerName}  ·  ${estate.location}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => _editEstate(estate),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text(
                    'Edit Estate',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/owner-activity'),
                  icon: const Icon(Icons.receipt_long, size: 17),
                  label: const Text(
                    'Buyers & Orders',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _darkGreen,
                    side: const BorderSide(color: _darkGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stats
        Row(
          children: [
            Expanded(
              child: ProfileStatCard(
                number: '${summary.activeListings}',
                label: 'Active\nListings',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ProfileStatCard(
                number: '${summary.openChats}',
                label: 'Open\nChats',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ProfileStatCard(
                number: '${summary.ordersCompleted}',
                label: 'Completed\nOrders',
              ),
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
                    '${summary.ordersActive == 1 ? '' : 's'} awaiting pickup',
            ].join('  ·  '),
            onTap: () => Navigator.pushNamed(context, '/owner-activity'),
          ),
        ],
        const SizedBox(height: 10),

        // Trust score
        _Card(
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFFFB175),
                child: Icon(Icons.star, color: Color(0xFF6B3B1C), size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trust Score',
                      style: TextStyle(
                        fontSize: 16,
                        color: _ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      estate.trustScore == null
                          ? 'Builds up as buyers complete orders with you'
                          : 'From buyers who completed orders',
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              estate.trustScore == null
                  ? const Text(
                      'New',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFB26A2C),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Column(
                      children: [
                        Text(
                          estate.trustScore!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFFB26A2C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          '/ 5.0',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
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
                      'Estate Details',
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
                icon: Icons.location_on_outlined,
                title: 'Location',
                value: estate.location ?? '',
              ),
              const SizedBox(height: 12),
              EstateDetailItem(
                icon: Icons.terrain_outlined,
                title: 'Total Land Area',
                value: estate.totalLandArea ?? '',
              ),
              const SizedBox(height: 12),
              EstateDetailItem(
                icon: Icons.eco_outlined,
                title: 'Primary Crop',
                value: estate.primaryCrop ?? '',
              ),
              const SizedBox(height: 12),
              EstateDetailItem(
                icon: Icons.calendar_month_outlined,
                title: 'Year Established',
                value: estate.yearEstablished?.toString() ?? '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Account
        _Card(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline, color: _darkGreen),
                title: Text(
                  user?.name ?? estate.ownerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                subtitle: Text(
                  '${user?.phone ?? ''}  ·  Estate Owner',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                trailing: TextButton(
                  onPressed: _editAccount,
                  style: TextButton.styleFrom(foregroundColor: _darkGreen),
                  child: const Text('Edit'),
                ),
              ),
              const Divider(height: 1, indent: 56, color: _cardBorder),
              ListTile(
                onTap: () => confirmLogOut(context),
                leading: const Icon(Icons.logout, color: Color(0xFFC62828)),
                title: const Text(
                  'Log out',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
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
      ],
    );
  }
}

class ProfileStatCard extends StatelessWidget {
  final String number;
  final String label;

  const ProfileStatCard({super.key, required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 21,
                color: _ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EstateDetailItem extends StatelessWidget {
  final IconData icon;
  final String title;

  /// Empty shows a muted "Not added yet".
  final String value;

  const EstateDetailItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bool empty = value.trim().isEmpty;

    return Row(
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
                empty ? 'Not added yet' : value,
                style: TextStyle(
                  color: empty ? const Color(0xFFAAAAAA) : _ink,
                  fontSize: 13,
                  fontStyle: empty ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

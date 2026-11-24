import 'package:flutter/material.dart';
import '../screens/account_dialogs.dart';
import 'buyer_widgets.dart';

/// Shared profile design, based on the buyer account page.
class ProfileTitle extends StatelessWidget {
  const ProfileTitle({super.key});

  @override
  Widget build(BuildContext context) => const Text(
    'Profile',
    style: TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.bold,
      color: Color(0xFF1A1A1A),
    ),
  );
}

class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.name,
    required this.role,
    required this.phone,
    this.location,
  });

  final String name;
  final String role;
  final String phone;
  final String? location;

  @override
  Widget build(BuildContext context) => BuyerCard(
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: kBuyerGreen,
          child: Text(
            initialsOf(name),
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
                name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDEEE0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: kBuyerGreen,
                    letterSpacing: .3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _ProfileInfo(icon: Icons.phone_outlined, text: phone),
              const SizedBox(height: 4),
              _ProfileInfo(
                icon: Icons.location_on_outlined,
                text: (location ?? '').trim().isEmpty
                    ? 'No location added'
                    : location!,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: kBuyerGrey),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: Color(0xFF3A3A3A)),
        ),
      ),
    ],
  );
}

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: kBuyerGrey,
      letterSpacing: .6,
    ),
  );
}

class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.color = const Color(0xFF1A1A1A),
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
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

class ProfileAccountCard extends StatelessWidget {
  const ProfileAccountCard({
    super.key,
    required this.onEdit,
    this.actions = const [],
    this.showLogout = true,
  });
  final VoidCallback? onEdit;
  final List<Widget> actions;
  final bool showLogout;
  @override
  Widget build(BuildContext context) => BuyerCard(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        ProfileActionRow(
          icon: Icons.edit_outlined,
          label: 'Edit profile',
          subtitle: 'Name and location',
          onTap: onEdit,
        ),
        for (final action in actions) ...[
          const Divider(height: 1, indent: 56, color: kBuyerBorder),
          action,
        ],
        if (showLogout) ...[
          const Divider(height: 1, indent: 56, color: kBuyerBorder),
          ProfileActionRow(
            icon: Icons.logout,
            label: 'Log out',
            color: const Color(0xFFC62828),
            onTap: () => confirmLogOut(context),
          ),
        ],
      ],
    ),
  );
}

class ProfileStatTile extends StatelessWidget {
  const ProfileStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
  });
  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => BuyerCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: kBuyerBrown),
        const SizedBox(height: 10),
        Text(
          value,
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

class ProfileStatsGrid extends StatelessWidget {
  const ProfileStatsGrid({super.key, required this.children});
  final List<ProfileStatTile> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 260 ? 2 : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final tile in children) SizedBox(width: width, child: tile),
        ],
      );
    },
  );
}

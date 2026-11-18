import 'package:flutter/material.dart';
import 'app_bottom_nav.dart';

class DashboardHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool centered;

  const DashboardHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: color,
            fontSize: 18,
            height: 1.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(color: Color(0xFF777777), fontSize: 10),
        ),
      ],
    );
  }
}

class DashboardCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? iconWidget;
  final VoidCallback? onTap;

  const DashboardCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.iconWidget,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF3F3F3),
                  child: iconWidget ?? Icon(icon, color: iconColor, size: 22),
                ),

                const SizedBox(height: 8),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8A8A8A), fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CoconutProductCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String? imageAsset;
  final String? unitLabel;
  final VoidCallback? onTap;

  const CoconutProductCard({
    super.key,
    required this.title,
    required this.imageUrl,
    this.imageAsset,
    this.unitLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
                child: Image(
                  image: imageAsset != null
                      ? AssetImage(imageAsset!)
                      : NetworkImage(imageUrl) as ImageProvider,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFFE8F5E9),
                    child: const Center(
                      child: Icon(
                        Icons.image,
                        size: 32,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: Color(0xFF2E7D32),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (unitLabel != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        unitLabel!,
                        style: const TextStyle(
                          color: Color(0xFF64705F),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ChatScope chatScope;

  const CustomBottomNavigation({
    super.key,
    required this.currentIndex,
    this.chatScope = ChatScope.all,
  });

  @override
  Widget build(BuildContext context) {
    // Same bar as the buyer side: Dashboard, Orders, Chats, Alerts, Profile.
    return AppBottomNav(
      chatScope: chatScope,
      current: const [
        AppTab.dashboard,
        AppTab.orders,
        AppTab.profile,
      ][currentIndex.clamp(0, 2)],
    );
  }
}

class BottomMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const BottomMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 16 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD9EAD4) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFF777777),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFF777777),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../widgets/owner_widgets.dart';
import '../account_dialogs.dart';

/// The page frame every fertilizer screen uses, so it looks like the rest of
/// the app: the same cream page, the same green centred title with a small
/// grey line under it, and the same back arrow.
class FertPage extends StatelessWidget {
  const FertPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.bottom,
    this.showLogout = false,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? bottom;
  final bool showLogout;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    // Buttons and links are green like everywhere else in the app (the
    // default Material buttons would be purple).
    final ThemeData base = Theme.of(context);
    final ShapeBorder pill = const StadiumBorder();
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(primary: kOwnerGreen),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kOwnerGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: pill as OutlinedBorder,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kOwnerGreen,
            foregroundColor: Colors.white,
            shape: pill as OutlinedBorder,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kOwnerGreen,
            side: const BorderSide(color: kOwnerGreen),
            shape: pill as OutlinedBorder,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: kOwnerGreen),
        ),
      ),
      child: _frame(context),
    );
  }

  Widget _frame(BuildContext context) {
    return OwnerPage(
      bottom: bottom,
      child: Column(
        children: [
          OwnerHeader(
            title: title,
            subtitle: subtitle,
            showBack: showBack,
            actions: [
              if (showLogout)
                IconButton(
                  tooltip: 'Log out',
                  onPressed: () => confirmLogOut(context),
                  icon: const Icon(Icons.logout, color: kOwnerGreen, size: 22),
                ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A bottom bar that looks exactly like the app's main one (Dashboard,
/// Orders, Chats...), for the fertilizer tabs. items are (icon, label).
class FertTabBar extends StatelessWidget {
  const FertTabBar({
    super.key,
    required this.items,
    required this.current,
    required this.onTap,
  });

  final List<(IconData, String)> items;
  final int current;
  final ValueChanged<int> onTap;

  static const Color _green = Color(0xFF256B45);
  static const Color _greenSoft = Color(0xFFDDEEE0);
  static const Color _grey = Color(0xFF7A7A7A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F4EB),
        border: Border(top: BorderSide(color: Color(0xFFE8E2D6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: i == current ? _greenSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        items[i].$1,
                        size: 22,
                        color: i == current ? _green : _grey,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$2,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: items[i].$2.length > 11 ? 9.5 : 10.5,
                        height: 1.1,
                        fontWeight:
                            i == current ? FontWeight.bold : FontWeight.w600,
                        color: i == current ? _green : _grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

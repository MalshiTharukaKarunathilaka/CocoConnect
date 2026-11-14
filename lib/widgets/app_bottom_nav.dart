import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/buyer/buyer_profile_page.dart';
import '../screens/chat/chats_page.dart';
import '../screens/chat/notifications_page.dart';
import '../screens/estate_owner_profile_page.dart';
import '../screens/orders/orders_page.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

const Color _green = Color(0xFF256B45);
const Color _greenSoft = Color(0xFFDDEEE0);
const Color _grey = Color(0xFF7A7A7A);

enum AppTab { dashboard, orders, chats, alerts, profile }

/// Unread chat messages and unseen notifications, shared by every bottom
/// bar on screen and refreshed while one is showing.
class Unread {
  Unread._();

  static final ValueNotifier<({int chats, int alerts})> counts = ValueNotifier((
    chats: 0,
    alerts: 0,
  ));

  static Timer? _timer;
  static int _bars = 0;

  static void _attach() {
    _bars++;
    refresh();
    _timer ??= Timer.periodic(const Duration(seconds: 20), (_) => refresh());
  }

  static void _detach() {
    _bars--;
    if (_bars <= 0) {
      _bars = 0;
      _timer?.cancel();
      _timer = null;
    }
  }

  static Future<void> refresh() async {
    if (AuthService.currentUser == null) return;
    try {
      final chats = await ChatService.getChats();
      final notes = await ChatService.getNotifications();
      final int unseen = await ChatService.unseenCount(notes);
      counts.value = (
        chats: chats.fold(0, (sum, chat) => sum + chat.unreadCount),
        alerts: unseen,
      );
    } catch (_) {
      // Keep the last counts if the server can't be reached.
    }
  }
}

/// Opens one of the main tabs on top of the home screen, so tabs replace
/// each other instead of piling up.
void openTab(BuildContext context, AppTab tab, {int ordersTab = 0}) {
  final NavigatorState navigator = Navigator.of(context);
  final String? role = AuthService.currentUser?.role;
  final Widget? page = switch (tab) {
    AppTab.dashboard => null,
    AppTab.orders => OrdersPage(initialTab: ordersTab),
    AppTab.chats => const ChatsPage(),
    AppTab.alerts => const NotificationsPage(),
    AppTab.profile => switch (role) {
      'BUYER' => const BuyerProfilePage(),
      'ESTATE_OWNER' => const EstateOwnerProfilePage(),
      // Other account types have no profile screen in this build.
      _ => null,
    },
  };
  if (tab == AppTab.profile && page == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'There is no profile screen for ${role ?? 'this'} accounts yet. '
          'Log in with a Buyer or Estate Owner account.',
        ),
      ),
    );
    return;
  }
  navigator.popUntil((route) => route.isFirst);
  if (page != null) {
    navigator.push(MaterialPageRoute(builder: (context) => page));
  }
}

/// Dashboard · Orders · Chats · Alerts · Profile - the same on the buyer and
/// estate owner sides.
class AppBottomNav extends StatefulWidget {
  final AppTab current;

  const AppBottomNav({super.key, required this.current});

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  @override
  void initState() {
    super.initState();
    Unread._attach();
  }

  @override
  void dispose() {
    Unread._detach();
    super.dispose();
  }

  void _go(AppTab tab) {
    if (tab == widget.current) return;
    openTab(context, tab);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F4EB),
        border: Border(top: BorderSide(color: Color(0xFFE8E2D6))),
      ),
      child: ValueListenableBuilder(
        valueListenable: Unread.counts,
        builder: (context, counts, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _item(
              AppTab.dashboard,
              Icons.dashboard_outlined,
              Icons.dashboard,
              'Dashboard',
            ),
            _item(
              AppTab.orders,
              Icons.receipt_long_outlined,
              Icons.receipt_long,
              'Orders',
            ),
            _item(
              AppTab.chats,
              Icons.chat_bubble_outline,
              Icons.chat_bubble,
              'Chats',
              badge: counts.chats,
            ),
            _item(
              AppTab.alerts,
              Icons.notifications_outlined,
              Icons.notifications,
              'Alerts',
              badge: counts.alerts,
            ),
            _item(
              AppTab.profile,
              Icons.person_outline,
              Icons.person,
              'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    AppTab tab,
    IconData icon,
    IconData activeIcon,
    String label, {
    int badge = 0,
  }) {
    final bool active = tab == widget.current;
    final Color color = active ? _green : _grey;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _go(tab),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? _greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: const Color(0xFFD32F2F),
                child: Icon(active ? activeIcon : icon, size: 22, color: color),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

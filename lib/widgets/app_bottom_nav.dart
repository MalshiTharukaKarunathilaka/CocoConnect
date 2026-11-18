import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/buyer/buyer_profile_page.dart';
import '../screens/chat/chats_page.dart';
import '../screens/chat/notifications_page.dart';
import '../screens/estate_owner_profile_page.dart';
import '../screens/orders/orders_page.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/day_job_chat_service.dart';

const Color _green = Color(0xFF256B45);
const Color _greenSoft = Color(0xFFDDEEE0);
const Color _grey = Color(0xFF7A7A7A);

enum AppTab { dashboard, orders, chats, alerts, profile }

enum ChatScope { all, coconut, dayJobs }

bool get supportsMainNavigation =>
    AuthService.currentUser?.role == 'BUYER' ||
    AuthService.currentUser?.role == 'ESTATE_OWNER';

/// Unread chat messages and unseen notifications, shared by every bottom
/// bar on screen and refreshed while one is showing.
class Unread {
  Unread._();

  static final ValueNotifier<
    ({int chats, int coconutChats, int dayJobChats, int alerts})
  >
  counts = ValueNotifier((
    chats: 0,
    coconutChats: 0,
    dayJobChats: 0,
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
      final role = AuthService.currentUser?.role;
      final chats = await ChatService.getChats();
      final dayJobChats = role == 'ESTATE_OWNER' || role == 'WORKER'
          ? await DayJobChatService.getChats()
          : const <DayJobChatSummary>[];
      final notes = await ChatService.getNotifications();
      final int unseen = await ChatService.unseenCount(notes);
      final coconutUnread = chats.fold(
        0,
        (sum, chat) => sum + chat.unreadCount,
      );
      final dayJobUnread = dayJobChats.fold(
        0,
        (sum, chat) => sum + chat.unreadCount,
      );
      counts.value = (
        chats: coconutUnread + dayJobUnread,
        coconutChats: coconutUnread,
        dayJobChats: dayJobUnread,
        alerts: unseen,
      );
    } catch (_) {
      // Keep the last counts if the server can't be reached.
    }
  }
}

/// Opens one of the main tabs on top of the home screen, so tabs replace
/// each other instead of piling up.
void openTab(
  BuildContext context,
  AppTab tab, {
  int ordersTab = 0,
  ChatScope chatScope = ChatScope.all,
}) {
  final NavigatorState navigator = Navigator.of(context);
  final String? role = AuthService.currentUser?.role;
  final Widget? page = switch (tab) {
    AppTab.dashboard => null,
    AppTab.orders => OrdersPage(initialTab: ordersTab),
    AppTab.chats => ChatsPage(scope: chatScope),
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
          'Log in with a Buyer or Land Owner account.',
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
/// land owner sides.
class AppBottomNav extends StatefulWidget {
  final AppTab current;
  final ChatScope chatScope;
  final ValueChanged<AppTab>? onProviderTab;
  final int providerChatCount;
  final int providerAlertCount;

  const AppBottomNav({
    super.key,
    required this.current,
    this.chatScope = ChatScope.all,
    this.onProviderTab,
    this.providerChatCount = 0,
    this.providerAlertCount = 0,
  });

  @override
  State<AppBottomNav> createState() => _AppBottomNavState();
}

class _AppBottomNavState extends State<AppBottomNav> {
  @override
  void initState() {
    super.initState();
    if (widget.onProviderTab == null) Unread._attach();
  }

  @override
  void dispose() {
    if (widget.onProviderTab == null) Unread._detach();
    super.dispose();
  }

  void _go(AppTab tab) {
    final onProviderTab = widget.onProviderTab;
    if (onProviderTab == null) {
      openTab(context, tab, chatScope: widget.chatScope);
    } else {
      onProviderTab(tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        color: widget.onProviderTab == null ? const Color(0xFFF8F4EB) : Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE8E2D6))),
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
            if (widget.onProviderTab == null) _item(
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
              badge: widget.onProviderTab != null ? widget.providerChatCount : switch (widget.chatScope) {
                ChatScope.coconut => counts.coconutChats,
                ChatScope.dayJobs => counts.dayJobChats,
                ChatScope.all => counts.chats,
              },
            ),
            _item(
              AppTab.alerts,
              Icons.notifications_outlined,
              Icons.notifications,
              'Alerts',
              badge: widget.onProviderTab != null ? widget.providerAlertCount : counts.alerts,
            ),
            _item(
              AppTab.profile,
              widget.onProviderTab == null ? Icons.person_outline : Icons.account_circle_outlined,
              widget.onProviderTab == null ? Icons.person : Icons.account_circle,
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
                color: active && widget.onProviderTab == null ? _greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: const Color(0xFFD32F2F),
                child: Icon(active ? activeIcon : icon, size: widget.onProviderTab == null ? 22 : 26, color: color),
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

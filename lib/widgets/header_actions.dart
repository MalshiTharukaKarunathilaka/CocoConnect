import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/chat/chats_page.dart';
import '../screens/chat/notifications_page.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';

/// Bell and chat icons for the top bar, with red badges for unseen
/// notifications and unread chat messages. Refreshes itself while shown.
class HeaderActions extends StatefulWidget {
  final Color color;

  const HeaderActions({super.key, this.color = const Color(0xFF2E7D32)});

  @override
  State<HeaderActions> createState() => _HeaderActionsState();
}

class _HeaderActionsState extends State<HeaderActions> {
  static const Duration _refreshEvery = Duration(seconds: 20);

  int _unseen = 0;
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_refreshEvery, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (AuthService.currentUser == null) return;
    try {
      final chats = await ChatService.getChats();
      final notes = await ChatService.getNotifications();
      final int unseen = await ChatService.unseenCount(notes);
      if (!mounted) return;
      setState(() {
        _unread = chats.fold(0, (sum, chat) => sum + chat.unreadCount);
        _unseen = unseen;
      });
    } catch (_) {
      // Badges are a nicety; keep the last counts if the server is away.
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.currentUser == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BadgeIcon(
          tooltip: 'Notifications',
          icon: Icons.notifications_outlined,
          count: _unseen,
          color: widget.color,
          onTap: () => _open(const NotificationsPage()),
        ),
        _BadgeIcon(
          tooltip: 'Chats',
          icon: Icons.chat_bubble_outline,
          count: _unread,
          color: widget.color,
          onTap: () => _open(const ChatsPage()),
        ),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _BadgeIcon({
    required this.tooltip,
    required this.icon,
    required this.count,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: const Color(0xFFD32F2F),
        child: Icon(icon, size: 23, color: color),
      ),
    );
  }
}

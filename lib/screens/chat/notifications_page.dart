import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/notification_attention.dart';
import '../../widgets/owner_widgets.dart';
import '../../widgets/app_bottom_nav.dart';
import 'chat_page.dart';
import 'chats_page.dart';
import '../estate_owner_calendar_page.dart';
import '../worker_dashboard.dart';
import '../worker_chat_page.dart';

const Color _green = Color(0xFF256B45);
const Color _muted = Color(0xFF6B7280);
const Color _brown = Color(0xFF8B4A1C);

/// Offers from the other side and upcoming orders, for buyers and estate
/// owners alike. Items go away once they're dealt with.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<({Map<String, List<AppNotification>> groups, Set<String> unseen})>
  _items = _load();
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (ModalRoute.of(context)?.isCurrent == true) _reload();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<({Map<String, List<AppNotification>> groups, Set<String> unseen})>
  _load() async {
    final List<AppNotification> items = await ChatService.getNotifications();
    final unseen = await ChatService.unseenNotifications(items);
    if (mounted) Unread.alertAttention.update(unseen);
    return (
      groups: groupNotifications(items, bySender: true),
      unseen: unseen.map((item) => item.key).toSet(),
    );
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _items = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _open(List<AppNotification> group) async {
    final conversations = groupNotifications(group).values;
    if (conversations.length > 1) {
      final selected = await showDialog<List<AppNotification>>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('Messages from ${group.first.senderName}'),
          children: [
            for (final conversation in conversations)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, conversation),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    conversation.first.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    conversation.length == 1
                        ? '1 message'
                        : '${conversation.length} messages',
                  ),
                ),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      group = selected;
    }
    final item = group.first;
    await ChatService.markSeen(group);
    Unread.refresh();
    if (!mounted) return;
    switch (item.type) {
      case NotificationType.offer:
      case NotificationType.chat:
        final chatId = item.negotiationId;
        if (chatId == null) {
          await _reload();
          return;
        }
        await openChat(context, chatId);
        if (mounted) _reload();
      case NotificationType.dayJobChat:
        final chatId = item.dayJobChatId;
        if (chatId == null) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WorkerChatPage(chatId: chatId)),
        );
        if (mounted) _reload();
      case NotificationType.sellOffer:
        // The buyer's request with the land's offer: Pending Orders.
        openTab(context, AppTab.orders, ordersTab: 0);
      case NotificationType.jobCompletionAck:
        final role = AuthService.currentUser?.role;
        if (role == 'ESTATE_OWNER') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EstateOwnerCalendarPage()),
          );
        } else if (role == 'WORKER') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkerDashboard()),
          );
        }
        if (mounted) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      bottom: const AppBottomNav(current: AppTab.alerts),
      child: Column(
        children: [
          const OwnerHeader(title: 'Alerts', subtitle: 'OFFERS & MESSAGES'),
          Expanded(
            child: RefreshIndicator(
              color: _green,
              onRefresh: _reload,
              child: FutureBuilder(
                future: _items,
                builder: (context, snapshot) {
                  if (!snapshot.hasData &&
                      snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: _green),
                    );
                  }
                  if (snapshot.hasError) {
                    final Object error = snapshot.error!;
                    return ListView(
                      children: [
                        OwnerMessage(
                          icon: Icons.cloud_off_outlined,
                          text: error is ApiException
                              ? error.message
                              : 'Could not load notifications',
                          onRetry: _reload,
                        ),
                      ],
                    );
                  }
                  final data = snapshot.data!;
                  final groups = data.groups.entries.toList();
                  if (data.groups.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        OwnerMessage(
                          icon: Icons.notifications_none,
                          text:
                              "You're all caught up. Offers you receive and "
                              'new chat messages show up here.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    itemCount: data.groups.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = groups[index];
                      final group = entry.value;
                      final unseenCount = group
                          .where((item) => data.unseen.contains(item.key))
                          .length;
                      final isDayJobChat =
                          group.first.type == NotificationType.dayJobChat;
                      return _NotificationCard(
                        key: ValueKey(entry.key),
                        groupKey: entry.key,
                        item: group.first,
                        newCount: isDayJobChat && unseenCount > 0
                            ? 1
                            : unseenCount,
                        messageCount: group.first.isChatMessage
                            ? group.length
                            : 0,
                        onTap: () => _open(group),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatefulWidget {
  final String groupKey;
  final AppNotification item;
  final VoidCallback onTap;
  final int newCount;
  final int messageCount;

  const _NotificationCard({
    super.key,
    required this.groupKey,
    required this.item,
    required this.newCount,
    required this.messageCount,
    required this.onTap,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _NotificationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulse();
  }

  void _syncPulse() {
    final attention = Unread.alertAttention;
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final pending = attention.takePulse(widget.groupKey);
    if (reducedMotion || widget.newCount == 0) {
      _pulse.value = 1;
    } else if (pending) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final newCount = widget.newCount;
    final messageCount = widget.messageCount;
    final count = newCount > 0 ? newCount : messageCount;
    final title = messageCount > 0
        ? 'You have $count ${count == 1 ? 'message' : 'messages'} from ${item.senderName}'
        : item.title;
    final (IconData icon, Color color, String label) = switch (item.type) {
      NotificationType.offer => (Icons.local_offer, _brown, 'Offer'),
      NotificationType.sellOffer => (Icons.storefront, _brown, 'Offer'),
      NotificationType.chat ||
      NotificationType.dayJobChat => (Icons.chat_bubble, _green, 'Message'),
      NotificationType.jobCompletionAck => (
        Icons.fact_check_outlined,
        const Color(0xFFD9A441),
        'Acknowledgement',
      ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final wave = math.sin(math.pi * 3 * _pulse.value);
          return Transform.scale(scale: 1 - 0.035 * wave * wave, child: child);
        },
        child: OwnerCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withAlpha(30),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          chatTime(item.at),
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (messageCount == 0 && newCount > 1)
                      Text(
                        '$newCount new updates',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _brown,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: kOwnerInk,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 6, top: 10),
                child: Icon(Icons.chevron_right, color: _muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

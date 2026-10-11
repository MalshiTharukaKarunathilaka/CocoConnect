import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/my_activity_page.dart';
import '../deal_window_page.dart';
import 'chat_page.dart';
import 'chats_page.dart';

const Color _green = Color(0xFF256B45);
const Color _muted = Color(0xFF6B7280);
const Color _red = Color(0xFFC62828);
const Color _brown = Color(0xFF8B4A1C);

/// Offers from the other side and upcoming orders, for buyers and estate
/// owners alike. Items go away once they're dealt with.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _items = _load();

  Future<List<AppNotification>> _load() async {
    final List<AppNotification> items = await ChatService.getNotifications();
    await ChatService.markSeen(items);
    return items;
  }

  Future<void> _reload() async {
    final Future<List<AppNotification>> next = _load();
    setState(() {
      _items = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _open(AppNotification item) async {
    final bool buyer = AuthService.currentUser?.isBuyer ?? false;
    switch (item.type) {
      case NotificationType.offer:
        await openChat(context, item.negotiationId!);
      case NotificationType.sellOffer:
        openMyActivity(context, tab: 0);
        return;
      case NotificationType.delivery:
        if (buyer) {
          openMyActivity(context, tab: 2);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DealWindowPage()),
        );
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(title: 'Notifications'),
          Expanded(
            child: RefreshIndicator(
              color: _green,
              onRefresh: _reload,
              child: FutureBuilder<List<AppNotification>>(
                future: _items,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
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
                  final List<AppNotification> items = snapshot.data!;
                  if (items.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        OwnerMessage(
                          icon: Icons.notifications_none,
                          text:
                              "You're all caught up. Offers you receive and "
                              'orders due in the next week show up here.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) => _NotificationCard(
                      item: items[index],
                      onTap: () => _open(items[index]),
                    ),
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

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (item.type) {
      NotificationType.offer => (Icons.local_offer, _brown, 'Offer'),
      NotificationType.sellOffer => (Icons.storefront, _brown, 'Offer'),
      NotificationType.delivery => (
        Icons.local_shipping,
        item.urgent ? _red : _green,
        'Upcoming order',
      ),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
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
                      if (item.type != NotificationType.delivery)
                        Text(
                          chatTime(item.at),
                          style: const TextStyle(fontSize: 11, color: _muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
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
    );
  }
}

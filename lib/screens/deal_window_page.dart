import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/owner_service.dart';
import '../widgets/header_actions.dart';
import '../widgets/owner_widgets.dart';
import '../widgets/reusable_widgets.dart';
import 'buyer/buyer_format.dart';
import 'buyer/coconut_type.dart';
import 'complete_deal_page.dart';
import 'chat/chat_page.dart';
import 'order_status_page.dart';

/// Estate owner's Orders tab: every deal made on their listings or offers,
/// with delivery dates, and the way to complete each one.
class DealWindowPage extends StatefulWidget {
  const DealWindowPage({super.key});

  @override
  State<DealWindowPage> createState() => _DealWindowPageState();
}

class _DealWindowPageState extends State<DealWindowPage> {
  late Future<List<Deal>> _deals = OwnerService.getDeals();
  int _tab = 0;
  bool _bannerClosed = false;

  Future<void> _reload() async {
    final Future<List<Deal>> next = OwnerService.getDeals();
    setState(() {
      _deals = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  static bool _dueSoon(Deal deal) {
    final int? days = deal.daysUntilDue;
    return !deal.isCompleted && days != null && days <= 1;
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    _reload();
  }

  Future<void> _complete(Deal deal) async {
    if (await openCompleteDeal(context, deal.id)) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      bottom: const CustomBottomNavigation(currentIndex: 1),
      child: Column(
        children: [
          OwnerHeader(
            title: 'Deal Window',
            subtitle: 'ORDERS & DELIVERIES',
            actions: [
              const HeaderActions(color: kOwnerGreen),
              IconButton(
                tooltip: 'My sell requests',
                icon: const Icon(Icons.assignment_outlined, color: kOwnerGreen),
                onPressed: () => _open(const OrderStatusPage()),
              ),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<Deal>>(
              future: _deals,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: kOwnerGreen),
                  );
                }
                if (snapshot.hasError) {
                  final Object error = snapshot.error!;
                  return _scrollable([
                    OwnerMessage(
                      icon: Icons.cloud_off_outlined,
                      text: error is ApiException
                          ? error.message
                          : 'Could not load deals',
                      onRetry: _reload,
                    ),
                  ]);
                }
                return _buildDeals(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollable(List<Widget> children) {
    return RefreshIndicator(
      color: kOwnerGreen,
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        children: children,
      ),
    );
  }

  Widget _buildDeals(List<Deal> all) {
    final List<Deal> dueSoon = all.where(_dueSoon).toList();
    final List<Deal> upcoming = all
        .where((deal) => !deal.isCompleted && !_dueSoon(deal))
        .toList();
    final List<Deal> shown = switch (_tab) {
      1 => dueSoon,
      2 => upcoming,
      _ => all,
    };
    final int scheduled = all.where((deal) => !deal.isCompleted).length;

    return _scrollable([
      const SizedBox(height: 14),
      OwnerTabs(
        labels: const ['All Deals', 'Due Tomorrow', 'Upcoming'],
        badges: [0, dueSoon.length, 0],
        selected: _tab,
        onSelected: (index) => setState(() => _tab = index),
      ),
      if (dueSoon.isNotEmpty && !_bannerClosed)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _DueBanner(
            count: dueSoon.length,
            onClose: () => setState(() => _bannerClosed = true),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Text(
          'SCHEDULED DELIVERIES ($scheduled)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: kOwnerMuted,
          ),
        ),
      ),
      if (shown.isEmpty)
        OwnerMessage(
          icon: Icons.local_shipping_outlined,
          text: switch (_tab) {
            1 => 'Nothing due today or tomorrow.',
            2 => 'No upcoming deliveries.',
            _ =>
              'No deals yet. Deals appear when you accept a buyer\'s offer '
                  'in a chat, or a buyer accepts one of your offers.',
          },
        ),
      for (final Deal deal in shown)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: _DealCard(
            deal: deal,
            onComplete: () => _complete(deal),
            onChat: deal.negotiationId == null
                ? null
                : () => _open(ChatPage(chatId: deal.negotiationId!)),
          ),
        ),
    ]);
  }
}

class _DueBanner extends StatelessWidget {
  final int count;
  final VoidCallback onClose;

  const _DueBanner({required this.count, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C2C2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: kOwnerRed, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 delivery due by tomorrow'
                      : '$count deliveries due by tomorrow',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: kOwnerRed,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Prepare the nuts and complete each deal once delivered.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7A3B3B)),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: kOwnerRed),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  final Deal deal;
  final VoidCallback onComplete;
  final VoidCallback? onChat;

  const _DealCard({required this.deal, required this.onComplete, this.onChat});

  OwnerPill get _pill {
    if (deal.isCompleted) {
      return const OwnerPill('Completed', icon: Icons.check_circle_outline);
    }
    final int? days = deal.daysUntilDue;
    if (days != null && days < 0) {
      return const OwnerPill(
        'Overdue',
        icon: Icons.error_outline,
        tone: PillTone.red,
      );
    }
    if (days == 0) {
      return const OwnerPill(
        'Due Today',
        icon: Icons.schedule,
        tone: PillTone.red,
      );
    }
    if (days == 1) {
      return const OwnerPill(
        'Due Tomorrow',
        icon: Icons.schedule,
        tone: PillTone.red,
      );
    }
    return const OwnerPill('Confirmed', icon: Icons.verified_outlined);
  }

  @override
  Widget build(BuildContext context) {
    final int? days = deal.daysUntilDue;
    final bool urgent = !deal.isCompleted && days != null && days <= 1;
    final CoconutType type = CoconutType.fromCode(deal.productType);

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${deal.reference}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: kOwnerMuted,
                  ),
                ),
              ),
              _pill,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            deal.buyerName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: kOwnerInk,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(type.icon, size: 15, color: type.iconColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  [
                    type.label,
                    if (deal.buyerLocation != null &&
                        deal.buyerLocation!.isNotEmpty)
                      deal.buyerLocation!,
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          QuantityPriceBox(
            quantity: deal.deliveredQuantity ?? deal.quantity,
            pricePerUnit: deal.deliveredPrice ?? deal.pricePerUnit,
          ),
          if (deal.isCompleted && deal.deliveredQuantity != null) ...[
            const SizedBox(height: 6),
            Text(
              'Agreed ${withCommas(deal.quantity)} nuts at '
              '${rupees(deal.pricePerUnit)}  ·  delivered '
              '${shortDate(deal.completedAt)}',
              style: const TextStyle(fontSize: 11.5, color: kOwnerMuted),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: urgent ? kOwnerRed : kOwnerMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  deal.dueDate == null
                      ? 'No delivery date set'
                      : 'Due ${shortDate(deal.dueDate)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: urgent ? FontWeight.bold : FontWeight.normal,
                    color: urgent ? kOwnerRed : kOwnerMuted,
                  ),
                ),
              ),
              const Text(
                'Total  ',
                style: TextStyle(fontSize: 12, color: kOwnerMuted),
              ),
              Text(
                rupees(
                  deal.isCompleted && deal.deliveredQuantity != null
                      ? deal.deliveredQuantity! * (deal.deliveredPrice ?? 0)
                      : deal.totalValue,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kOwnerGreen,
                ),
              ),
            ],
          ),
          if (!deal.isCompleted || onChat != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (!deal.isCompleted)
                  Expanded(
                    child: OwnerPrimaryButton(
                      label: 'Complete Deal',
                      onPressed: onComplete,
                    ),
                  )
                else
                  const Spacer(),
                if (onChat != null) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: onChat,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: kOwnerGreen,
                        side: const BorderSide(color: kOwnerGreen),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../services/activity_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/buyer_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import '../buyer/coconut_type.dart';
import '../chat/chat_page.dart';
import '../complete_deal_page.dart';
import '../order_status_page.dart';
import 'buyer_request_card.dart';

const Color _amber = Color(0xFFB26A2C);

/// The Orders tab, the same for buyers and estate owners:
///   Pending Orders  offers I put out that wait for the other side
///   Deals           open negotiations and accepted deals (Deal Window)
///   Transactions    completed deals
class OrdersPage extends StatefulWidget {
  /// 0 pending, 1 deals, 2 transactions.
  final int initialTab;

  const OrdersPage({super.key, this.initialTab = 0});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

enum _DealFilter { all, dueTomorrow, upcoming, negotiating }

class _OrdersPageState extends State<OrdersPage> {
  late int _tab = widget.initialTab;
  _DealFilter _filter = _DealFilter.all;
  bool _bannerClosed = false;

  late Future<(Activity, List<BuyerRequest>)> _data = _load();

  bool get _buyer => AuthService.currentUser?.isBuyer ?? false;

  Future<(Activity, List<BuyerRequest>)> _load() async {
    final Future<Activity> activity = ActivityService.load();
    final List<BuyerRequest> requests = _buyer
        ? (await BuyerService.getMyRequests())
              .where((r) => r.isPending)
              .toList()
        : const [];
    return (await activity, requests);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
    Unread.refresh();
  }

  Future<void> _openChat(int chatId) async {
    await openChat(context, chatId);
    _reload();
  }

  Future<void> _complete(OrderItem deal) async {
    if (await openCompleteDeal(context, deal.id)) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      bottom: const AppBottomNav(current: AppTab.orders),
      child: Column(
        children: [
          OwnerHeader(
            title: 'Orders',
            subtitle: _buyer ? 'PURCHASES & ORDERS' : 'SALES & ORDERS',
          ),
          Expanded(
            child: FutureBuilder<(Activity, List<BuyerRequest>)>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: kOwnerGreen),
                  );
                }
                if (snapshot.hasError) {
                  final Object error = snapshot.error!;
                  return OwnerMessage(
                    icon: Icons.cloud_off_outlined,
                    text: error is ApiException
                        ? error.message
                        : 'Could not load your orders',
                    onRetry: _reload,
                  );
                }
                final (Activity activity, List<BuyerRequest> requests) =
                    snapshot.data!;
                return _buildTabs(activity, requests);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(Activity activity, List<BuyerRequest> requests) {
    final int pending = activity.pending.length + requests.length;
    final int dueSoon = activity.deals.where((d) => d.dueSoon).length;

    final List<Widget> content = switch (_tab) {
      0 => _pending(activity, requests),
      1 => _deals(activity),
      _ => _transactions(activity),
    };

    return RefreshIndicator(
      color: kOwnerGreen,
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 14, bottom: 24),
        children: [
          OwnerTabs(
            labels: const ['Pending Orders', 'Deals', 'Transactions'],
            badges: [pending, dueSoon + _waiting(activity), 0],
            selected: _tab,
            onSelected: (index) => setState(() => _tab = index),
          ),
          const SizedBox(height: 6),
          ...content,
        ],
      ),
    );
  }

  /// Chats where the other side's offer waits for my answer.
  int _waiting(Activity activity) =>
      activity.negotiations.where((chat) => chat.offerWaiting).length;

  Widget _section(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: kOwnerMuted,
            ),
          ),
        ),
        ?action,
      ],
    ),
  );

  Widget _padded(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: child);

  // ------------------------------------------------------------- Pending

  List<Widget> _pending(Activity activity, List<BuyerRequest> requests) {
    final List<PendingOffer> chatOffers = activity.pending
        .where((p) => p.inChat)
        .toList();
    final List<PendingOffer> sellOffers = activity.pending
        .where((p) => !p.inChat)
        .toList();

    if (chatOffers.isEmpty && sellOffers.isEmpty && requests.isEmpty) {
      return [
        OwnerMessage(
          icon: Icons.hourglass_empty,
          text: _buyer
              ? 'Nothing pending. Requests you submit and price offers you '
                    'send in chats wait here for the estate owners.'
              : 'Nothing pending. Offers you send to buyers and prices you '
                    'offer in chats wait here for an answer.',
        ),
      ];
    }

    return [
      if (requests.isNotEmpty) ...[
        _section('YOUR REQUESTS (${requests.length})'),
        for (final BuyerRequest request in requests)
          _padded(BuyerRequestCard(request: request, onChanged: _reload)),
      ],
      if (sellOffers.isNotEmpty) ...[
        _section(
          'YOUR OFFERS TO BUYERS (${sellOffers.length})',
          action: TextButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OrderStatusPage(),
                ),
              );
              _reload();
            },
            style: TextButton.styleFrom(foregroundColor: kOwnerGreen),
            child: const Text('View all'),
          ),
        ),
        for (final PendingOffer offer in sellOffers)
          _padded(
            _PendingOfferCard(
              offer: offer,
              onChat: offer.negotiationId == null
                  ? null
                  : () => _openChat(offer.negotiationId!),
            ),
          ),
      ],
      if (chatOffers.isNotEmpty) ...[
        _section('YOUR PRICE OFFERS IN CHATS (${chatOffers.length})'),
        for (final PendingOffer offer in chatOffers)
          _padded(
            _PendingOfferCard(
              offer: offer,
              onChat: () => _openChat(offer.negotiationId!),
            ),
          ),
      ],
    ];
  }

  // --------------------------------------------------------------- Deals

  List<Widget> _deals(Activity activity) {
    final List<OrderItem> dueSoon = activity.deals
        .where((d) => d.dueSoon)
        .toList();
    final List<OrderItem> upcoming = activity.deals
        .where((d) => !d.dueSoon)
        .toList();
    final List<OrderItem> shownDeals = switch (_filter) {
      _DealFilter.all => activity.deals,
      _DealFilter.dueTomorrow => dueSoon,
      _DealFilter.upcoming => upcoming,
      _DealFilter.negotiating => const [],
    };
    final bool showChats =
        _filter == _DealFilter.all || _filter == _DealFilter.negotiating;

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OwnerTabs(
          labels: const [
            'All Deals',
            'Due Tomorrow',
            'Upcoming',
            'Negotiating',
          ],
          badges: [0, dueSoon.length, 0, _waiting(activity)],
          selected: _filter.index,
          onSelected: (index) =>
              setState(() => _filter = _DealFilter.values[index]),
        ),
      ),
      if (dueSoon.isNotEmpty &&
          !_bannerClosed &&
          _filter != _DealFilter.negotiating)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _DueBanner(
            deal: dueSoon.first,
            more: dueSoon.length - 1,
            onClose: () => setState(() => _bannerClosed = true),
          ),
        ),
      if (_filter != _DealFilter.negotiating) ...[
        _section('SCHEDULED ORDERS (${shownDeals.length})'),
        if (shownDeals.isEmpty)
          const OwnerMessage(
            icon: Icons.local_shipping_outlined,
            text:
                'No deals here yet. A deal is made when an offer is accepted.',
          ),
        for (final OrderItem deal in shownDeals)
          _padded(
            _DealCard(
              deal: deal,
              onComplete: deal.iAmBuyer ? null : () => _complete(deal),
              onChat: deal.negotiationId == null
                  ? null
                  : () => _openChat(deal.negotiationId!),
            ),
          ),
      ],
      if (showChats) ...[
        _section('NEGOTIATING (${activity.negotiations.length})'),
        if (activity.negotiations.isEmpty)
          OwnerMessage(
            icon: Icons.forum_outlined,
            text: _buyer
                ? 'No open negotiations. Tap Negotiate on a listing to start one.'
                : 'No open negotiations. Buyers start one from your listings.',
          ),
        for (final ChatSummary chat in activity.negotiations)
          _padded(
            _NegotiationCard(chat: chat, onOpen: () => _openChat(chat.id)),
          ),
      ],
    ];
  }

  // -------------------------------------------------------- Transactions

  List<Widget> _transactions(Activity activity) {
    if (activity.transactions.isEmpty) {
      return const [
        OwnerMessage(
          icon: Icons.receipt_long_outlined,
          text:
              'No completed transactions yet. Deals appear here once the '
              'estate owner completes them.',
        ),
      ];
    }
    return [
      _section('COMPLETED (${activity.transactions.length})'),
      for (final OrderItem order in activity.transactions)
        _padded(
          _TransactionCard(
            order: order,
            onChat: order.negotiationId == null
                ? null
                : () => _openChat(order.negotiationId!),
          ),
        ),
    ];
  }
}

// ------------------------------------------------------------------ cards

class _CardTop extends StatelessWidget {
  final String label;
  final Widget pill;

  const _CardTop({required this.label, required this.pill});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: kOwnerGreen,
            ),
          ),
        ),
        pill,
      ],
    );
  }
}

/// Name, product line and an optional round chat button.
class _Who extends StatelessWidget {
  final String name;
  final String productType;
  final VoidCallback? onChat;
  final int unread;

  const _Who({
    required this.name,
    required this.productType,
    this.onChat,
    this.unread = 0,
  });

  @override
  Widget build(BuildContext context) {
    final CoconutType type = CoconutType.fromCode(productType);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(type.icon, size: 14, color: type.iconColor),
                  const SizedBox(width: 5),
                  Text(
                    type.label,
                    style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onChat != null)
          Material(
            color: kOwnerGreenSoft,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'Open chat',
              onPressed: onChat,
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(
                  Icons.chat_outlined,
                  size: 20,
                  color: kOwnerGreen,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;

  const _TotalRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kOwnerInk,
            ),
          ),
        ),
        Text(
          rupees(amount),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kOwnerGreen,
          ),
        ),
      ],
    );
  }
}

class _DateLine extends StatelessWidget {
  final String text;
  final bool urgent;

  const _DateLine(this.text, {this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final Color color = urgent ? kOwnerRed : kOwnerMuted;
    return Row(
      children: [
        Icon(Icons.calendar_today_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: urgent ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DueBanner extends StatelessWidget {
  final OrderItem deal;
  final int more;
  final VoidCallback onClose;

  const _DueBanner({
    required this.deal,
    required this.more,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final int days = deal.daysUntilDue ?? 1;
    final String title = days < 0
        ? 'Deal Overdue'
        : days == 0
        ? 'Deal Due Today'
        : 'Deal Due Tomorrow';
    final String who = deal.iAmBuyer
        ? 'Your order from ${deal.counterpartName}'
        : '${deal.counterpartName} order';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: kOwnerGreenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDCC6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kOwnerGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: kOwnerRed,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$who of ${withCommas(deal.quantity)} '
                  '${CoconutType.fromCode(deal.productType).label.toLowerCase()} '
                  'scheduled for ${shortDate(deal.dueDate)}.'
                  '${more > 0 ? ' $more more due soon.' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: kOwnerInk,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: kOwnerMuted),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// An accepted deal, as in the Deal Window design.
class _DealCard extends StatelessWidget {
  final OrderItem deal;
  final VoidCallback? onComplete;
  final VoidCallback? onChat;

  const _DealCard({required this.deal, this.onComplete, this.onChat});

  OwnerPill get _pill {
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
    return const OwnerPill('Confirmed', icon: Icons.check_circle_outline);
  }

  @override
  Widget build(BuildContext context) {
    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTop(label: 'REQUEST #${deal.reference}', pill: _pill),
          const SizedBox(height: 10),
          _Who(
            name: deal.counterpartName,
            productType: deal.productType,
            onChat: onChat,
          ),
          const SizedBox(height: 12),
          QuantityPriceBox(
            quantity: deal.quantity,
            pricePerUnit: deal.pricePerUnit,
          ),
          const SizedBox(height: 10),
          _DateLine(
            deal.dueDate == null ? 'No order date' : shortDate(deal.dueDate),
            urgent: deal.dueSoon,
          ),
          const DashedDivider(),
          _TotalRow(label: 'Total Value', amount: deal.totalValue),
          const SizedBox(height: 14),
          if (onComplete != null)
            OwnerPrimaryButton(
              label: 'Complete Deal',
              arrow: true,
              onPressed: onComplete,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: kOwnerPanel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Order in progress - ${deal.counterpartName} completes it',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kOwnerMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An open negotiation; tapping opens its chat.
class _NegotiationCard extends StatelessWidget {
  final ChatSummary chat;
  final VoidCallback onOpen;

  const _NegotiationCard({required this.chat, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final double price = chat.lastOfferPrice ?? chat.listedPrice;
    final String priceLabel = chat.lastOfferPrice == null
        ? 'Listed price'
        : chat.lastIsMine
        ? 'Your latest offer'
        : 'Their latest offer';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: OwnerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTop(
              label: 'NEGOTIATION #CH-${chat.id.toString().padLeft(3, '0')}',
              pill: chat.offerWaiting
                  ? const OwnerPill(
                      'Reply needed',
                      icon: Icons.local_offer_outlined,
                      tone: PillTone.red,
                    )
                  : const OwnerPill(
                      'Negotiating',
                      icon: Icons.sync_alt,
                      tone: PillTone.neutral,
                    ),
            ),
            const SizedBox(height: 10),
            _Who(
              name: chat.counterpartName,
              productType: chat.productType,
              onChat: onOpen,
              unread: chat.unreadCount,
            ),
            const SizedBox(height: 12),
            QuantityPriceBox(quantity: chat.quantity, pricePerUnit: price),
            const SizedBox(height: 8),
            Text(
              '$priceLabel  ·  updated ${_when(chat.lastActivityAt)}',
              style: const TextStyle(fontSize: 12, color: kOwnerMuted),
            ),
            const DashedDivider(),
            _TotalRow(
              label: 'Value at this price',
              amount: price * chat.quantity,
            ),
            const SizedBox(height: 14),
            OwnerPrimaryButton(
              label: 'Open Chat',
              arrow: true,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

String _when(DateTime? time) {
  if (time == null) return '';
  final DateTime now = DateTime.now();
  final bool today =
      time.year == now.year && time.month == now.month && time.day == now.day;
  return today ? clockTime(time) : shortDate(time);
}

/// An offer I sent that waits for an answer.
class _PendingOfferCard extends StatelessWidget {
  final PendingOffer offer;
  final VoidCallback? onChat;

  const _PendingOfferCard({required this.offer, this.onChat});

  @override
  Widget build(BuildContext context) {
    final String label = offer.inChat
        ? 'PRICE OFFER #CH-${(offer.negotiationId ?? 0).toString().padLeft(3, '0')}'
        : 'REQUEST #CR-${offer.id.toString().padLeft(3, '0')}';
    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTop(
            label: label,
            pill: const OwnerPill(
              'Waiting',
              icon: Icons.hourglass_empty,
              tone: PillTone.neutral,
            ),
          ),
          const SizedBox(height: 10),
          _Who(
            name: offer.counterpartName,
            productType: offer.productType,
            onChat: onChat,
          ),
          const SizedBox(height: 12),
          QuantityPriceBox(quantity: offer.quantity, pricePerUnit: offer.price),
          const SizedBox(height: 10),
          Text(
            [
              if (offer.theirPrice != null)
                offer.inChat
                    ? 'Listed at ${rupees(offer.theirPrice!)}'
                    : 'Buyer bid ${rupees(offer.theirPrice!)}',
              if (offer.date != null) 'needed by ${shortDate(offer.date)}',
              'sent ${_when(offer.createdAt)}',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 12, color: kOwnerMuted),
          ),
          const DashedDivider(),
          _TotalRow(label: 'Offer Value', amount: offer.price * offer.quantity),
        ],
      ),
    );
  }
}

/// A completed deal, with any price dispute.
class _TransactionCard extends StatelessWidget {
  final OrderItem order;
  final VoidCallback? onChat;

  const _TransactionCard({required this.order, this.onChat});

  @override
  Widget build(BuildContext context) {
    final OwnerPill pill = switch (order.disputeStatus) {
      'PENDING' => const OwnerPill(
        'Price review',
        icon: Icons.gavel,
        tone: PillTone.red,
      ),
      'REJECTED' => const OwnerPill(
        'Agreed price kept',
        icon: Icons.verified_outlined,
      ),
      'APPROVED' => const OwnerPill(
        'New price approved',
        icon: Icons.verified_outlined,
      ),
      _ => const OwnerPill('Completed', icon: Icons.check_circle_outline),
    };
    final int quantity = order.deliveredQuantity ?? order.quantity;
    final double price = order.deliveredPrice ?? order.pricePerUnit;

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTop(label: 'DEAL #${order.reference}', pill: pill),
          const SizedBox(height: 10),
          _Who(
            name: order.counterpartName,
            productType: order.productType,
            onChat: onChat,
          ),
          const SizedBox(height: 12),
          QuantityPriceBox(quantity: quantity, pricePerUnit: price),
          const SizedBox(height: 8),
          Text(
            'Agreed ${withCommas(order.quantity)} nuts at '
            '${rupees(order.pricePerUnit)}  ·  completed '
            '${shortDate(order.completedAt)}',
            style: const TextStyle(fontSize: 12, color: kOwnerMuted),
          ),
          if (order.disputeStatus == 'PENDING' &&
              order.disputePrice != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.gavel, size: 16, color: _amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${rupees(order.disputePrice!)} / nut requested - waiting '
                      'for CocoConnect Admin. The agreed '
                      '${rupees(order.pricePerUnit)} applies until approved.',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Color(0xFF6B4A1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const DashedDivider(),
          _TotalRow(label: 'Settled Value', amount: order.settledTotal),
        ],
      ),
    );
  }
}

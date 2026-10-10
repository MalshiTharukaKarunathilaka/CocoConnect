import 'package:flutter/material.dart';
import '../services/buyer_service.dart';
import '../services/owner_service.dart';
import '../widgets/async_list.dart';
import '../widgets/reusable_widgets.dart';
import 'buyer/buyer_format.dart';
import 'buyer/coconut_type.dart';
import 'negotiation_page.dart';

const Color _ink = Color(0xFF0F1F35);
const Color _green = Color(0xFF2E7D32);
const Color _grey = Color(0xFF6B7280);
const Color _border = Color(0xFFD8E1EA);

/// Estate owner's Orders tab: chats with buyers on their listings, offers
/// they sent for buyer requests, and the resulting orders.
class OwnerActivityPage extends StatelessWidget {
  const OwnerActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        body: Center(
          child: Container(
            width: 390,
            height: double.infinity,
            color: const Color(0xFFFCF8EF),
            child: const SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Text(
                      'Buyers & Orders',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                  TabBar(
                    labelColor: _green,
                    unselectedLabelColor: _grey,
                    indicatorColor: _green,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: [
                      Tab(text: 'Chats'),
                      Tab(text: 'Offers Sent'),
                      Tab(text: 'Orders'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_ChatsTab(), _OffersTab(), _OrdersTab()],
                    ),
                  ),
                  CustomBottomNavigation(currentIndex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Card({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _border),
        ),
        child: child,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool good;
  final bool bad;

  const _Pill(this.text, {this.good = false, this.bad = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: good
            ? const Color(0xFFE8F5E9)
            : bad
            ? const Color(0xFFFBE3E3)
            : const Color(0xFFF0EDE6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: good
              ? _green
              : bad
              ? const Color(0xFFC62828)
              : const Color(0xFF5A5A5A),
        ),
      ),
    );
  }
}

Widget _title(String text) => Text(
  text,
  style: const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: _ink,
  ),
);

Widget _detail(String text) => Text(
  text,
  style: const TextStyle(fontSize: 12.5, color: Color(0xFF3A3A3A)),
);

class _ChatsTab extends StatelessWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context) {
    return AsyncList<NegotiationSummary>(
      load: OwnerService.getChats,
      emptyText:
          'No buyer chats yet. Buyers can start one from your listings in '
          'the marketplace.',
      itemBuilder: (context, chat, reload) {
        final _Pill pill = switch (chat.status) {
          'REJECTED' => const _Pill('CLOSED', bad: true),
          'ACCEPTED' =>
            chat.orderStatus == 'COMPLETED'
                ? const _Pill('COMPLETED', good: true)
                : const _Pill('ORDER PLACED', good: true),
          _ => const _Pill('NEGOTIATING'),
        };
        return _Card(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NegotiationPage(negotiationId: chat.id),
              ),
            );
            reload();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _title(chat.buyerName ?? 'Buyer')),
                  pill,
                ],
              ),
              const SizedBox(height: 6),
              _detail(
                '${CoconutType.fromCode(chat.productType).label}  ·  '
                '${withCommas(chat.quantity)} nuts  ·  listed at '
                '${rupees(chat.listedPrice)}',
              ),
              const SizedBox(height: 4),
              Text(
                chat.messageCount == 1
                    ? '1 message'
                    : '${chat.messageCount} messages',
                style: const TextStyle(fontSize: 12, color: _grey),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OffersTab extends StatelessWidget {
  const _OffersTab();

  @override
  Widget build(BuildContext context) {
    return AsyncList<SellOffer>(
      load: OwnerService.getMyOffers,
      emptyText:
          'No offers sent yet. Open Coconuts on the dashboard and tap a '
          'buyer to send one.',
      itemBuilder: (context, offer, reload) {
        final _Pill pill = switch (offer.status.toLowerCase()) {
          'accepted' => const _Pill('ACCEPTED', good: true),
          'declined' => const _Pill('NOT CHOSEN', bad: true),
          _ => const _Pill('WAITING'),
        };
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _title(offer.buyerName ?? 'Buyer')),
                  pill,
                ],
              ),
              const SizedBox(height: 6),
              _detail(
                'You offered ${withCommas(offer.quantity)} nuts at '
                '${rupees(offer.pricePerUnit)} each',
              ),
              if (offer.buyerBid != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${CoconutType.fromCode(offer.productType).label}  ·  '
                  'buyer bid ${rupees(offer.buyerBid!)} for '
                  '${withCommas(offer.requestedQuantity ?? 0)} nuts',
                  style: const TextStyle(fontSize: 12, color: _grey),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    return AsyncList<BuyerOrder>(
      load: OwnerService.getOrders,
      emptyText:
          'No orders yet. Orders appear when a buyer accepts your price in '
          'a chat or accepts one of your offers.',
      itemBuilder: (context, order, reload) {
        final bool completed = order.status == 'COMPLETED';
        return _Card(
          onTap: order.negotiationId == null
              ? null
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NegotiationPage(negotiationId: order.negotiationId!),
                    ),
                  );
                  reload();
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _title(
                      'Order #${order.id}  ·  ${order.buyerName ?? 'Buyer'}',
                    ),
                  ),
                  completed
                      ? const _Pill('COMPLETED', good: true)
                      : const _Pill('AWAITING PICKUP'),
                ],
              ),
              const SizedBox(height: 6),
              _detail(
                '${withCommas(order.quantity)} nuts  ·  '
                '${rupees(order.pricePerUnit)} each  ·  total '
                '${rupees(order.totalValue)}',
              ),
              const SizedBox(height: 4),
              Text(
                CoconutType.fromCode(order.productType).label,
                style: const TextStyle(fontSize: 12, color: _grey),
              ),
            ],
          ),
        );
      },
    );
  }
}

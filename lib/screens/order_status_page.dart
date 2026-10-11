import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/buyer_service.dart';
import '../services/owner_service.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'buyer/coconut_type.dart';
import 'complete_deal_page.dart';

/// "My Sell Requests": the offers this estate sent for buyer requests,
/// grouped by what happened to them.
class OrderStatusPage extends StatefulWidget {
  const OrderStatusPage({super.key});

  @override
  State<OrderStatusPage> createState() => _OrderStatusPageState();
}

enum _Stage { pending, accepted, completed, notChosen }

class _OrderStatusPageState extends State<OrderStatusPage> {
  late Future<List<SellOffer>> _offers = OwnerService.getMyOffers();
  _Stage _tab = _Stage.pending;

  static const Map<_Stage, String> _labels = {
    _Stage.pending: 'Pending',
    _Stage.accepted: 'Accepted',
    _Stage.completed: 'Completed',
    _Stage.notChosen: 'Not chosen',
  };

  static _Stage _stageOf(SellOffer offer) {
    switch (offer.status.toLowerCase()) {
      case 'accepted':
        return offer.orderStatus == 'COMPLETED'
            ? _Stage.completed
            : _Stage.accepted;
      case 'declined':
        return _Stage.notChosen;
      default:
        return _Stage.pending;
    }
  }

  Future<void> _reload() async {
    final Future<List<SellOffer>> next = OwnerService.getMyOffers();
    setState(() {
      _offers = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder.
    }
  }

  Future<void> _complete(SellOffer offer) async {
    if (offer.orderId == null) return;
    if (await openCompleteDeal(context, offer.orderId!)) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(title: 'My Sell Requests'),
          Expanded(
            child: RefreshIndicator(
              color: kOwnerGreen,
              onRefresh: _reload,
              child: FutureBuilder<List<SellOffer>>(
                future: _offers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: kOwnerGreen),
                    );
                  }
                  if (snapshot.hasError) {
                    final Object error = snapshot.error!;
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        OwnerMessage(
                          icon: Icons.cloud_off_outlined,
                          text: error is ApiException
                              ? error.message
                              : 'Could not load your requests',
                          onRetry: _reload,
                        ),
                      ],
                    );
                  }
                  return _buildList(snapshot.data!);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<SellOffer> all) {
    final List<_Stage> stages = _Stage.values;
    final List<SellOffer> shown = all
        .where((offer) => _stageOf(offer) == _tab)
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      children: [
        OwnerTabs(
          labels: [for (final stage in stages) _labels[stage]!],
          badges: [
            for (final stage in stages)
              stage == _Stage.accepted
                  ? all.where((o) => _stageOf(o) == stage).length
                  : 0,
          ],
          selected: stages.indexOf(_tab),
          onSelected: (index) => setState(() => _tab = stages[index]),
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          OwnerMessage(
            icon: Icons.inbox_outlined,
            text: switch (_tab) {
              _Stage.pending =>
                'No requests waiting. Open Coconuts on the dashboard and '
                    'tap a buyer to send one.',
              _Stage.accepted => 'No accepted requests to deliver.',
              _Stage.completed => 'No completed deals yet.',
              _Stage.notChosen => 'No requests were turned down.',
            },
          ),
        for (final SellOffer offer in shown)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: _RequestCard(
              offer: offer,
              stage: _stageOf(offer),
              onComplete: () => _complete(offer),
            ),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final SellOffer offer;
  final _Stage stage;
  final VoidCallback onComplete;

  const _RequestCard({
    required this.offer,
    required this.stage,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final CoconutType type = CoconutType.fromCode(offer.productType);
    final OwnerPill pill = switch (stage) {
      _Stage.pending => const OwnerPill(
        'Pending',
        icon: Icons.hourglass_empty,
        tone: PillTone.neutral,
      ),
      _Stage.accepted => const OwnerPill(
        'Accepted',
        icon: Icons.check_circle_outline,
      ),
      _Stage.completed => const OwnerPill(
        'Completed',
        icon: Icons.verified_outlined,
      ),
      _Stage.notChosen => const OwnerPill(
        'Not chosen',
        icon: Icons.block,
        tone: PillTone.red,
      ),
    };

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'REQUEST #CR-${offer.id.toString().padLeft(3, '0')}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: kOwnerMuted,
                  ),
                ),
              ),
              pill,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(type.icon, size: 18, color: type.iconColor),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Buyer: ${offer.buyerName ?? 'Buyer'}',
              if (offer.createdAt != null) 'sent ${shortDate(offer.createdAt)}',
            ].join('  ·  '),
            style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
          ),
          if (offer.buyerBid != null) ...[
            const SizedBox(height: 2),
            Text(
              'Buyer asked for ${withCommas(offer.requestedQuantity ?? 0)} '
              'nuts at ${rupees(offer.buyerBid!)}',
              style: const TextStyle(fontSize: 12, color: kOwnerMuted),
            ),
          ],
          const SizedBox(height: 12),
          QuantityPriceBox(
            quantity: offer.quantity,
            pricePerUnit: offer.pricePerUnit,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Value',
                  style: TextStyle(fontSize: 13, color: kOwnerMuted),
                ),
              ),
              Text(
                rupees(offer.quantity * offer.pricePerUnit),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kOwnerGreen,
                ),
              ),
            ],
          ),
          if (stage == _Stage.accepted && offer.orderId != null) ...[
            const SizedBox(height: 14),
            OwnerPrimaryButton(
              label: 'Complete Transaction',
              arrow: true,
              onPressed: onComplete,
            ),
          ],
        ],
      ),
    );
  }
}

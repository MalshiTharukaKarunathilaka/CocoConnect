import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../services/buyer_service.dart';
import '../../widgets/async_list.dart';
import '../../widgets/buyer_widgets.dart';
import 'buyer_format.dart';
import 'buyer_negotiation_page.dart';
import 'coconut_type.dart';
import 'buyer_profile_page.dart';

/// Opens My Activity from any buyer screen's ORDERS tab, on top of
/// Buying Categories rather than stacking copies.
void openMyActivity(BuildContext context) {
  final NavigatorState navigator = Navigator.of(context);
  navigator.popUntil((route) => route.isFirst);
  navigator.push(
    MaterialPageRoute(builder: (context) => const MyActivityPage()),
  );
}

/// The buyer's own requests, negotiations and orders.
class MyActivityPage extends StatelessWidget {
  const MyActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: BuyerScaffold(
        bottomNavigation: BuyerBottomNavigation(
          currentIndex: 1,
          onTabSelected: (index) {
            if (index == 0) {
              Navigator.popUntil(context, (route) => route.isFirst);
            } else if (index == 2) {
              openBuyerProfile(context);
            }
          },
        ),
        body: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'My Activity',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            TabBar(
              labelColor: kBuyerGreen,
              unselectedLabelColor: kBuyerGrey,
              indicatorColor: kBuyerGreen,
              labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'Requests'),
                Tab(text: 'Negotiations'),
                Tab(text: 'Orders'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_RequestsTab(), _NegotiationsTab(), _OrdersTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSnack(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFC62828) : kBuyerGreen,
      ),
    );
}

BuyerPill _statusPill(String text, {bool good = false, bool bad = false}) {
  return BuyerPill(
    text: text,
    background: good
        ? const Color(0xFFDDEEE0)
        : bad
        ? const Color(0xFFFBE3E3)
        : const Color(0xFFF0EDE6),
    foreground: good
        ? kBuyerGreen
        : bad
        ? const Color(0xFFC62828)
        : const Color(0xFF5A5A5A),
  );
}

// ---------------------------------------------------------------- Requests

class _RequestsTab extends StatelessWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context) {
    return AsyncList<BuyerRequest>(
      load: BuyerService.getMyRequests,
      emptyText:
          'No requests yet. Submit one from the Marketplace and estate '
          'owners can respond.',
      itemBuilder: (context, request, reload) =>
          _RequestCard(request: request, onChanged: reload),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BuyerRequest request;
  final VoidCallback onChanged;

  const _RequestCard({required this.request, required this.onChanged});

  Future<void> _edit(BuildContext context) async {
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EditRequestDialog(request: request),
    );
    if (saved == true && context.mounted) {
      _showSnack(context, 'Request updated');
      onChanged();
    }
  }

  Future<void> _showOffers(BuildContext context) async {
    final bool? accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _OffersSheet(request: request),
    );
    if (accepted == true && context.mounted) {
      _showSnack(context, 'Offer accepted. It is now under Orders.');
      onChanged();
    }
  }

  Future<void> _delete(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete request?'),
        content: Text(
          'Your request for ${withCommas(request.quantity)} nuts will be '
          'removed and estate owners will no longer see it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await BuyerService.deleteRequest(request.id);
      if (!context.mounted) return;
      _showSnack(context, 'Request deleted');
      onChanged();
    } on ApiException catch (error) {
      if (context.mounted) _showSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CoconutType type = CoconutType.fromCode(request.productType);

    return BuyerCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        type.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    request.isPending
                        ? _statusPill('PENDING')
                        : _statusPill(request.status.toUpperCase(), good: true),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${withCommas(request.quantity)} nuts  ·  '
                  '${rupees(request.pricePerUnit)} / nut',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Needed by ${shortDate(request.requiredDate)}',
                  style: const TextStyle(fontSize: 12, color: kBuyerGrey),
                ),
                if (request.responseCount > 0) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showOffers(context),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_offer_outlined,
                          size: 15,
                          color: kBuyerGreen,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            request.responseCount == 1
                                ? '1 estate owner responded  ·  View offer'
                                : '${request.responseCount} estate owners '
                                      'responded  ·  View offers',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: kBuyerGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Request options',
            icon: const Icon(Icons.more_vert, color: kBuyerGrey),
            onSelected: (choice) =>
                choice == 'edit' ? _edit(context) : _delete(context),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                enabled: request.isPending,
                child: const Text('Edit'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Estate owners' offers on one request, cheapest first, with Accept.
class _OffersSheet extends StatefulWidget {
  final BuyerRequest request;

  const _OffersSheet({required this.request});

  @override
  State<_OffersSheet> createState() => _OffersSheetState();
}

class _OffersSheetState extends State<_OffersSheet> {
  late final Future<List<SellOffer>> _offers = BuyerService.getRequestResponses(
    widget.request.id,
  );
  int? _accepting;

  Future<void> _accept(SellOffer offer) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept this offer?'),
        content: Text(
          '${offer.estateName}: ${withCommas(offer.quantity)} nuts at '
          '${rupees(offer.pricePerUnit)} each\n'
          'Total: ${rupees(offer.pricePerUnit * offer.quantity)}\n\n'
          'Other offers on this request will be declined.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _accepting = offer.id);
    try {
      await BuyerService.acceptResponse(offer.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _accepting = null);
      _showSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool open = widget.request.isPending;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Offers from estate owners',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Your request: ${withCommas(widget.request.quantity)} nuts at '
                '${rupees(widget.request.pricePerUnit)} each',
                style: const TextStyle(fontSize: 12.5, color: kBuyerGrey),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: FutureBuilder<List<SellOffer>>(
                  future: _offers,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(color: kBuyerGreen),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      final Object error = snapshot.error!;
                      return Text(
                        error is ApiException
                            ? error.message
                            : 'Could not load offers',
                        style: const TextStyle(color: Color(0xFFC62828)),
                      );
                    }
                    final List<SellOffer> offers = snapshot.data!;
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: offers.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final SellOffer offer = offers[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    offer.estateName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${withCommas(offer.quantity)} nuts  ·  '
                                    '${rupees(offer.pricePerUnit)} each',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3A3A3A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (offer.location != null)
                                        offer.location!,
                                      offer.trustScore == null
                                          ? 'not rated yet'
                                          : 'trust ${offer.trustScore}/5',
                                    ].join('  ·  '),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kBuyerGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (open)
                              ElevatedButton(
                                onPressed: _accepting == null
                                    ? () => _accept(offer)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kBuyerGreen,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _accepting == offer.id ? '...' : 'Accept',
                                ),
                              )
                            else
                              offer.status.toLowerCase() == 'accepted'
                                  ? _statusPill('ACCEPTED', good: true)
                                  : _statusPill('NOT CHOSEN'),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditRequestDialog extends StatefulWidget {
  final BuyerRequest request;

  const _EditRequestDialog({required this.request});

  @override
  State<_EditRequestDialog> createState() => _EditRequestDialogState();
}

class _EditRequestDialogState extends State<_EditRequestDialog> {
  late final _quantityController = TextEditingController(
    text: '${widget.request.quantity}',
  );
  late final _priceController = TextEditingController(
    text: widget.request.pricePerUnit.truncate().toString(),
  );
  late DateTime? _date = widget.request.requiredDate;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime today = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date != null && _date!.isAfter(today) ? _date! : today,
      firstDate: today,
      lastDate: DateTime(today.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final int? quantity = int.tryParse(_quantityController.text);
    final int? price = int.tryParse(_priceController.text);
    if (quantity == null || quantity <= 0) {
      setState(() => _error = 'Enter the number of nuts');
      return;
    }
    if (_date == null) {
      setState(() => _error = 'Pick a date');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a price per nut');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BuyerService.updateRequest(
        widget.request.id,
        quantity: quantity,
        requiredDate: _date!,
        pricePerUnit: price.toDouble(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Number of nuts',
              suffixText: 'nuts',
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Required date',
                suffixIcon: Icon(Icons.calendar_month_outlined),
              ),
              child: Text(shortDate(_date)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Bidding price',
              prefixText: 'Rs. ',
              suffixText: 'per nut',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 12.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Negotiations

class _NegotiationsTab extends StatelessWidget {
  const _NegotiationsTab();

  @override
  Widget build(BuildContext context) {
    return AsyncList<NegotiationSummary>(
      load: BuyerService.getMyNegotiations,
      emptyText:
          'No negotiations yet. Open a listing in the Marketplace and tap '
          'Negotiate.',
      itemBuilder: (context, negotiation, reload) => BuyerCard(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BuyerNegotiationPage(
                negotiationId: negotiation.id,
                type: CoconutType.fromCode(negotiation.productType),
              ),
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
                  child: Text(
                    negotiation.estateName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                _negotiationPill(negotiation),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${CoconutType.fromCode(negotiation.productType).label}  ·  '
              '${withCommas(negotiation.quantity)} nuts  ·  listed at '
              '${rupees(negotiation.listedPrice)}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF3A3A3A)),
            ),
            const SizedBox(height: 4),
            Text(
              negotiation.messageCount == 1
                  ? '1 message'
                  : '${negotiation.messageCount} messages',
              style: const TextStyle(fontSize: 12, color: kBuyerGrey),
            ),
          ],
        ),
      ),
    );
  }

  BuyerPill _negotiationPill(NegotiationSummary negotiation) {
    switch (negotiation.status) {
      case 'REJECTED':
        return _statusPill('REJECTED', bad: true);
      case 'ACCEPTED':
        return negotiation.orderStatus == 'COMPLETED'
            ? _statusPill('COMPLETED', good: true)
            : _statusPill('DEAL ACCEPTED', good: true);
      default:
        return _statusPill('OPEN');
    }
  }
}

// ------------------------------------------------------------------ Orders

class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  Future<void> _completeOrder(
    BuildContext context,
    BuyerOrder order,
    VoidCallback reload,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete transaction?'),
        content: const Text(
          'Confirm that you have collected the nuts and paid the estate owner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BuyerService.completeOrder(order.id);
      if (!context.mounted) return;
      _showSnack(context, 'Transaction completed');
      reload();
    } on ApiException catch (error) {
      if (context.mounted) _showSnack(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncList<BuyerOrder>(
      load: BuyerService.getMyOrders,
      emptyText: 'No orders yet. Orders appear here when you accept a deal.',
      itemBuilder: (context, order, reload) {
        final bool completed = order.status == 'COMPLETED';
        return BuyerCard(
          onTap: completed
              ? null
              : order.negotiationId == null
              ? () => _completeOrder(context, order, reload)
              : () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BuyerNegotiationPage(
                        negotiationId: order.negotiationId!,
                        type: CoconutType.fromCode(order.productType),
                      ),
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
                    child: Text(
                      'Order #${order.id}  ·  ${order.estateName}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  completed
                      ? _statusPill('COMPLETED', good: true)
                      : _statusPill('TO COLLECT'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: BuyerInfoPair(
                      label: 'QUANTITY',
                      value: '${withCommas(order.quantity)} nuts',
                    ),
                  ),
                  Expanded(
                    child: BuyerInfoPair(
                      label: 'TOTAL',
                      value: rupees(order.totalValue),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${CoconutType.fromCode(order.productType).label}  ·  '
                '${rupees(order.pricePerUnit)} per nut'
                '${completed ? '' : '  ·  tap to complete'}',
                style: const TextStyle(fontSize: 12, color: kBuyerGrey),
              ),
            ],
          ),
        );
      },
    );
  }
}

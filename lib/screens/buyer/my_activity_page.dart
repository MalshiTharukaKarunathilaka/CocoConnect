import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../services/buyer_service.dart';
import '../../widgets/buyer_widgets.dart';
import '../auth_gate.dart';
import 'buyer_format.dart';
import 'buyer_negotiation_page.dart';
import 'coconut_type.dart';

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
              showAccountSheet(context);
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

/// Loads a list, with spinner, error + retry, empty message and
/// pull-to-refresh. [itemBuilder] gets a reload callback for after edits.
class _AsyncList<T> extends StatefulWidget {
  final Future<List<T>> Function() load;
  final String emptyText;
  final Widget Function(BuildContext context, T item, VoidCallback reload)
  itemBuilder;

  const _AsyncList({
    super.key,
    required this.load,
    required this.emptyText,
    required this.itemBuilder,
  });

  @override
  State<_AsyncList<T>> createState() => _AsyncListState<T>();
}

class _AsyncListState<T> extends State<_AsyncList<T>> {
  late Future<List<T>> _items = widget.load();

  Future<void> _reload() async {
    final Future<List<T>> next = widget.load();
    setState(() {
      _items = next;
    });
    try {
      await next;
    } catch (_) {
      // Shown by the FutureBuilder below.
    }
  }

  Widget _message(IconData icon, String text) {
    // ListView so pull-to-refresh still works on an empty or failed list.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 20),
      children: [
        Icon(icon, size: 34, color: kBuyerGrey),
        const SizedBox(height: 10),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.4, color: kBuyerGrey),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(foregroundColor: kBuyerGreen),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: kBuyerGreen,
      onRefresh: _reload,
      child: FutureBuilder<List<T>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: kBuyerGreen),
            );
          }
          if (snapshot.hasError) {
            final Object error = snapshot.error!;
            return _message(
              Icons.cloud_off_outlined,
              error is ApiException ? error.message : 'Could not load',
            );
          }
          final List<T> items = snapshot.data!;
          if (items.isEmpty) {
            return _message(Icons.inbox_outlined, widget.emptyText);
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                widget.itemBuilder(context, items[index], _reload),
          );
        },
      ),
    );
  }
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
    return _AsyncList<BuyerRequest>(
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
    return _AsyncList<NegotiationSummary>(
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

  @override
  Widget build(BuildContext context) {
    return _AsyncList<BuyerOrder>(
      load: BuyerService.getMyOrders,
      emptyText: 'No orders yet. Orders appear here when you accept a deal.',
      itemBuilder: (context, order, reload) {
        final bool completed = order.status == 'COMPLETED';
        return BuyerCard(
          onTap: order.negotiationId == null
              ? null
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

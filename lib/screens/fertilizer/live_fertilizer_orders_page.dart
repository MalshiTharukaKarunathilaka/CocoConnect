import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/fertilizer_api.dart';
import '../../widgets/land_owner_rating_dialog.dart';
import '../../widgets/owner_widgets.dart';

/// An order is sent to the real supplier selected here, never a demo account.
Future<Map<String, dynamic>?> submitFertilizerOrder(
  BuildContext context, {
  required String product,
  required int quantity,
  required num total,
  required DateTime date,
  required String slot,
  required bool government,
  Map<String, dynamic>? application,
}) async {
  final suppliers = await FertilizerApi.suppliers(government: government);
  if (!context.mounted) return null;
  final supplier = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(government ? 'Choose your CDO' : 'Choose your supplier'),
      children: [
        if (suppliers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No registered suppliers are available yet. A supplier must register before you can send an order.',
            ),
          ),
        for (final supplier in suppliers)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, supplier),
            child: ListTile(
              title: Text('${supplier['name']}'),
              subtitle: Text('${supplier['location'] ?? ''}'),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
  if (supplier == null) return null;
  final record = await FertilizerApi.create({
    'supplier_id': supplier['id'],
    'product': product,
    'quantity': quantity,
    'proposed_total': total,
    'preferred_date':
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'time_slot': slot,
    'application': application,
  });
  return {...record, 'supplier_name': supplier['name']};
}

class LiveFertilizerOrdersPage extends StatefulWidget {
  const LiveFertilizerOrdersPage({super.key, this.embedded = false});
  final bool embedded;
  @override
  State<LiveFertilizerOrdersPage> createState() =>
      _LiveFertilizerOrdersPageState();
}

class _LiveFertilizerOrdersPageState extends State<LiveFertilizerOrdersPage> {
  late Future<List<Map<String, dynamic>>> _orders = FertilizerApi.orders();
  bool _busy = false;
  Future<void> _reload() async {
    final next = FertilizerApi.orders();
    setState(() {
      _orders = next;
    });
    try {
      await next;
    } catch (_) {
      /* Displayed below. */
    }
  }

  Future<void> _act(Map<String, dynamic> order, String action) async {
    if (_busy) return;
    int? rating;
    if (action == 'rating') {
      rating = await showLandOwnerRatingDialog(context);
      if (rating == null || !mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(
            '${action == 'deliver'
                ? 'Mark delivered'
                : action == 'accept'
                ? 'Accept order'
                : 'Cancel order'}?',
          ),
          content: Text('${order['product']} ? ${order['quantity']} bags'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      if (action == 'rating') {
        await FertilizerApi.rateOwner(order['id'] as int, rating!);
      } else {
        await FertilizerApi.act(order['id'] as int, action);
      }
      if (mounted) await _reload();
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Fertilizer orders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Refresh orders',
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _orders,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snapshot.error is ApiException
                              ? (snapshot.error as ApiException).message
                              : 'Could not load fertilizer orders',
                        ),
                      ),
                      TextButton(
                        onPressed: _reload,
                        child: const Text('Retry'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (orders.isEmpty)
                      const Text(
                        'No orders yet. Place a fertilizer order from the map.',
                      ),
                    for (final order in orders)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _card(order),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
    return widget.embedded
        ? body
        : OwnerPage(
            child: Column(
              children: [
                const OwnerHeader(title: 'My fertilizer orders'),
                Expanded(child: body),
              ],
            ),
          );
  }

  void _viewApplication(Map<String, dynamic> application) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Fertilizer application'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Land owner: ${application['owner_name'] ?? ''}'),
                Text('Land: ${application['land_name'] ?? ''}'),
                Text('Location: ${application['location'] ?? ''}'),
                for (final key in ['nic_copy', 'land_title_copy'])
                  if (application[key] is String) ...[
                    const SizedBox(height: 12),
                    Text(key == 'nic_copy' ? 'Identity card' : 'Land title'),
                    Image.memory(
                      base64Decode(application[key] as String),
                      errorBuilder: (context, error, stack) =>
                          const Text('Could not display the attachment'),
                    ),
                  ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> order) {
    final supplier = order['supplier_user_id'] == AuthService.currentUser?.id;
    final status = '${order['status']}';
    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FO-${order['id']} ? ${status.toLowerCase()}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('${order['product']}'),
          Text(
            '${order['quantity']} bags ? Proposed total: Rs. ${order['proposed_total']}',
          ),
          Text('Land owner: ${order['owner_name']}'),
          Text('Supplier: ${order['supplier_name']}'),
          Text(
            '${order['preferred_date'].toString().split('T').first} ? ${order['time_slot']}',
          ),
          if (order['land_owner_rating'] != null)
            Text('Land owner rating: ${order['land_owner_rating']} / 5'),
          if (order['application'] is Map)
            TextButton(
              onPressed: () => _viewApplication(
                Map<String, dynamic>.from(order['application'] as Map),
              ),
              child: const Text('View application'),
            ),
          Wrap(
            spacing: 8,
            children: [
              if (supplier && status == 'PENDING')
                FilledButton(
                  onPressed: _busy ? null : () => _act(order, 'accept'),
                  child: const Text('Accept'),
                ),
              if (supplier && status == 'ACCEPTED')
                FilledButton(
                  onPressed: _busy ? null : () => _act(order, 'deliver'),
                  child: const Text('Mark delivered'),
                ),
              if (supplier &&
                  status == 'DELIVERED' &&
                  order['land_owner_rating'] == null)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _act(order, 'rating'),
                  icon: const Icon(Icons.star_outline),
                  label: const Text('Rate land owner'),
                ),
              if (status == 'PENDING' || status == 'ACCEPTED')
                TextButton(
                  onPressed: _busy ? null : () => _act(order, 'cancel'),
                  child: const Text('Cancel order'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

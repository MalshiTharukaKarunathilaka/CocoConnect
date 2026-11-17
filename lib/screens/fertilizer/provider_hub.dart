import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_cancel_reasons.dart';
import 'fertilizer_cdo_area_page.dart';
import 'fertilizer_cdo_messages_page.dart';
import 'fertilizer_cdo_request_sheet.dart';
import 'fertilizer_cdo_stock_page.dart';
import 'fertilizer_chrome.dart';
import 'fertilizer_data.dart';
import 'fertilizer_dispute_sheet.dart';
import 'fertilizer_supplier_chat_page.dart';
import 'supplier_calendar_page.dart';

/// Supplier Agent / CDO shell with demo-style bottom tabs.
class ProviderHub extends StatefulWidget {
  const ProviderHub({super.key, required this.mode});

  final FertHomeMode mode;

  @override
  State<ProviderHub> createState() => _ProviderHubState();
}

class _ProviderHubState extends State<ProviderHub> {
  final _store = FertilizerStore.instance;
  int _tab = 0;
  String _orderStatusFilter = 'all';

  bool get _isCdo => widget.mode == FertHomeMode.cdo;

  FertPlace get _shop => _store.myShop;

  List<FertOrder> get _myOrders => _store.myShopOrders;

  List<FertOrder> get _pending => _store.pendingAck;

  List<FertGovRequest> get _cdoRequests => _store.myCdoRequests;

  List<FertGovRequest> get _filteredCdoRequests {
    return _cdoRequests.where((r) {
      switch (_orderStatusFilter) {
        case 'pending':
          return r.status == 'Pending Ack' || r.status == 'Submitted';
        case 'accepted':
          return r.status == 'Accepted' || r.status == 'Receipt Confirmed';
        case 'cancelled':
          return r.status == 'Cancelled' || r.status == 'Rejected';
        case 'delivered':
          return r.distributed > 0 || r.status == 'Distributed';
        case 'disputed':
          return false;
        default:
          return true;
      }
    }).toList();
  }

  List<FertOrder> get _filteredOrders {
    return _myOrders.where((o) {
      switch (_orderStatusFilter) {
        case 'pending':
          return o.status == 'Pending Ack' || o.status == 'Negotiating';
        case 'accepted':
          return o.status == 'Accepted' || o.status == 'Stock Confirmed';
        case 'cancelled':
          return o.status == 'Cancelled';
        case 'delivered':
          return o.status == 'Distributed';
        case 'disputed':
          return FertilizerStore.instance.complaints.any(
            (c) => c.description.contains(o.id),
          );
        default:
          return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    if (!_isCdo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _store.checkLowStock(_shop);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _isCdo
        ? const [
            (Icons.calendar_month, 'Calendar'),
            (Icons.inbox_outlined, 'Orders'),
            (Icons.map_outlined, 'Area'),
            (Icons.warehouse_outlined, 'Stock'),
            (Icons.chat_bubble_outline, 'Messages'),
          ]
        : const [
            (Icons.calendar_month, 'Calendar'),
            (Icons.inbox_outlined, 'Orders'),
            (Icons.inventory_2_outlined, 'Stock'),
            (Icons.person_outline, 'Profile'),
          ];

    return FertPage(
      title: tabs[_tab].$2,
      subtitle:
          '${_isCdo ? 'CDO' : 'SUPPLIER'} \u00b7 ${_shop.company}'.toUpperCase(),
      showLogout: true,
      supplierAlerts: !_isCdo,
      bottom: FertTabBar(
        items: tabs,
        current: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
      child: _body(),
    );
  }

  Widget _body() {
    if (_tab == 0) {
      return SupplierCalendarPage(mode: widget.mode, embedded: true);
    }
    if (_isCdo) {
      switch (_tab) {
        case 1:
          return _ordersPage(cdo: true);
        case 2:
          return const FertilizerCdoAreaPage();
        case 3:
          return const FertilizerCdoStockPage();
        case 4:
          return const FertilizerCdoMessagesPage();
      }
    } else {
      switch (_tab) {
        case 1:
          return _ordersPage(cdo: false);
        case 2:
          return _supplierStockPage();
        case 3:
          return _profilePage();
      }
    }
    return const SizedBox.shrink();
  }

  Widget _ordersPage({required bool cdo}) {
    if (cdo) return _cdoOrdersPage();
    final list = _filteredOrders;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Orders',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Filter by status. Accept, negotiate, cancel, or dispute accepted jobs.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in [
                ('all', 'All'),
                ('pending', 'Pending'),
                ('accepted', 'Accepted'),
                ('cancelled', 'Cancelled'),
                ('delivered', 'Delivered'),
                ('disputed', 'Disputed'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(e.$2, style: const TextStyle(fontSize: 12)),
                    selected: _orderStatusFilter == e.$1,
                    onSelected: (_) =>
                        setState(() => _orderStatusFilter = e.$1),
                    selectedColor: AppColors.greenSoft,
                    checkmarkColor: AppColors.green,
                  ),
                ),
            ],
          ),
        ),
        if (_pending.isNotEmpty &&
            (_orderStatusFilter == 'all' ||
                _orderStatusFilter == 'pending')) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_pending.length} waiting for your acknowledgement',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.dangerText,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Text('No orders in this filter.',
              style: TextStyle(color: AppColors.muted))
        else
          for (final o in list) _orderCard(o),
      ],
    );
  }

  Widget _cdoOrdersPage() {
    final list = _filteredCdoRequests;
    final waiting = _store.pendingCdoAck.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Orders',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Open View to read the estate form. Accept or cancel only — no negotiation.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in [
                ('all', 'All'),
                ('pending', 'Pending'),
                ('accepted', 'Accepted'),
                ('cancelled', 'Cancelled'),
                ('delivered', 'Delivered'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(e.$2, style: const TextStyle(fontSize: 12)),
                    selected: _orderStatusFilter == e.$1,
                    onSelected: (_) =>
                        setState(() => _orderStatusFilter = e.$1),
                    selectedColor: AppColors.greenSoft,
                    checkmarkColor: AppColors.green,
                  ),
                ),
            ],
          ),
        ),
        if (waiting > 0 &&
            (_orderStatusFilter == 'all' ||
                _orderStatusFilter == 'pending')) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$waiting waiting for your acknowledgement',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.dangerText,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Text(
            'No government requests in this filter.',
            style: TextStyle(color: AppColors.muted),
          )
        else
          for (final r in list) _cdoRequestCard(r),
      ],
    );
  }

  Widget _cdoRequestCard(FertGovRequest r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.id} · ${r.fertilizer}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill.forStatus(r.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.owner} · ${r.requested} bags · ${shortDate(r.date)}'
            '${r.estateName.isEmpty ? '' : ' · ${r.estateName}'}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (r.nicCopy.isNotEmpty || r.landTitleCopy.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (r.nicCopy.isNotEmpty) 'NIC attached',
                if (r.landTitleCopy.isNotEmpty) 'Land title attached',
              ].join(' · '),
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () async {
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FertilizerCdoRequestSheet(request: r),
                );
                if (ok == true && mounted) setState(() {});
              },
              child: const Text('View'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(FertOrder o) {
    final canAck =
        o.status == 'Pending Ack' || o.status == 'Negotiating' || o.status == 'Submitted';
    final canDeliver =
        o.status == 'Accepted' || o.status == 'Stock Confirmed';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${o.id} · ${o.product}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              StatusPill.forStatus(o.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${o.owner} · ${o.qty50} × 50 kg · ${rupees(o.price)} · ${shortDate(o.preferredDate)} · ${o.slot}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canAck) ...[
                ElevatedButton(
                  onPressed: () {
                    _store.acceptOrder(o.id);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${o.id} accepted')),
                    );
                  },
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FertilizerSupplierChatPage(order: o),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  child: const Text('Negotiate'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                    backgroundColor: AppColors.dangerSoft,
                  ),
                  onPressed: () async {
                    final note = await showFertCancelReasons(
                      context,
                      title: 'Cancel ${o.id}',
                    );
                    if (note == null) return;
                    _store.cancelOrder(
                      o.id,
                      bySupplier: true,
                      note: note,
                    );
                    setState(() {});
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${o.id} cancelled · estate will see this'),
                      ),
                    );
                  },
                  child: const Text('Cancel'),
                ),
              ],
              if (canDeliver) ...[
                ElevatedButton(
                  onPressed: () {
                    _store.markDelivered(o.id);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${o.id} marked delivered')),
                    );
                  },
                  child: const Text('Mark delivered'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.dangerText,
                  ),
                  onPressed: () async {
                    final ok = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FertilizerDisputeSheet(
                        order: o,
                        bySupplier: true,
                      ),
                    );
                    if (ok == true && mounted) setState(() {});
                  },
                  child: const Text('Dispute'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _supplierStockPage() {
    final items = _shop.items;
    final low = items.where((i) => i.stock50 <= FertilizerStore.lowStockBags);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Stock',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Update bag counts and pack prices here. Low stock alerts show in Notifications.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        if (low.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              '${low.length} product${low.length == 1 ? '' : 's'} at or under ${FertilizerStore.lowStockBags} × 50 kg',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < items.length; i++) _stockCard(items[i]),
      ],
    );
  }

  Widget _stockCard(FertItem item) {
    final low = item.stock50 <= FertilizerStore.lowStockBags;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: low ? AppColors.warning : AppColors.line,
          width: low ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (low)
                const StatusPill(
                  'Low stock',
                  fg: AppColors.warning,
                  bg: Color(0xFFFFF3E0),
                ),
            ],
          ),
          Text(
            '${item.brand} · ${item.type}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Bags (50 kg)', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: item.stock <= 0
                    ? null
                    : () => setState(() {
                          item.stock = (item.stock - 1).clamp(0, 9999);
                          if (item.stock50 <= FertilizerStore.lowStockBags) {
                            _store.checkLowStock(_shop);
                          }
                        }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '${item.stock50}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  item.stock = (item.stock + 1).clamp(0, 9999);
                }),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pack price ${rupees(item.price)} · ${rupees(item.perKg)}/kg',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              TextButton(
                onPressed: () => _editPrice(item),
                child: const Text('Change price'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editPrice(FertItem item) async {
    final ctrl = TextEditingController(text: '${item.price}');
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Price · ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'New pack price (Rs.)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. transport cost up',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) {
      ctrl.dispose();
      reason.dispose();
      return;
    }
    final v = int.tryParse(ctrl.text.trim());
    ctrl.dispose();
    final why = reason.text.trim();
    reason.dispose();
    if (v == null || v <= 0) return;
    setState(() => item.price = v);
    _store.notifySupplier(
      title: 'Price updated · ${item.name}',
      body: why.isEmpty
          ? 'Now ${rupees(v)} per pack'
          : '${rupees(v)} per pack · $why',
      kind: 'info',
    );
  }

  Widget _profilePage() {
    final p = _shop;
    final defaultNote =
        'Delivers within ${p.distanceKm.toStringAsFixed(0)} km of Mawathagama.';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Profile',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Shop identity is fixed. You can edit contact, delivery willingness and coverage note.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.greenSoft,
                    child: Text(
                      p.company.isEmpty ? '?' : p.company[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.company,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const Text(
                          'Shop name · not editable',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Brands (locked)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(p.brandLine),
              const SizedBox(height: 4),
              Text(
                p.physical ? 'Physical shop' : 'Delivery-only',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: p.who,
                decoration: const InputDecoration(
                  labelText: 'Agent name',
                  isDense: true,
                ),
                onChanged: (v) => p.who = v.trim().isEmpty ? p.who : v.trim(),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: p.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  isDense: true,
                ),
                onChanged: (v) => p.phone = v.trim(),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Willing to deliver far'),
                subtitle: const Text(
                  'Estates outside your usual ring can still order',
                  style: TextStyle(fontSize: 12),
                ),
                value: p.willingFar,
                activeThumbColor: AppColors.green,
                onChanged: (v) => setState(() => p.willingFar = v),
              ),
              TextFormField(
                initialValue:
                    p.coverageNote.isEmpty ? defaultNote : p.coverageNote,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Coverage note',
                  alignLabelWithHint: true,
                ),
                onChanged: (v) => p.coverageNote = v.trim(),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile saved')),
                  );
                },
                child: const Text('Save profile'),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

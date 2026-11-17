import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

class FertilizerOrderSheet extends StatefulWidget {
  const FertilizerOrderSheet({
    super.key,
    required this.place,
    this.preselectedKinds = const {},
  });

  final FertPlace place;

  /// From the map Fertilizer filter. Matching items start ticked; others show unticked.
  final Set<String> preselectedKinds;

  @override
  State<FertilizerOrderSheet> createState() => _FertilizerOrderSheetState();
}

class _FertilizerOrderSheetState extends State<FertilizerOrderSheet> {
  late final List<bool> _on;
  late final List<int> _qty;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _slot = 'Morning 8–11';

  @override
  void initState() {
    super.initState();
    final items = widget.place.items;
    final n = items.length;
    _qty = List.filled(n, 1);
    // Why: if owner filtered APM on the map, only APM starts checked — others stay visible.
    if (widget.preselectedKinds.isEmpty) {
      _on = List.filled(n, true);
    } else {
      _on = [
        for (final item in items)
          item.kinds.any(widget.preselectedKinds.contains),
      ];
    }
  }

  int get _total {
    var t = 0;
    for (var i = 0; i < widget.place.items.length; i++) {
      if (!_on[i]) continue;
      t += widget.place.items[i].price50 * _qty[i];
    }
    return t;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _date = d);
  }

  void _submit() {
    final lines = <CartLine>[];
    for (var i = 0; i < widget.place.items.length; i++) {
      if (!_on[i] || _qty[i] < 1) continue;
      lines.add(CartLine(item: widget.place.items[i], qty50: _qty[i]));
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tick at least one fertilizer.')),
      );
      return;
    }
    if (widget.place.isGov) {
      Navigator.pop(
        context,
        GovOrderDraft(lines: lines, date: _date, slot: _slot),
      );
      return;
    }
    final store = FertilizerStore.instance;
    final order = FertOrder(
      id: store.nextId(),
      placeId: widget.place.id,
      company: widget.place.company,
      agent: widget.place.who,
      owner: 'Your Estate',
      product:
          lines.map((l) => '${l.item.brand} ${l.item.name} (50 kg)').join(', '),
      items: lines,
      qty50: lines.fold(0, (s, l) => s + l.qty50),
      price: _total,
      preferredDate: _date,
      slot: _slot,
      status: 'Pending Ack',
      message: 'Cart order · awaiting provider acknowledgement',
    );
    store.placeOrder(order);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, order);
    messenger.showSnackBar(
      SnackBar(content: Text('${order.id} sent as Pending Ack')),
    );
  }

  Widget _itemCard(int i) {
    final item = widget.place.items[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(
          color: _on[i] ? AppColors.green : AppColors.line,
          width: _on[i] ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _on[i],
                activeColor: AppColors.green,
                visualDensity: VisualDensity.compact,
                onChanged: (v) => setState(() => _on[i] = v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.type} · ${item.stock50} × 50 kg available',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      // Why: owners compare shops by Rs/kg, not only the 50 kg bag total.
                      '${rupees(item.perKg)}/kg · 50 kg ${rupees(item.price50)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_on[i])
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Row(
                children: [
                  const Text(
                    'Bags',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _qty[i] <= 1
                        ? null
                        : () => setState(() => _qty[i]--),
                    icon: const Icon(Icons.remove_circle_outline, size: 22),
                  ),
                  Text(
                    '${_qty[i]}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: _qty[i] >= item.stock50
                        ? null
                        : () => setState(() => _qty[i]++),
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

    // Why: phone-style sheet — list scrolls, Place order stays fixed at the bottom.
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH, maxWidth: 430),
          child: Material(
            color: AppColors.cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order · ${p.company}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      widget.preselectedKinds.isEmpty
                          ? '${p.brandLine} · Tick what you need. Bags are 50 kg.'
                          : 'Only ${widget.preselectedKinds.join(', ')} starts ticked. Other stock is shown so you can add it.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      shrinkWrap: true,
                      itemCount: p.items.length,
                      itemBuilder: (_, i) => _itemCard(i),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.line),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              rupees(_total),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickDate,
                                child: Text(
                                  shortDate(_date),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: _slot,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Morning 8–11',
                                    child: Text('Morning 8–11',
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Afternoon 12–3',
                                    child: Text('Afternoon 12–3',
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Evening 3–6',
                                    child: Text('Evening 3–6',
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                                onChanged: (v) =>
                                    setState(() => _slot = v ?? _slot),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.place.isGov
                              ? 'Next: estate details + NIC / land title, then CDO approval.'
                              : 'Stays Pending Ack until the provider accepts. Pay after that.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Place order'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

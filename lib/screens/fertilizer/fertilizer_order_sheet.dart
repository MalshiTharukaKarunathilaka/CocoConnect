import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// Place-order cart — sized for a phone bottom sheet (no giant empty gap).
class FertilizerOrderSheet extends StatefulWidget {
  const FertilizerOrderSheet({
    super.key,
    required this.place,
    this.preselectedTypes = const {},
  });

  final FertPlace place;

  /// From the map filter — those types start selected in the cart.
  final Set<String> preselectedTypes;

  @override
  State<FertilizerOrderSheet> createState() => _FertilizerOrderSheetState();
}

class _FertilizerOrderSheetState extends State<FertilizerOrderSheet> {
  late final Map<String, int> _qtyByType;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  String _slot = 'Morning 8–11';
  String? _dropdownPick;

  @override
  void initState() {
    super.initState();
    _qtyByType = {};
    final preset = widget.preselectedTypes
        .map((t) => t.toUpperCase())
        .where((t) => widget.place.itemForType(t) != null)
        .toSet();
    // Why: if owner filtered MOP on the map, cart opens with MOP already chosen.
    final start = preset.isNotEmpty
        ? preset
        : {widget.place.items.first.type.toUpperCase()};
    for (final code in start) {
      _qtyByType[code] = 1;
    }
  }

  List<FertItem> get _available => widget.place.items;

  List<String> get _selectedCodes => _qtyByType.keys.toList()..sort();

  List<String> get _addableCodes => _available
      .map((i) => i.type.toUpperCase())
      .where((c) => !_qtyByType.containsKey(c))
      .toList();

  int get _total {
    var t = 0;
    for (final e in _qtyByType.entries) {
      final item = widget.place.itemForType(e.key);
      if (item == null) continue;
      t += item.price50 * e.value;
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

  void _addFromDropdown(String? code) {
    if (code == null) return;
    setState(() {
      _qtyByType[code] = 1;
      _dropdownPick = null;
    });
  }

  void _submit() {
    final lines = <CartLine>[];
    for (final e in _qtyByType.entries) {
      final item = widget.place.itemForType(e.key);
      if (item == null || e.value < 1) continue;
      lines.add(CartLine(item: item, qty50: e.value));
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one fertilizer.')),
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
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${order.id} sent as Pending Ack')),
    );
  }

  Widget _lineCard(String code) {
    final p = widget.place;
    final item = p.itemForType(code)!;
    final qty = _qtyByType[code] ?? 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _qtyByType.remove(code)),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          Text(
            '${item.brand} · ${item.stock50} × 50 kg available',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            '50 kg base ${rupees(item.price50)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
          const SizedBox(height: 8),
          // Qty on its own row so thumbs can hit + / − on a phone.
          Row(
            children: [
              const Text(
                'Bags (50 kg)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: qty <= 1
                    ? null
                    : () => setState(() => _qtyByType[code] = qty - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$qty',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              IconButton(
                onPressed: qty >= item.stock50
                    ? null
                    : () => setState(() => _qtyByType[code] = qty + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    // Why: one scrollable sheet that hugs content — no Expanded empty middle on phones.
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order · ${p.company}',
                            style: const TextStyle(
                              fontSize: 17,
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
                    Text(
                      '${p.brandLine} · Quantities are in 50 kg units. '
                      'Use the dropdown to add more fertilizer types.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _dropdownPick,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Add fertilizer type',
                        isDense: true,
                      ),
                      hint: Text(
                        _addableCodes.isEmpty
                            ? 'All types from this supplier are in the cart'
                            : 'Choose a type to add',
                        style: const TextStyle(fontSize: 13),
                      ),
                      items: [
                        for (final code in _addableCodes)
                          DropdownMenuItem(
                            value: code,
                            child: Text(
                              '$code · ${rupees(p.itemForType(code)!.price50)} / 50 kg',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged:
                          _addableCodes.isEmpty ? null : _addFromDropdown,
                    ),
                    const SizedBox(height: 12),
                    if (_selectedCodes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Pick a fertilizer type from the dropdown.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    else
                      for (final code in _selectedCodes) _lineCard(code),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Cart total',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              Text(
                                rupees(_total),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Stack date + slot on narrow phones so they don’t squeeze.
                          OutlinedButton(
                            onPressed: _pickDate,
                            child: Text(shortDate(_date)),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _slot,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Time slot',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Morning 8–11',
                                child: Text('Morning 8–11'),
                              ),
                              DropdownMenuItem(
                                value: 'Afternoon 12–3',
                                child: Text('Afternoon 12–3'),
                              ),
                              DropdownMenuItem(
                                value: 'Evening 3–6',
                                child: Text('Evening 3–6'),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _slot = v ?? _slot),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'After you place the order it stays in Pending Ack until the provider accepts.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
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
      ),
    );
  }
}

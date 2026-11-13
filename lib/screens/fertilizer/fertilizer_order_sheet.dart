import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

// Keep cream/green look via design-system tokens.
const Color kOwnerCream = AppColors.cream;
const Color kOwnerGreen = AppColors.green;
const Color kOwnerMuted = AppColors.muted;
const Color kOwnerGreenSoft = AppColors.greenSoft;

class FertilizerOrderSheet extends StatefulWidget {
  const FertilizerOrderSheet({super.key, required this.place});
  final FertPlace place;

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
    final n = widget.place.items.length;
    _on = List.filled(n, true);
    _qty = List.filled(n, 1);
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
    final store = FertilizerStore.instance;
    final order = FertOrder(
      id: store.nextId(),
      placeId: widget.place.id,
      company: widget.place.company,
      agent: widget.place.who,
      owner: 'Your Estate',
      product: lines.map((l) => '${l.item.brand} ${l.item.name} (50 kg)').join(', '),
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

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: kOwnerCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Order · ${p.company}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kOwnerGreen,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${p.brandLine} · Quantities are in 50 kg units so bag sizes are easy to compare. '
              '${p.isGov ? 'Government programme. No negotiation.' : 'Private shop. You can negotiate before you send.'}',
              style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: p.items.length,
              separatorBuilder: (_, __) => const Divider(height: 18),
              itemBuilder: (_, i) {
                final item = p.items[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _on[i],
                          activeColor: kOwnerGreen,
                          onChanged: (v) => setState(() => _on[i] = v ?? false),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kOwnerGreenSoft,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: const Text(
                                      '50 kg',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: kOwnerGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${item.brand} · sold as ${item.unit} · ${item.stock50} × 50 kg available',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kOwnerMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${rupees(item.perKg)} / kg',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kOwnerMuted,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '50 kg base ${rupees(item.price50)}',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: !_on[i] || _qty[i] <= 1
                                  ? null
                                  : () => setState(() => _qty[i]--),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '${_qty[i]}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: !_on[i] || _qty[i] >= item.stock50
                                  ? null
                                  : () => setState(() => _qty[i]++),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Cart total',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      rupees(_total),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: kOwnerGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _pickDate,
                        child: Text(shortDate(_date)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _slot,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Morning 8–11',
                            child: Text('Morning 8–11', style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: 'Afternoon 12–3',
                            child: Text('Afternoon 12–3', style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: 'Evening 3–6',
                            child: Text('Evening 3–6', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (v) => setState(() => _slot = v ?? _slot),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'After you place the order it stays in Pending Ack until the provider accepts. Payment is after they accept.',
                  style: TextStyle(fontSize: 11.5, color: kOwnerMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: const Text(
                      'Place order',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

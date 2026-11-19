import 'package:flutter/material.dart';
import 'fertilizer_cancel_reasons.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// Edit a pending order: change bags / date / slot, or cancel the whole order.
class FertilizerOrderEditSheet extends StatefulWidget {
  const FertilizerOrderEditSheet({super.key, required this.order});

  final FertOrder order;

  @override
  State<FertilizerOrderEditSheet> createState() =>
      _FertilizerOrderEditSheetState();
}

class _FertilizerOrderEditSheetState extends State<FertilizerOrderEditSheet> {
  late final List<int> _qty;
  late DateTime _date;
  late String _slot;
  late final TextEditingController _note;

  FertOrder get o => widget.order;

  bool get _canEdit => o.status == 'Pending Ack' || o.status == 'Negotiating';

  @override
  void initState() {
    super.initState();
    _qty = [for (final l in o.items) l.qty50];
    _date = o.preferredDate;
    _slot = o.slot;
    _note = TextEditingController(text: o.message);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _total {
    var t = 0;
    for (var i = 0; i < o.items.length; i++) {
      t += o.items[i].item.price50 * _qty[i];
    }
    return t;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      builder: themedPicker,
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (d != null) setState(() => _date = d);
  }

  void _save() {
    if (!_canEdit) {
      Navigator.pop(context, false);
      return;
    }
    if (_qty.every((q) => q < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one bag, or cancel the order.'),
        ),
      );
      return;
    }
    for (var i = 0; i < o.items.length; i++) {
      o.items[i].qty50 = _qty[i];
    }
    o.preferredDate = _date;
    o.slot = _slot;
    o.message = _note.text.trim().isEmpty
        ? 'Cart order · awaiting provider acknowledgement'
        : _note.text.trim();
    o.refreshTotals();
    Navigator.pop(context, true);
  }

  Future<void> _cancelOrder() async {
    final note = await showFertCancelReasons(context, title: 'Cancel Fertilizer Order');
    if (note == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final id = o.id;
    FertilizerStore.instance.cancelOrder(id, note: note);
    Navigator.pop(context, true);
    messenger.showSnackBar(SnackBar(content: Text('$id cancelled')));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height * 0.92;

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
              child: ListView(
                shrinkWrap: true,
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
                            'Edit · ${o.id}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context, false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      _canEdit
                          ? '${o.company} · Change bags, date or slot. Cancel the order below if you do not need it.'
                          : '${o.company} · This order is ${o.status}, so it cannot be changed.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.zero,
                    child: ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      children: [
                        for (var i = 0; i < o.items.length; i++) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppRadius.field,
                              ),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  o.items[i].item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  '${rupees(o.items[i].item.perKg)}/kg · 50 kg ${rupees(o.items[i].item.price50)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.green,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Text(
                                      'Bags',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: !_canEdit || _qty[i] <= 0
                                          ? null
                                          : () => setState(() => _qty[i]--),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                        size: 22,
                                      ),
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
                                      onPressed:
                                          !_canEdit ||
                                              _qty[i] >= o.items[i].item.stock50
                                          ? null
                                          : () => setState(() => _qty[i]++),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        OutlinedButton(
                          onPressed: _canEdit ? _pickDate : null,
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
                          onChanged: !_canEdit
                              ? null
                              : (v) => setState(() => _slot = v ?? _slot),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _note,
                          enabled: _canEdit,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Note to supplier',
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),

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
                        if (_canEdit) ...[
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _save,
                            child: const Text('Save changes'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.dangerText,
                              backgroundColor: AppColors.dangerSoft,
                              minimumSize: const Size(0, 44),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _cancelOrder,
                            child: const Text('Cancel order'),
                          ),
                        ] else
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Close'),
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

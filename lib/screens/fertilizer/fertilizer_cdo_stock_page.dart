import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// CDO warehouse stock — same card layout as supplier stock, but no price edit.
class FertilizerCdoStockPage extends StatefulWidget {
  const FertilizerCdoStockPage({super.key});

  @override
  State<FertilizerCdoStockPage> createState() => _FertilizerCdoStockPageState();
}

class _FertilizerCdoStockPageState extends State<FertilizerCdoStockPage> {
  final _store = FertilizerStore.instance;
  final _qtyCtrl = TextEditingController();
  String? _pickedType;
  final _customType = TextEditingController();
  bool _useCustom = false;

  /// Why: form stays hidden until the CDO taps Add fertilizer.
  bool _showAddForm = false;

  static const _catalog = [
    'ERP Coconut Fertilizer',
    'Urea subsidy',
    'MOP',
    'Dolomite',
    'TSP',
    'APM',
  ];

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _customType.dispose();
    super.dispose();
  }

  void _add() {
    final type = _useCustom ? _customType.text.trim() : (_pickedType ?? '');
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (type.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a fertilizer type and enter a bag quantity.'),
        ),
      );
      return;
    }
    setState(() {
      _store.receiveCdoStock(type, qty);
      _qtyCtrl.clear();
      _customType.clear();
      _useCustom = false;
      _pickedType = null;
      _showAddForm = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Recorded +$qty bags of $type')));
  }

  @override
  Widget build(BuildContext context) {
    final lines = _store.myCdoStock;
    final low = lines.where((l) => l.level == 'low').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const Text(
          'Stock',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Update bag counts here. Pack prices are set by the board — CDO cannot change them. Low stock alerts show in Notifications.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        // Why: same “Enter fertilizer stock” row as supplier, opens the add form.
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _showAddForm = !_showAddForm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showAddForm
                          ? 'Close add form'
                          : 'Enter fertilizer stock',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Icon(
                    _showAddForm ? Icons.close : Icons.add_circle,
                    color: AppColors.green,
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_showAddForm) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add fertilizer',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose a fertilizer type and enter bags (50 kg).',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fertilizer type',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in _catalog)
                      ChoiceChip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        selected: !_useCustom && _pickedType == t,
                        selectedColor: AppColors.greenSoft,
                        onSelected: (_) => setState(() {
                          _useCustom = false;
                          _pickedType = t;
                        }),
                      ),
                    ChoiceChip(
                      label: const Text(
                        'Other',
                        style: TextStyle(fontSize: 12),
                      ),
                      selected: _useCustom,
                      selectedColor: AppColors.greenSoft,
                      onSelected: (_) => setState(() {
                        _useCustom = true;
                        _pickedType = null;
                      }),
                    ),
                  ],
                ),
                if (_useCustom) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _customType,
                    decoration: const InputDecoration(
                      labelText: 'Type name',
                      isDense: true,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity (50 kg bags)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_box_outlined),
                    label: const Text('Save to stock'),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        if (lines.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              'No stock lines yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (final line in lines) ...[
            _stockCard(line),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  /// Why: matches supplier stock cards so CDO and supplier feel the same.
  Widget _stockCard(FertCdoStockLine line) {
    final low = line.level == 'low';
    final empty = line.level == 'not available';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: low || empty
              ? AppColors.warning.withValues(alpha: 0.55)
              : AppColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.type,
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
              if (empty)
                const StatusPill(
                  'Empty',
                  fg: AppColors.dangerText,
                  bg: AppColors.dangerSoft,
                ),
            ],
          ),
          Text(
            'CDO warehouse · ${line.type}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              const Text(
                'Bags (50 kg)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: line.bags <= 0
                    ? null
                    : () => setState(() {
                        _store.adjustCdoStock(line.type, -1);
                        _store.checkCdoLowStock();
                      }),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '${line.bags}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _store.adjustCdoStock(line.type, 1);
                }),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          // Why: show pack price for clarity, but no “Change price” — CDO cannot edit it.
          Text(
            'Pack price ${rupees(line.packPrice)} · ${rupees(line.perKg)}/kg',
            style: const TextStyle(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

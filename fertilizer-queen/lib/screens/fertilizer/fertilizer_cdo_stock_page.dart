import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'fertilizer_data.dart';

/// CDO warehouse stock — add new lines behind a button; +/- each row.
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Recorded +$qty bags of $type')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = _store.myCdoStock;
    final available = lines.where((l) => l.level == 'available').length;
    final low = lines.where((l) => l.level == 'low').length;
    final empty = lines.where((l) => l.level == 'not available').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF1F4E3A), Color(0xFF2F6B4E)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stock',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Record fertilizer received at ${_store.myShop.who}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _topStat('$available', 'Available'),
                  _topStat('$low', 'Low'),
                  _topStat('$empty', 'Empty'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _showAddForm = !_showAddForm),
            icon: Icon(_showAddForm ? Icons.close : Icons.add),
            label: Text(_showAddForm ? 'Close add form' : 'Add fertilizer'),
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
                  'Choose a fertilizer type and enter bags.',
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
                      label: const Text('Other', style: TextStyle(fontSize: 12)),
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
        const SizedBox(height: 18),
        const Text(
          'Stock table',
          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F1EA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Fertilizer',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Bags',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Status',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (lines.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No stock lines yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                )
              else
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _stockRow(lines[i]),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stockRow(FertCdoStockLine line) {
    final (fg, bg, label) = switch (line.level) {
      'available' => (AppColors.green, AppColors.greenSoft, 'Available'),
      'low' => (AppColors.warning, AppColors.warningSoft, 'Low'),
      _ => (AppColors.dangerText, AppColors.dangerSoft, 'Not available'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              line.type,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: line.bags <= 0
                      ? null
                      : () => setState(
                            () => _store.adjustCdoStock(line.type, -1),
                          ),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                ),
                Text(
                  '${line.bags}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => setState(
                    () => _store.adjustCdoStock(line.type, 1),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

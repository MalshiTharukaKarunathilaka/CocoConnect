import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'fertilizer_data.dart';

/// Estate owner government programme request (demo).
class FertilizerGovRequestSheet extends StatefulWidget {
  const FertilizerGovRequestSheet({super.key});

  @override
  State<FertilizerGovRequestSheet> createState() =>
      _FertilizerGovRequestSheetState();
}

class _FertilizerGovRequestSheetState extends State<FertilizerGovRequestSheet> {
  int _qty = 12;

  void _submit() {
    final store = FertilizerStore.instance;
    store.placeGovRequest(
      FertGovRequest(
        id: 'FR-${1000 + store.govRequests.length + 1}',
        owner: 'Your Estate',
        fertilizer: 'ERP Coconut Fertilizer (50 kg)',
        requested: _qty,
        status: 'Pending Ack',
        cdo: 'CDO - Mawathagama',
        date: DateTime.now(),
        district: 'Kurunegala',
      ),
    );
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Government request sent · Pending Ack'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = FertilizerStore.instance.areaStock.first;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Request Board fertilizer',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.green,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Sample stock and area labels only — not official CCB inventory.',
              style: TextStyle(fontSize: 12.5, color: AppColors.warning),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${stock['product']} · ${stock['bags']} bags listed near CDO Area 01',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          const Text('Quantity (50 kg bags)', style: TextStyle(fontWeight: FontWeight.w700)),
          Row(
            children: [
              IconButton(
                onPressed: _qty <= 1 ? null : () => setState(() => _qty--),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_qty',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: () => setState(() => _qty++),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _submit,
            child: const Text('Submit government request'),
          ),
        ],
      ),
    );
  }
}

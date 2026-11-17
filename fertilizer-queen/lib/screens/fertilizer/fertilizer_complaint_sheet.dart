import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'fertilizer_data.dart';

class FertilizerComplaintSheet extends StatefulWidget {
  const FertilizerComplaintSheet({super.key});

  @override
  State<FertilizerComplaintSheet> createState() =>
      _FertilizerComplaintSheetState();
}

class _FertilizerComplaintSheetState extends State<FertilizerComplaintSheet> {
  String _category = 'Product quality';
  final _desc = TextEditingController();

  static const _cats = [
    'Product quality',
    'Incorrect quantity',
    "Didn't receive the fertilizer",
    'Wrong product',
  ];

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    if (_desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue')),
      );
      return;
    }
    final store = FertilizerStore.instance;
    store.addComplaint(
      FertComplaint(
        id: 'QC-${200 + store.complaints.length + 1}',
        category: _category,
        product: 'ERP Coconut Fertilizer',
        status: 'Submitted',
        date: DateTime.now(),
        description: _desc.text.trim(),
        owner: 'Your Estate',
        district: 'Kurunegala',
      ),
    );
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Complaint submitted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'File a quality complaint',
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
            const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [
                for (final c in _cats)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            const Text('What happened?', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _desc,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe the issue…',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit complaint'),
            ),
          ],
        ),
      ),
    );
  }
}

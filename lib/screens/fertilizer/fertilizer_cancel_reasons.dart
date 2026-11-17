import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

const List<String> kFertCancelReasons = [
  'Out of stock',
  'Cannot deliver on that date',
  'Price not workable',
  'Outside my coverage area',
  'Duplicate / wrong order',
];

/// Why: CDO government forms are not priced / shop-coverage based.
const List<String> kFertCdoCancelReasons = [
  'Out of stock',
  'Cannot deliver on that date',
  'Documents incomplete',
  'Estate not eligible',
  'Duplicate / wrong order',
];

/// Checkbox reasons + optional Other text. Returns null if cancelled, else reason string.
Future<String?> showFertCancelReasons(
  BuildContext context, {
  required String title,
  bool forCdo = false,
}) async {
  final reasons = forCdo ? kFertCdoCancelReasons : kFertCancelReasons;
  final selected = <String>{};
  final other = TextEditingController();
  var useOther = false;

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Material(
              color: AppColors.cream,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: StatefulBuilder(
                builder: (context, setLocal) {
                  return SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pick one or more reasons. The estate will see this.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final r in reasons)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: selected.contains(r),
                              activeColor: AppColors.green,
                              title: Text(r, style: const TextStyle(fontSize: 14)),
                              onChanged: (v) => setLocal(() {
                                if (v == true) {
                                  selected.add(r);
                                } else {
                                  selected.remove(r);
                                }
                              }),
                            ),
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: useOther,
                            activeColor: AppColors.green,
                            title: const Text(
                              'Other',
                              style: TextStyle(fontSize: 14),
                            ),
                            onChanged: (v) =>
                                setLocal(() => useOther = v ?? false),
                          ),
                          if (useOther)
                            TextField(
                              controller: other,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText: 'Type your reason…',
                                isDense: true,
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Back'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.dangerText,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    final parts = <String>[...selected];
                                    if (useOther &&
                                        other.text.trim().isNotEmpty) {
                                      parts.add(other.text.trim());
                                    }
                                    if (parts.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Pick a reason or type Other.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pop(ctx, parts.join(' · '));
                                  },
                                  child: const Text('Cancel order'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
  other.dispose();
  return result;
}

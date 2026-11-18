import '../../widgets/mobile_sheet.dart';
import 'package:flutter/material.dart';
import 'fertilizer_chrome.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_complaint_sheet.dart';
import 'fertilizer_data.dart';

/// Quality complaints — matches the HTML demo tab.
class FertilizerComplaintsPage extends StatefulWidget {
  const FertilizerComplaintsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<FertilizerComplaintsPage> createState() =>
      _FertilizerComplaintsPageState();
}

class _FertilizerComplaintsPageState extends State<FertilizerComplaintsPage> {
  @override
  Widget build(BuildContext context) {
    final list = FertilizerStore.instance.complaints;

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () async {
              final ok = await showModalBottomSheet<bool>(
                useSafeArea: true,
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: mobileSheetBuilder(
                  (_) => const FertilizerComplaintSheet(),
                ),
              );
              if (ok == true && mounted) setState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('New complaint'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quality complaints and order disputes (wrong bags, late delivery, billing) show here.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.callout),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text(
              'No complaints or disputes yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (final c in list)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.category,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      StatusPill.forStatus(c.status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${c.id} · ${c.product} · ${shortDate(c.date)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(c.description, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(color: AppColors.cream, child: body);
    }
    return FertPage(
      title: 'Quality complaints',
      subtitle: 'FERTILIZER \u00b7 LAND OWNER',
      child: body,
    );
  }
}

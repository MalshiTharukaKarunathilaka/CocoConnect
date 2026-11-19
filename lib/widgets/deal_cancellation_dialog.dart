import 'package:flutter/material.dart';

enum DealCancellationType {
  coconut('Cancel Coconut Deal', [
    'Issue with coconut quantity',
    'Issue with coconut quality or condition',
    'Issue with the agreed price',
    'Issue with the collection date or time',
    'Issue with transport or the collection location',
    'Personal or business circumstances changed',
  ]),
  machinery('Cancel Machinery Booking', [
    'Machine broke down or is unavailable',
    'Operator is unavailable',
    'Weather or field conditions prevent work',
    'Access to the land is blocked',
    'Booking time or work requirements changed',
    'Price or payment disagreement',
  ]),
  dayJob('Cancel Day Job', [
    'Worker is unavailable or did not show up',
    'Work schedule changed',
    'Weather or site conditions prevent work',
    'Payment or working hours dispute',
  ]),
  dayJobCompletion('Cancel Job Completion', [
    'Work not finished yet',
    'Incomplete or poor quality work',
    'Workers left early / did not show up',
    'Payment or working hours dispute',
    'Job is not needed now',
    'Bad weather or site problem',
    'Not enough workers',
    'Workers are not available',
    'Job was posted by mistake',
  ]),
  dayJobWithdrawal('Withdraw from Day Job', [
    'Schedule changed',
    'Bad weather or site problem',
    'Not enough workers',
    'Unable to complete the work',
  ]),
  fertilizer('Cancel Fertilizer Order', [
    'Fertilizer is out of stock',
    'Product or quantity differs from the agreement',
    'Delivery or collection cannot go ahead',
    'Price or payment disagreement',
  ]),
  fertilizerCdo('Cancel Fertilizer Request', [
    'Fertilizer is out of stock',
    'Collection or delivery cannot go ahead',
    'Documents are incomplete',
    'Land does not meet eligibility requirements',
    'Duplicate or incorrect request',
  ]);

  const DealCancellationType(this.title, this.reasons);

  final String title;
  final List<String> reasons;
}

Future<Map<String, String>?> showDealCancellationDialog(
  BuildContext context, {
  required DealCancellationType type,
  String? title,
}) {
  const cream = Color(0xFFFAF7EE);
  const red = Color(0xFFA4251C);
  const muted = Color(0xFF596273);
  const ink = Color(0xFF152238);
  String? reason;
  var note = '';

  return showDialog<Map<String, String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        backgroundColor: cream,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: red, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title ?? type.title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 310,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                type == DealCancellationType.dayJobCompletion
                    ? 'Select why you are not confirming completion:'
                    : 'Select a reason for cancelling:',
                style: const TextStyle(color: muted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              RadioGroup<String>(
                groupValue: reason,
                onChanged: (value) => setState(() => reason = value),
                child: Column(
                  children: [
                    for (final item in [...type.reasons, 'Other'])
                      RadioListTile<String>(
                        value: item,
                        activeColor: red,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item,
                          style: TextStyle(
                            color: ink,
                            fontSize: 13,
                            fontWeight: reason == item
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text('Optional note:', style: TextStyle(color: muted, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                minLines: 3,
                maxLines: 3,
                maxLength: 500,
                onChanged: (value) => note = value.trim(),
                decoration: InputDecoration(
                  hintText: 'Add a note for the other party...',
                  hintStyle: const TextStyle(color: muted, fontSize: 13),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: muted,
                    side: const BorderSide(color: Color(0xFFE3DFD8)),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: reason == null
                      ? null
                      : () => Navigator.pop(context, {'reason': reason!, 'note': note}),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(
                    type == DealCancellationType.dayJobWithdrawal ? 'Withdraw' : 'Submit Cancel',
                    textAlign: TextAlign.center,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: red,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

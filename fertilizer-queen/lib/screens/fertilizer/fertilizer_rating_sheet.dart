import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Star rating after an order is completed (owner ↔ supplier / CDO).
class FertilizerRatingSheet extends StatefulWidget {
  const FertilizerRatingSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onSubmit,
  });

  final String title;
  final String subtitle;
  final void Function(int stars, String note) onSubmit;

  @override
  State<FertilizerRatingSheet> createState() => _FertilizerRatingSheetState();
}

class _FertilizerRatingSheetState extends State<FertilizerRatingSheet> {
  int _stars = 5;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
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
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars ? Icons.star : Icons.star_border,
                    color: const Color(0xFFE6A700),
                    size: 34,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              widget.onSubmit(_stars, _note.text.trim());
              Navigator.pop(context, true);
            },
            child: const Text('Submit rating'),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showFertilizerRatingSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required void Function(int stars, String note) onSubmit,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FertilizerRatingSheet(
      title: title,
      subtitle: subtitle,
      onSubmit: onSubmit,
    ),
  );
}

import 'package:flutter/material.dart';

Future<int?> showLandOwnerRatingDialog(
  BuildContext context, {
  String party = 'land owner',
}) => showDialog<int>(
  context: context,
  builder: (context) {
    var rating = 0;
    return StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        scrollable: true,
        title: Text('Rate $party'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How was your experience with this $party?'),
            const SizedBox(height: 12),
            Wrap(
              children: [
                for (var value = 1; value <= 5; value++)
                  IconButton(
                    tooltip: '$value star${value == 1 ? '' : 's'}',
                    onPressed: () => setState(() => rating = value),
                    icon: Icon(
                      value <= rating ? Icons.star : Icons.star_border,
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
            Text(rating == 0 ? 'Choose 1 to 5 stars' : '$rating / 5'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: rating == 0
                ? null
                : () => Navigator.pop(context, rating),
            child: const Text('Submit rating'),
          ),
        ],
      ),
    );
  },
);

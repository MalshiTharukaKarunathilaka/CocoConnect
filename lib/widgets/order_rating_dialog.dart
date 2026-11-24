import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../services/api_client.dart';

Future<bool> showOrderRating(BuildContext context, OrderItem order) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _OrderRatingDialog(order: order),
    ) ==
    true;

class _OrderRatingDialog extends StatefulWidget {
  final OrderItem order;
  const _OrderRatingDialog({required this.order});
  @override
  State<_OrderRatingDialog> createState() => _OrderRatingDialogState();
}

class _OrderRatingDialogState extends State<_OrderRatingDialog> {
  int _rating = 0;
  String _note = '';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ActivityService.rateOrder(widget.order.id, _rating, note: _note);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.order.iAmBuyer ? 'Rate seller' : 'Rate buyer'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.order.counterpartName),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (var star = 1; star <= 5; star++)
              IconButton(
                tooltip: '$star stars',
                onPressed: _saving
                    ? null
                    : () => setState(() => _rating = star),
                icon: Icon(
                  star <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber.shade800,
                ),
              ),
          ],
        ),
        Text(_rating == 0 ? 'Choose 1 to 5 stars' : '$_rating out of 5 stars'),
        const SizedBox(height: 12),
        TextField(
          enabled: !_saving,
          minLines: 2,
          maxLines: 3,
          maxLength: 500,
          onChanged: (value) => _note = value.trim(),
          decoration: const InputDecoration(
            labelText: 'Comment (optional)',
            helperText: 'Comments appear on the other person’s profile.',
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Later'),
      ),
      FilledButton(
        onPressed: _saving || _rating == 0 ? null : _save,
        child: Text(_saving ? 'Saving...' : 'Submit rating'),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/provider_booking_request.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'provider_request_widgets.dart';

/// The estate owner changes the price and the request (the work, the date and
/// the time). Returns the body for `POST /api/machinery/bookings/:id/revise`,
/// or null when cancelled. The provider can then only accept or decline it.
Future<Map<String, dynamic>?> showReviseRequestDialog(
  BuildContext context,
  ProviderBookingRequest request,
) => showThemedDialog<Map<String, dynamic>>(
  context: context,
  builder: (_) => _ReviseDialog(request: request),
);

class _ReviseDialog extends StatefulWidget {
  final ProviderBookingRequest request;
  const _ReviseDialog({required this.request});

  @override
  State<_ReviseDialog> createState() => _ReviseDialogState();
}

class _ReviseDialogState extends State<_ReviseDialog> {
  late final List<TextEditingController> _qty = [
    for (final item in widget.request.items)
      TextEditingController(text: _plain(item['quantity'])),
  ];
  late final _total = TextEditingController(
    text: _plain(widget.request.proposedTotal),
  );
  final _message = TextEditingController();
  late DateTime _day = DateTime(
    widget.request.startsAt.year,
    widget.request.startsAt.month,
    widget.request.startsAt.day,
  );
  late TimeOfDay _start = TimeOfDay.fromDateTime(widget.request.startsAt);
  late TimeOfDay _end = TimeOfDay.fromDateTime(widget.request.endsAt);
  bool _totalTouched = false;
  String? _error;

  static String _plain(dynamic value) {
    final double n = double.tryParse('$value') ?? 0;
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();
  }

  @override
  void dispose() {
    for (final c in _qty) {
      c.dispose();
    }
    _total.dispose();
    _message.dispose();
    super.dispose();
  }

  double _rateOf(int i) =>
      double.tryParse('${widget.request.items[i]['rate']}') ?? 0;

  bool _perDay(int i) => widget.request.items[i]['unit'] == 'day';

  /// The work at the provider's rates, from the quantities typed so far.
  double get _listTotal {
    double sum = 0;
    for (int i = 0; i < _qty.length; i++) {
      final double q = double.tryParse(_qty[i].text.trim()) ?? 0;
      sum += _rateOf(i) * q;
    }
    return sum;
  }

  /// While the owner has not typed a price of their own, it follows the work.
  void _quantityChanged() {
    if (_totalTouched) return;
    setState(() => _total.text = _plain(_listTotal.roundToDouble()));
  }

  DateTime _utc(TimeOfDay time, DateTime day) => DateTime.utc(
    day.year,
    day.month,
    day.day,
    time.hour,
    time.minute,
  ).subtract(const Duration(minutes: 330));

  Future<void> _pickDay() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(now) ? now : _day,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: themedPicker,
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _pickTime(bool start) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: themedPicker,
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  void _submit() {
    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < _qty.length; i++) {
      final double? q = double.tryParse(_qty[i].text.trim());
      final item = widget.request.items[i];
      if (q == null || !q.isFinite || q <= 0 || q > 100000000) {
        setState(() => _error = 'Enter an amount of work for ${item['name']}.');
        return;
      }
      if ((q * 100 - (q * 100).roundToDouble()).abs() > 0.00001) {
        setState(() => _error = 'Use at most two decimal places.');
        return;
      }
      if (_perDay(i) && q != q.roundToDouble()) {
        setState(() => _error = '${item['name']} is charged per whole day.');
        return;
      }
      items.add({'service_id': item['service_id'], 'quantity': q});
    }
    final double? total = double.tryParse(_total.text.trim());
    if (total == null || !total.isFinite || total <= 0 || total > 100000000) {
      setState(() => _error = 'Enter your offer for the whole job in rupees.');
      return;
    }
    final DateTime start = _utc(_start, _day);
    final DateTime end = _utc(_end, _day);
    if (!end.isAfter(start)) {
      setState(() => _error = 'The end time must be after the start time.');
      return;
    }
    Navigator.pop(context, {
      'items': items,
      'offer_total': total,
      'starts_at': start.toIso8601String(),
      'ends_at': end.toIso8601String(),
      if (_message.text.trim().isNotEmpty) 'message': _message.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    return AlertDialog(
      title: const Text('Change price or request'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The provider can only accept or decline. Anything you change here goes back to them as a new offer.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            for (int i = 0; i < _qty.length; i++) ...[
              TextField(
                key: Key('revise-qty-$i'),
                controller: _qty[i],
                onChanged: (_) => _quantityChanged(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: '${request.items[i]['name']}',
                  suffixText:
                      '${request.items[i]['unit']}s  ·  ${rupees(_rateOf(i))}/${request.items[i]['unit']}',
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              key: const Key('revise-total'),
              controller: _total,
              onChanged: (_) => _totalTouched = true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Your offer for the whole job',
                prefixText: 'Rs. ',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'At the provider\'s rates this work is ${rupees(_listTotal.round())}.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined, color: AppColors.green),
              title: const Text('Service date'),
              subtitle: Text(requestDate(_day)),
              onTap: _pickDay,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start'),
                    subtitle: Text(_start.format(context)),
                    onTap: () => _pickTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End'),
                    subtitle: Text(_end.format(context)),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            TextField(
              key: const Key('revise-message'),
              controller: _message,
              maxLength: 500,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message to the provider (optional)',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12.5,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('revise-send'),
          onPressed: _submit,
          child: const Text('Send new offer'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/machinery_api.dart';
import '../services/api_client.dart';
import '../widgets/owner_widgets.dart';
import 'provider/provider_request_page.dart';

/// Captures the explicit interval missing from the old demonstration booking.
Future<void> requestLiveMachinery(
  BuildContext context, {
  required int machineId,
  required DateTime date,
  required List<Map<String, dynamic>> items,
}) async {
  final request = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _RequestDialog(date: date, items: items),
  );
  if (request == null || !context.mounted) return;
  try {
    final saved = await const MachineryApi().createBooking(machineId, request);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderRequestPage(
          request: saved,
          api: const MachineryApi(),
          isOwner: true,
        ),
      ),
    );
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _RequestDialog extends StatefulWidget {
  final DateTime date;
  final List<Map<String, dynamic>> items;
  const _RequestDialog({required this.date, required this.items});
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _estate = TextEditingController();
  late final _address = TextEditingController(
    text: AuthService.currentUser?.location ?? '',
  );
  final _offer = TextEditingController();
  TimeOfDay _start = const TimeOfDay(hour: 7, minute: 30),
      _end = const TimeOfDay(hour: 12, minute: 0);
  String? _error;
  @override
  void dispose() {
    _estate.dispose();
    _address.dispose();
    _offer.dispose();
    super.dispose();
  }

  DateTime _utc(TimeOfDay time) => DateTime.utc(
    widget.date.year,
    widget.date.month,
    widget.date.day,
    time.hour,
    time.minute,
  ).subtract(const Duration(minutes: 330));
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Request Machinery'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _estate,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Estate name'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your estate name' : null,
            ),
            TextFormField(
              controller: _address,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Job address'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the job address' : null,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start time'),
              subtitle: Text(_start.format(context)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _start,
                );
                if (time != null && mounted) setState(() => _start = time);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End time'),
              subtitle: Text(_end.format(context)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _end,
                );
                if (time != null && mounted) setState(() => _end = time);
              },
            ),
            const Text(
              'Times are in Sri Lanka time. Only this interval is requested.',
              style: TextStyle(fontSize: 12, color: kOwnerMuted),
            ),
            TextFormField(
              controller: _offer,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Offer total (optional)',
                prefixText: 'Rs. ',
                hintText: 'Use listed total',
              ),
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return null;
                final n = double.tryParse(v!);
                return n == null || !n.isFinite || n <= 0 || n > 100000000
                    ? 'Enter a valid positive total'
                    : null;
              },
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: kOwnerRed)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          final start = _utc(_start), end = _utc(_end);
          if (!start.isAfter(DateTime.now().toUtc()) || !end.isAfter(start)) {
            setState(
              () => _error = 'Choose a future start time and a later end time.',
            );
            return;
          }
          Navigator.pop(context, {
            'starts_at': start.toIso8601String(),
            'ends_at': end.toIso8601String(),
            'estate_name': _estate.text.trim(),
            'address': _address.text.trim(),
            'items': widget.items,
            if (_offer.text.trim().isNotEmpty)
              'offered_total': double.parse(_offer.text),
          });
        },
        child: const Text('Send Booking Request'),
      ),
    ],
  );
}

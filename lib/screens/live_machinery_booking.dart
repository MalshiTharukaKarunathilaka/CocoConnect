import 'package:flutter/material.dart';
import '../services/owner_service.dart';
import '../widgets/auto_filled_field.dart';
import 'account_dialogs.dart';
import 'buyer/buyer_format.dart';
import '../services/machinery_api.dart';
import '../services/api_client.dart';
import '../widgets/owner_widgets.dart';
import 'provider/provider_request_page.dart';
import '../theme/app_theme.dart';
import '../models/provider_booking_request.dart';
import '../services/auth_service.dart';
import '../widgets/machinery_widgets.dart';
import 'provider/revise_request_dialog.dart';

Future<void> openMachineryBooking(
  BuildContext context, {
  required MachineInfo machine,
  required DateTime date,
  required List<Map<String, dynamic>> items,
  required double listedTotal,
  required bool negotiate,
}) async {
  const api = MachineryApi();
  const offset = Duration(minutes: 330);
  DateTime utc(DateTime day) => DateTime.utc(
    day.year, day.month, day.day, day.hour, day.minute,
  ).subtract(offset);

  try {
    final land = await OwnerService.getEstate();
    if (!context.mounted) return;
    final estate = land.estateName.trim();
    final address = land.location?.trim() ?? '';
    if (estate.isEmpty || address.isEmpty) {
      throw const ApiException('Add your land name and location in your profile before booking.');
    }
    final wallTime = DateTime.now().toUtc().add(offset + const Duration(minutes: 5));
    final now = DateTime(wallTime.year, wallTime.month, wallTime.day, wallTime.hour, wallTime.minute);
    final defaultStart = DateTime(date.year, date.month, date.day, 8);
    final start = defaultStart.isBefore(now) ? now : defaultStart;
    final end = DateTime(date.year, date.month, date.day, 17);
    if (!end.isAfter(start)) {
      throw const ApiException('Working hours have ended. Select a later date.');
    }
    final draft = ProviderBookingRequest(
      id: '',
      machineId: '${machine.databaseId}',
      machineName: machine.name,
      ownerName: AuthService.currentUser?.name ?? estate,
      providerName: machine.provider,
      estateName: estate,
      address: address,
      providerAt: machine.location,
      machinery: machineLabel(machine.type),
      service: items.map((item) => item['name']).join(', '),
      quantity: 1,
      unit: 'booking',
      startsAt: start,
      endsAt: end,
      proposedRate: listedTotal,
      items: items,
    );

    Future<ProviderBookingRequest> submit(Map<String, dynamic> body) =>
        api.createBooking(machine.databaseId!, {
          'estate_name': estate,
          'address': address,
          'starts_at': utc(start).toIso8601String(),
          'ends_at': utc(end).toIso8601String(),
          'items': [
            for (final item in items)
              {'service_id': item['service_id'], 'quantity': item['quantity']},
          ],
          ...body,
          'offered_total': body['offer_total'] ?? listedTotal,
        });

    if (negotiate) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderRequestPage(
            request: draft,
            api: api,
            isOwner: true,
            submitDraft: submit,
          ),
        ),
      );
    } else {
      final body = await showReviseRequestDialog(context, draft, initialRequest: true);
      if (body == null || !context.mounted) return;
      final saved = await submit(body);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderRequestPage(
            request: saved,
            api: api,
            isOwner: true,
          ),
        ),
      );
    }
  } on ApiException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// Captures the explicit interval missing from the old demonstration booking.
Future<void> requestLiveMachinery(
  BuildContext context, {
  required int machineId,
  required DateTime date,
  required List<Map<String, dynamic>> items,
  double? listedTotal,
}) async {
  final request = await showThemedDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) =>
        _RequestDialog(date: date, items: items, listedTotal: listedTotal),
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
  final double? listedTotal;
  const _RequestDialog({
    required this.date,
    required this.items,
    this.listedTotal,
  });
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _estate = TextEditingController();
  final _address = TextEditingController();
  Estate? _land;
  bool _loadingLand = true;
  String? _landError;

  bool get _landReady =>
      !_loadingLand &&
      _landError == null &&
      _estate.text.trim().isNotEmpty &&
      _address.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadLand();
  }

  Future<void> _loadLand() async {
    setState(() {
      _loadingLand = true;
      _landError = null;
    });
    try {
      final land = await OwnerService.getEstate();
      if (!mounted) return;
      setState(() {
        _land = land;
        _estate.text = land.estateName;
        _address.text = land.location ?? '';
        if (_estate.text.trim().isEmpty || _address.text.trim().isEmpty) {
          _landError =
              'Add your land name and location in your profile before booking.';
        }
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _landError = error.message);
    } finally {
      if (mounted) setState(() => _loadingLand = false);
    }
  }

  Future<void> _editLand() async {
    if (_land == null) return;
    final saved = await showThemedDialog<bool>(
      context: context,
      builder: (_) => EditEstateDialog(estate: _land!),
    );
    if (saved == true && mounted) await _loadLand();
  }

  final _offer = TextEditingController();
  // The request covers the working day (Sri Lanka time); no times to pick.
  static const TimeOfDay _dayStart = TimeOfDay(hour: 8, minute: 0);
  static const TimeOfDay _dayEnd = TimeOfDay(hour: 17, minute: 0);
  String? _error;
  @override
  void dispose() {
    _estate.dispose();
    _address.dispose();
    _offer.dispose();
    super.dispose();
  }

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  String _dateText(DateTime d) =>
      '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}, ${d.year}';

  DateTime _utc(TimeOfDay time) => DateTime.utc(
    widget.date.year,
    widget.date.month,
    widget.date.day,
    time.hour,
    time.minute,
  ).subtract(const Duration(minutes: 330));
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Request Machinery'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingLand) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            AutoFilledValue(
              key: const Key('machinery-land-name'),
              label: 'Land name',
              value: _estate.text,
              helper: 'Automatically filled from your land profile',
            ),
            const SizedBox(height: 14),
            AutoFilledValue(
              key: const Key('machinery-land-location'),
              label: 'Land location',
              value: _address.text,
              helper: 'The machinery will be sent to this location',
            ),
            const SizedBox(height: 14),
            AutoFilledValue(
              label: 'Service date',
              value: _dateText(widget.date),
              helper: 'Working day, 8:00 AM - 5:00 PM (Sri Lanka time)',
            ),
            const SizedBox(height: 14),
            if (widget.listedTotal != null) ...[
              AutoFilledValue(
                label: 'Listed total',
                value: rupees(widget.listedTotal!),
                helper:
                    'Calculated from all selected services at the provider?s rates',
              ),
              const SizedBox(height: 14),
            ],
            if (_landError != null) ...[
              Text(_landError!, style: const TextStyle(color: kOwnerRed)),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _loadingLand ? null : _loadLand,
                    child: const Text('Retry'),
                  ),
                  if (_land != null)
                    TextButton(
                      onPressed: _editLand,
                      child: const Text('Update land details'),
                    ),
                ],
              ),
            ],
            TextFormField(
              controller: _offer,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Your total offer (optional)',
                prefixText: 'Rs. ',
                hintText: 'Leave blank to use the listed total',
                helperText:
                    'Your proposed price for the whole job, including all selected services. Not a per-acre or hourly rate.',
                helperMaxLines: 5,
                filled: true,
                fillColor: Colors.white,
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
        onPressed: !_landReady
            ? null
            : () {
                if (!_form.currentState!.validate()) return;
                final now = DateTime.now().toUtc();
                var start = _utc(_dayStart);
                final end = _utc(_dayEnd);
                // Booking for today after 8 AM: start from the next few minutes.
                if (!start.isAfter(now)) {
                  start = now.add(const Duration(minutes: 5));
                }
                if (!end.isAfter(start)) {
                  setState(
                    () => _error =
                        "Today's working hours are over. Pick a later date.",
                  );
                  return;
                }
                setState(() => _error = null);
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

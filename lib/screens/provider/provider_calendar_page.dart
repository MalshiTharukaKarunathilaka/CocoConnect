import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/provider_calendar.dart';
import '../../models/provider_booking_request.dart';
import 'provider_booking_inquiry.dart';
import 'provider_request_page.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/provider_calendar_repository.dart';
import '../../widgets/owner_widgets.dart';
import '../../widgets/buyer_widgets.dart';
import '../account_dialogs.dart';
import '../auth_gate.dart';
import '../buyer/buyer_format.dart';
import '../../theme/app_theme.dart';
import '../../services/holiday_service.dart';
import '../../widgets/holiday_widgets.dart';

const _panel = AppColors.page;
const _background = AppColors.cream;
const _green = AppColors.green;
const _incoming = AppColors.gold;
const _available = AppColors.greenMid;
const _months = [
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
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Calendar is the provider's home. This first feature is a clearly marked
/// read-only preview, with availability drafts kept only for this visit.
class ProviderCalendarPage extends StatefulWidget {
  final ProviderCalendarRepository? repository;
  final DateTime? initialDate;

  const ProviderCalendarPage({super.key, this.repository, this.initialDate});

  @override
  State<ProviderCalendarPage> createState() => _ProviderCalendarPageState();
}

class _ProviderCalendarPageState extends State<ProviderCalendarPage> {
  late final ProviderCalendarRepository _repository =
      widget.repository ?? LiveProviderCalendarRepository();
  LiveProviderCalendarRepository? get _live =>
      _repository is LiveProviderCalendarRepository ? _repository : null;
  bool _saving = false;
  Timer? _poll;
  bool _polling = false;
  int _calendarRevision = 0;
  late DateTime _selected;
  late DateTime _month;
  late Future<ProviderCalendarMonth> _data;
  final Map<String, bool> _drafts = {};
  final Map<String, ProviderCalendarMonth> _cache = {};
  int _tab = 1;

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate ?? providerToday();
    _selected = DateTime(date.year, date.month, date.day);
    _month = DateTime(date.year, date.month);
    _load();
    if (!_repository.isPreview) {
      _poll = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _pollCalendar(),
      );
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pollCalendar() async {
    if (_polling ||
        _saving ||
        _drafts.isNotEmpty ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _polling = true;
    final revision = _calendarRevision;
    final month = _month;
    final machine = _live?.selectedMachineId;
    try {
      final data = await _repository.loadMonth(month);
      if (mounted &&
          revision == _calendarRevision &&
          month == _month &&
          (machine == null || machine == _live?.selectedMachineId)) {
        setState(() => _data = Future.value(data));
      }
    } on ApiException catch (_) {
      /* Explicit refresh displays connection errors. */
    } finally {
      _polling = false;
    }
  }

  void _load() {
    _calendarRevision++;
    final key = providerDateKey(_month);
    final cached = _repository.isPreview ? _cache[key] : null;
    _data = cached != null
        ? Future.value(cached)
        : _repository.loadMonth(_month).then((data) {
            _cache[key] = data;
            return data;
          });
  }

  void _shift(int by) {
    setState(() {
      _month = DateTime(_month.year, _month.month + by);
      final last = DateTime(_month.year, _month.month + 1, 0).day;
      _selected = DateTime(
        _month.year,
        _month.month,
        _selected.day > last ? last : _selected.day,
      );
      _load();
    });
  }

  Future<void> _openDate(DateTime date, ProviderCalendarMonth data) async {
    setState(() {
      _selected = date;
      _tab = 1;
    });
    final requests = data.requests
        .where(
          (r) =>
              r.startsAt.isBefore(
                DateTime(date.year, date.month, date.day + 1),
              ) &&
              r.endsAt.isAfter(DateTime(date.year, date.month, date.day)) &&
              (r.isPending || r.status == ProviderRequestStatus.confirmed),
        )
        .toList();
    if (requests.isEmpty) return;
    final selected = await showProviderBookingInquiry(
      context,
      date: date,
      requests: requests,
      isPreview: _repository.isPreview,
    );
    if (!mounted || selected == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderRequestPage(
          request: selected,
          bookings: data.requests,
          api: _live?.api,
        ),
      ),
    );
    if (mounted) {
      if (_repository.isPreview) {
        setState(() {});
      } else {
        _refresh();
      }
    }
  }

  void _notify(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  void _refresh() {
    if (!mounted) return;
    setState(() {
      _cache.clear();
      _load();
    });
  }

  Future<void> _run(Future<void> Function() task, String success) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await task();
      if (!mounted) return;
      _notify(success);
    } on ApiException catch (error) {
      if (mounted) _notify(error.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _refresh();
      }
    }
  }

  Future<void> _addMachine() async {
    final name = TextEditingController();
    final availableTypes = ['Tractor', 'Backhoe', 'Hand Tractor']
        .where((type) => !_live!.machines.any((m) => m['category'] == type))
        .toList();
    if (availableTypes.isEmpty) {
      _notify('You already have a Tractor, Backhoe and Hand Tractor.');
      return;
    }
    String category = availableTypes.first;
    final form = GlobalKey<FormState>();
    final values = await showThemedDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, change) => AlertDialog(
          title: const Text('Add your machinery'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Machine name'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a machine name' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Machinery type',
                  ),
                  isExpanded: true,
                  items: [
                    for (final type in availableTypes)
                      DropdownMenuItem(value: type, child: Text(type)),
                  ],
                  onChanged: (v) => change(() => category = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(ctx, {
                    'name': name.text.trim(),
                    'category': category,
                  });
                }
              },
              child: const Text('Save Machinery'),
            ),
          ],
        ),
      ),
    );
    // Dialog animation must release the field before its controller is disposed.
    if (values != null && mounted) {
      await _run(() async {
        final machine = await _live!.api.createMachine(
          values['name']!,
          values['category']!,
        );
        _live!.selectedMachineId = machine['id'] as int;
        _drafts.clear();
      }, 'Machinery saved');
    }
  }

  Future<void> _editRate([ProviderServiceRate? rate]) async {
    final live = _live;
    if (live?.selectedMachineId == null || _saving) return;
    try {
      final catalog = await live!.api.catalog();
      if (!mounted) return;
      final machine = live.machines.firstWhere(
        (m) => m['id'] == live.selectedMachineId,
      );
      final services = Map<String, dynamic>.from(
        catalog[machine['category']] as Map,
      );
      final isHandTractor = machine['category'] == 'Hand Tractor';
      final existingName = switch (rate?.name) {
        'Rotary Tiller' => 'Rotary',
        'Coconut Haulage Trailer' => 'Trailer',
        _ => rate?.name,
      };
      if (rate != null &&
          !isHandTractor &&
          !services.containsKey(existingName)) {
        _notify(
          'This service is no longer offered. Add a rate using the current service categories.',
        );
        return;
      }
      String name = isHandTractor
          ? 'Hand Tractor'
          : existingName ?? services.keys.first;
      String unit = (services[name] as List).first as String;
      final price = TextEditingController(
        text: rate == null ? '' : '${rate.rate}',
      );
      final form = GlobalKey<FormState>();
      final values = await showThemedDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, change) => AlertDialog(
            title: Text(
              rate == null ? 'Add Service Rate' : 'Edit Service Rate',
            ),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isHandTractor)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Service category',
                      ),
                      initialValue: name,
                      isExpanded: true,
                      items: [
                        for (final n in services.keys)
                          DropdownMenuItem(
                            value: n,
                            child: Text(n, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: rate != null
                          ? null
                          : (v) => change(() {
                              name = v!;
                              unit = (services[name] as List).first as String;
                            }),
                    ),
                  const SizedBox(height: 12),
                  Text('Price per $unit'),
                  TextFormField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(prefixText: 'Rs. '),
                    validator: (v) {
                      final n = double.tryParse(v ?? '');
                      return n == null || !n.isFinite || n <= 0 || n > 100000000
                          ? 'Enter a valid positive price'
                          : null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(ctx, {
                      'name': name,
                      'unit': unit,
                      'rate': double.parse(price.text),
                    });
                  }
                },
                child: const Text('Save Rate'),
              ),
            ],
          ),
        ),
      );
      if (values != null && mounted) {
        await _run(
          () => live.api.saveRate(
            live.selectedMachineId!,
            values['name'] as String,
            values['unit'] as String,
            values['rate'] as double,
          ),
          'Service rate saved',
        );
      }
    } on ApiException catch (error) {
      if (mounted) _notify(error.message);
    }
  }

  Future<void> _saveDrafts() async {
    final live = _live;
    if (live?.selectedMachineId == null) return;
    final drafts = Map<String, bool>.from(_drafts);
    await _run(() async {
      for (final entry in drafts.entries) {
        await live!.api.availability(
          live.selectedMachineId!,
          entry.key,
          entry.value ? 'AVAILABLE' : 'UNAVAILABLE',
        );
        if (mounted) _drafts.remove(entry.key);
      }
    }, 'Availability saved');
  }

  Future<void> _maintenance(ProviderDayState state) async {
    final live = _live;
    if (live?.selectedMachineId == null) return;
    final remove = state == ProviderDayState.maintenance;
    final yes = await showThemedDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remove ? 'Reopen date?' : 'Block date for maintenance?'),
        content: Text(
          '${_dateLabel(_selected)} will be ${remove ? 'available' : 'unavailable for the whole day'}. Confirmed bookings will not be overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _run(
        () => live!.api.availability(
          live.selectedMachineId!,
          providerDateKey(_selected),
          remove ? 'AVAILABLE' : 'MAINTENANCE',
        ),
        'Availability saved',
      );
    }
  }

  Widget _inventory() {
    final live = _live;
    if (live == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (live.machines.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final machine in live.machines)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        key: ValueKey('machine-type-${machine['id']}'),
                        label: Text('${machine['category']}'),
                        avatar: Icon(
                          switch (machine['category']) {
                            'Backhoe' => Icons.construction,
                            'Hand Tractor' => Icons.grass,
                            _ => Icons.agriculture,
                          },
                          size: 18,
                          color: machine['id'] == live.selectedMachineId
                              ? Colors.white
                              : _green,
                        ),
                        selected: machine['id'] == live.selectedMachineId,
                        showCheckmark: false,
                        selectedColor: _green,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: machine['id'] == live.selectedMachineId
                              ? Colors.white
                              : kOwnerInk,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: const StadiumBorder(),
                        onSelected: _saving
                            ? null
                            : (_) {
                                if (_drafts.isNotEmpty) {
                                  _notify(
                                    'Save or reset availability changes first.',
                                  );
                                  return;
                                }
                                if (live.selectedMachineId == machine['id'])
                                  return;
                                live.selectedMachineId = machine['id'] as int;
                                _refresh();
                              },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calendar, availability and rates for '
              "${live.machines.firstWhere((m) => m['id'] == live.selectedMachineId)['name']}",
              style: const TextStyle(fontSize: 12, color: kOwnerMuted),
            ),
          ],
          if (live.machines.isEmpty)
            const Text(
              'Add your machinery, then set its service rates so estate owners can request bookings.',
            ),
          TextButton.icon(
            onPressed: _saving || _drafts.isNotEmpty ? null : _addMachine,
            icon: const Icon(Icons.add),
            label: const Text('Add Machinery'),
          ),
          
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}, ${date.year}';

  @override
  Widget build(BuildContext context) =>
      AppThemeScope(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMachineryPageWidth),
          child: ColoredBox(
            color: _background,
            child: SafeArea(
              child: Column(
                children: [
                  _header(),
                  if (_repository.isPreview)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: AppColors.infoSoft,
                      child: const Text(
                        'Calendar preview · Sample bookings and rates. Changes are not saved.',
                        style: TextStyle(fontSize: 12, color: kOwnerInk),
                      ),
                    ),
                  Expanded(
                    child: FutureBuilder<ProviderCalendarMonth>(
                      future: _data,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(color: _green),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.cloud_off_outlined,
                                    color: kOwnerMuted,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    snapshot.error is ApiException
                                        ? (snapshot.error as ApiException)
                                              .message
                                        : 'Could not load your calendar. Please try again.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed:
                                        snapshot.error is ApiException &&
                                            (snapshot.error as ApiException)
                                                .isUnauthorized
                                        ? () => logOut(context)
                                        : () => setState(_load),
                                    child: Text(
                                      snapshot.error is ApiException &&
                                              (snapshot.error as ApiException)
                                                  .isUnauthorized
                                          ? 'Log In'
                                          : 'Retry',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        final data = snapshot.data!;
                        return switch (_tab) {
                          0 => _dashboard(data),
                          2 => _requests(data),
                          3 => _profile(),
                          _ => _calendarContent(data),
                        };
                      },
                    ),
                  ),
                  NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (value) =>
                        setState(() => _tab = value),
                    backgroundColor: AppColors.surface,
                    indicatorColor: kOwnerGreenSoft,
                    height: 70,
                    labelTextStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 11),
                    ),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.grid_view_outlined),
                        label: 'Dashboard',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.calendar_month_outlined),
                        label: 'Calendar',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.assignment_outlined),
                        label: 'Requests',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.account_circle_outlined),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.eco_outlined, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'KapConnect',
            style: TextStyle(
              color: _green,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Provider profile',
          onPressed: () => setState(() => _tab = 3),
          icon: const CircleAvatar(
            radius: 16,
            backgroundColor: _green,
            child: Icon(Icons.person_outline, size: 19, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  Widget _calendarContent(ProviderCalendarMonth data) => ListView(
    key: const PageStorageKey('provider-calendar-scroll'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      const Text(
        'My Availability Calendar',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: kOwnerInk,
        ),
      ),
      const SizedBox(height: 4),
    
      const SizedBox(height: 16),
      _inventory(),
      _calendar(data),
      const SizedBox(height: 14),
      // The chosen date's switch sits right under the calendar.
      _selectedDay(data),
      const SizedBox(height: 14),
      FilledButton(
        onPressed:
            _repository.isPreview ||
                _saving ||
                _drafts.isEmpty ||
                _live?.selectedMachineId == null
            ? null
            : _saveDrafts,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(_saving ? 'Saving...' : 'Save Availability Settings'),
        ),
      ),
      if (_drafts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _repository.isPreview
                      ? 'Unsaved preview changes'
                      : 'Unsaved availability changes',
                  style: TextStyle(fontSize: 12, color: kOwnerBrown),
                ),
              ),
              TextButton(
                onPressed: () => setState(_drafts.clear),
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      _rates(data.rates),
    ],
  );

  /// The month grid, redrawn when the year's holidays arrive.
  Widget _calendar(ProviderCalendarMonth data) => HolidayListener(
    years: [_month.year],
    builder: (_) => _calendarBody(data),
  );

  Widget _calendarBody(ProviderCalendarMonth data) {
    final leading = _month.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return OwnerCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: _green,
                size: 17,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]} ${_month.year}',
                  key: const Key('calendar-month'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final label in ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 10, color: kOwnerMuted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (int week = 0; week * 7 < leading + days; week++)
            Row(
              children: [
                for (int column = 0; column < 7; column++)
                  Expanded(
                    child: _dayCell(
                      week * 7 + column - leading + 1,
                      days,
                      data,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                _Legend(_green, 'Confirmed booking'),
                _Legend(_available, 'Available slot'),
                _Legend(_incoming, 'Incoming request'),
                _Legend(kOwnerRed, 'Fully booked'),
                _Legend(kOwnerBrown, 'Maintenance / unavailable'),
                HolidayLegend(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int number, int days, ProviderCalendarMonth data) {
    if (number < 1 || number > days) return const SizedBox(height: 48);
    final date = DateTime(_month.year, _month.month, number);
    final key = providerDateKey(date);
    final day = data.day(date);
    final selected = date == _selected;
    final state = _effectiveState(date, day);
    final closed = state != ProviderDayState.available;
    final background = selected
        ? _green
        : state == ProviderDayState.fullyBooked
        ? AppColors.dangerSoft
        : closed
        ? AppColors.warningSoft
        : AppColors.greenSoft;
    final description = switch (state) {
      ProviderDayState.available => 'Available slots',
      ProviderDayState.unavailable => 'Unavailable',
      ProviderDayState.maintenance => 'Maintenance',
      ProviderDayState.fullyBooked => 'Fully booked',
    };
    final holiday = HolidayService.of(date);
    return Semantics(
      label:
          '${_dateLabel(date)}.${holiday == null ? '' : ' Holiday: ${holiday.name}.'} $description. ${day.confirmed} confirmed bookings, ${day.incoming} incoming requests.',
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        key: Key('provider-day-$key'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openDate(date, data),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: date == providerToday() && !selected
                ? Border.all(color: _green)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (holiday != null)
                Positioned(
                  top: -1,
                  right: 2,
                  child: HolidayFlag(onDark: selected, size: 10),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : kOwnerInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 3,
                    runSpacing: 2,
                    children: [
                      if (day.confirmed > 0)
                        _dot(selected ? Colors.white : _green),
                      if (day.incoming > 0)
                        _dot(selected ? AppColors.gold : _incoming),
                      _dot(switch (state) {
                        ProviderDayState.available => _available,
                        ProviderDayState.fullyBooked => kOwnerRed,
                        _ => kOwnerBrown,
                      }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ProviderDayState _effectiveState(DateTime date, ProviderCalendarDay day) {
    final draft = _drafts[providerDateKey(date)];
    return draft == null
        ? day.state
        : draft
        ? ProviderDayState.available
        : ProviderDayState.unavailable;
  }

  Widget _rates(List<ProviderServiceRate> rates) => OwnerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Manage Service Rates',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            IconButton(
              tooltip: 'Add service rate',
              onPressed: _live?.selectedMachineId == null || _saving
                  ? null
                  : () => _editRate(),
              icon: const Icon(Icons.add, size: 20),
            ),
          ],
        ),
        const Text(
          'Set prices using the billing unit shown for each service.',
          style: TextStyle(fontSize: 11, color: kOwnerMuted),
        ),
        const SizedBox(height: 12),
        if (rates.isEmpty)
          const Text(
            'No registered machinery services.',
            style: TextStyle(color: kOwnerMuted),
          ),
        for (final rate in rates)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.agriculture_outlined, color: _green, size: 21),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rate.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          text: rupees(rate.rate),
                          style: const TextStyle(
                            color: _green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            TextSpan(
                              text: ' / ${rate.unit}',
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                color: kOwnerMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _repository.isPreview || _saving
                      ? null
                      : () => _editRate(rate),
                  child: const Text(
                    'Edit Rate',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _selectedDay(ProviderCalendarMonth data) {
    final day = data.day(_selected);
    final state = _effectiveState(_selected, day);
    final available = state == ProviderDayState.available;
    final past = _selected.isBefore(providerToday());
    final locked =
        day.state == ProviderDayState.fullyBooked ||
        day.state == ProviderDayState.maintenance;
    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 18,
                color: _green,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _dateLabel(_selected),
                  key: const Key('selected-date'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            switch (state) {
              ProviderDayState.available => 'Available slots',
              ProviderDayState.unavailable => 'Unavailable',
              ProviderDayState.maintenance => 'Maintenance',
              ProviderDayState.fullyBooked => 'Fully booked',
            },
            style: TextStyle(
              color: available ? _green : kOwnerBrown,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          HolidayListener(
            years: [_selected.year],
            builder: (_) => HolidayNote(_selected),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mark as Available for Bookings',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Save changes to update this date',
                        style: TextStyle(fontSize: 11, color: kOwnerMuted),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('availability-toggle'),
                  value: available,
                  onChanged:
                      past ||
                          locked ||
                          _saving ||
                          (!_repository.isPreview &&
                              _live?.selectedMachineId == null)
                      ? null
                      : (value) => setState(() {
                          if (value ==
                              (day.state == ProviderDayState.available)) {
                            _drafts.remove(providerDateKey(_selected));
                          } else {
                            _drafts[providerDateKey(_selected)] = value;
                          }
                        }),
                ),
              ],
            ),
          ),
          if (past)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Past dates are read-only.',
                style: TextStyle(fontSize: 12, color: kOwnerMuted),
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: _repository.isPreview || _saving || past
                ? null
                : () => _maintenance(state),
            icon: const Icon(Icons.build_outlined, size: 15),
            label: Text(
              state == ProviderDayState.maintenance
                  ? 'Reopen Date'
                  : 'Block Date / Schedule Maintenance',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${day.confirmed} confirmed · ${day.incoming} incoming',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kOwnerInk,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day.confirmed == 0 && day.incoming == 0
                ? 'No bookings or requests on this date.'
                : 'Select this date to review requests and bookings.',
            style: const TextStyle(fontSize: 12, color: kOwnerMuted),
          ),
        ],
      ),
    );
  }

  Widget _dashboard(ProviderCalendarMonth data) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'Machinery Overview',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: kOwnerInk,
        ),
      ),
      const SizedBox(height: 16),
      OwnerCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_months[_month.month - 1]} ${_month.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              '${data.dateKeys.fold(0, (sum, key) => sum + data.day(DateTime.parse(key)).confirmed)} confirmed bookings',
            ),
            const SizedBox(height: 8),
            Text(
              '${data.dateKeys.fold(0, (sum, key) => sum + data.day(DateTime.parse(key)).incoming)} incoming requests',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _tab = 1),
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('Open Availability Calendar'),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _requests(ProviderCalendarMonth data) {
    final dates =
        data.dateKeys
            .map((key) => MapEntry(key, data.day(DateTime.parse(key))))
            .where((entry) => data.day(DateTime.parse(entry.key)).incoming > 0)
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Incoming Requests',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: kOwnerInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_months[_month.month - 1]} ${_month.year}',
          style: const TextStyle(color: kOwnerMuted),
        ),
        const SizedBox(height: 16),
        if (dates.isEmpty)
          const OwnerCard(child: Text('No incoming requests this month.')),
        for (final entry in dates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OwnerCard(
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.event_note_outlined, color: _green),
                  title: Text(
                    _dateLabel(DateTime.parse(entry.key)),
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${data.day(DateTime.parse(entry.key)).incoming} incoming requests',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDate(DateTime.parse(entry.key), data),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _editProfile(AppUser user) async {
    final saved = await showThemedDialog<bool>(
      context: context,
      builder: (context) => EditProfileDialog(user: user),
    );
    if (saved == true && mounted) setState(() {});
  }

  Widget _profile() {
    final user = AuthService.currentUser;
    final location = user?.location?.trim() ?? '';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        BuyerCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: kBuyerGreen,
                child: Text(
                  initialsOf(user?.name ?? 'Provider preview'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'Provider preview',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const BuyerPill(
                      text: 'SERVICE PROVIDER',
                      background: Color(0xFFDDEEE0),
                      foreground: kBuyerGreen,
                    ),
                    const SizedBox(height: 10),
                    _profileInfo(
                      Icons.phone_outlined,
                      user?.phone ?? 'Preview account',
                    ),
                    const SizedBox(height: 4),
                    _profileInfo(
                      Icons.location_on_outlined,
                      location.isEmpty ? 'No location added' : location,
                      muted: location.isEmpty,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'ACCOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: kBuyerGrey,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 8),
        BuyerCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ListTile(
                onTap: user == null ? null : () => _editProfile(user),
                leading: const Icon(Icons.edit_outlined, color: kBuyerGreen),
                title: const Text(
                  'Edit profile',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Name and location',
                  style: TextStyle(fontSize: 12, color: kBuyerGrey),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFBBBBBB),
                ),
              ),
              if (user != null) ...[
                const Divider(height: 1, indent: 56, color: kBuyerBorder),
                ListTile(
                  onTap: () => confirmLogOut(context),
                  leading: const Icon(Icons.logout, color: Color(0xFFC62828)),
                  title: const Text(
                    'Log out',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC62828),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFBBBBBB),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileInfo(IconData icon, String text, {bool muted = false}) => Row(
    children: [
      Icon(icon, size: 15, color: kBuyerGrey),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: muted ? const Color(0xFFAAAAAA) : const Color(0xFF3A3A3A),
            fontStyle: muted ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    ],
  );
}

Widget _dot(Color color) => Container(
  width: 5,
  height: 5,
  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
);

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dot(color),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, color: kOwnerInk),
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/machinery_service.dart';
import '../widgets/machinery_widgets.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'machinery_booking_status_page.dart';
import 'machinery_negotiation_page.dart';

const Color _red = Color(0xFFC62828);
const Color _amber = Color(0xFFE2681F);
const Color _amberSoft = Color(0xFFFFF1E0);

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
const List<String> _months = [
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

/// A machinery service with its photo and rate.
class _Service {
  /// The machinery_services row, empty for services drawn from other people's bookings.
  final int? id;
  final String name;
  final String photo;
  final String description;
  final int rate;
  final String unit; // acre / day
  final String note;

  const _Service(
    this.name,
    this.photo,
    this.description,
    this.rate,
    this.unit,
    this.note, {
    this.id,
  });
}

const List<_Service> _services = [
  _Service(
    'Slasher',
    'slasher',
    'Weed cutting & estate undergrowth clearing',
    5000,
    'acre',
    'High clearing torque',
  ),
  _Service(
    'Disc Ploughing',
    'disc_plough',
    'Deep primary soil aeration for root hydration',
    7000,
    'acre',
    'Deep furrow penetration',
  ),
  _Service(
    'Rotary Tiller',
    'rotary',
    'Secondary soil pulverization & manure mixing',
    6000,
    'acre',
    'Optimal for organic top-dress',
  ),
  _Service(
    'Koku Nagula',
    'koku_nagula',
    'Traditional tine ploughing around coconut base',
    4500,
    'acre',
    'Safe root perimeter tilling',
  ),
  _Service(
    'Coconut Haulage Trailer',
    'trailer',
    'Nut transport & fertilizer distribution',
    14000,
    'day',
    'Up to 4,000 nuts / trip',
  ),
];

const List<_Service> _backhoeServices = [
  _Service(
    'Ditch & Drainage',
    '',
    'Drain and ditch digging between palm rows',
    4200,
    'hour',
    'Keeps estate water-logging away',
  ),
  _Service(
    'Pit Digging',
    '',
    'Planting pits for new coconut seedlings',
    4200,
    'hour',
    'Uniform pit depth',
  ),
  _Service(
    'Land Clearing',
    '',
    'Stump removal and levelling of new land',
    6500,
    'hour',
    'Heavy-duty clearing',
  ),
];

const List<_Service> _handTractorServices = [
  _Service(
    'Weeding',
    '',
    'Light weed control between palms',
    3200,
    'acre',
    'Good for narrow rows',
  ),
  _Service(
    'Inter-row Tilling',
    '',
    'Shallow tilling for intercrops',
    3000,
    'acre',
    'Low soil compaction',
  ),
  _Service(
    'Small Trailer Haulage',
    '',
    'Short-distance nut and manure transport',
    9000,
    'day',
    'Up to 1,000 nuts / trip',
  ),
];

/// The machine's own services and rates from the database. The photo and
/// the description come from the app's catalogue when the name matches one.
List<_Service> _servicesOf(MachineInfo? machine) {
  if (machine == null) return const [];
  final Map<String, _Service> catalogue = {
    for (final s in [..._services, ..._backhoeServices, ..._handTractorServices])
      s.name: s,
  };
  return [
    for (final s in machine.serviceList)
      _Service(
        s.name,
        catalogue[s.name]?.photo ?? '',
        catalogue[s.name]?.description ?? 'Offered by ${machine.provider}',
        s.rate,
        s.unit,
        catalogue[s.name]?.note ?? '',
        id: s.id,
      ),
  ];
}

/// "4.5 acres", "6 hrs" or "1 day" for a booked quantity.
String _qty(_Service s, double n) {
  final String v = n % 1 == 0 ? '${n.toInt()}' : '$n';
  return switch (s.unit) {
    'acre' => '$v acres',
    'hour' => '$v hrs',
    _ => '1 day',
  };
}

// `pending` is a request the provider has not accepted yet. Nothing creates one
// until providers can accept bookings in the app, but the calendar already
// draws it in amber.
// ignore: unused_field
enum _Status { confirmed, pending }

/// A service booked on a day.
class _Job {
  final _Service service;
  final _Status status;
  final String estate;
  final double acres;
  final String time;

  /// Set for bookings made in this app, so the card can open their status.
  final MachineBooking? mine;

  const _Job(
    this.service,
    this.status,
    this.estate,
    this.acres,
    this.time, {
    this.mine,
  });

  int get amount =>
      service.unit == 'day' ? service.rate : (service.rate * acres).round();
}

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// The provider starts early; the exact time is agreed in the chat.
const String _startTime = '07:00 AM';

String _fmt(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';

String _categoryOf(String? type) => switch (type) {
  'BACKHOE' => 'Backhoe',
  'HAND_TRACTOR' => 'Hand Tractor',
  _ => 'Tractor',
};

enum _Day { past, booked, pending, free }

/// Provider calendar. Green days are free, red are booked and amber already
/// have a request waiting. Tap a free day, pick a service and the amount of
/// work, then negotiate the price with the provider.
class ServiceSchedulePage extends StatefulWidget {
  /// The machine whose calendar this is (shown in the header).
  final String? machineName;
  final String? provider;

  /// TRACTOR / BACKHOE / HAND_TRACTOR; decides which services are listed.
  final String? type;

  /// Where the machine is based and where the estate is (for the status map).
  final LatLng? machineAt;
  final LatLng? estateAt;
  final double km;

  /// The machine itself, for the summary card at the top.
  final MachineInfo? info;

  const ServiceSchedulePage({
    super.key,
    this.machineName,
    this.provider,
    this.type,
    this.machineAt,
    this.estateAt,
    this.km = 0,
    this.info,
  });

  @override
  State<ServiceSchedulePage> createState() => _ServiceSchedulePageState();
}

class _ServiceSchedulePageState extends State<ServiceSchedulePage> {
  late final List<_Service> _svc = _servicesOf(widget.info);
  /// Other estates' bookings on this machine, from the backend. The owner's
  /// own bookings are added from [machineBookings] in [_on].
  Map<String, List<_Job>> _jobs = {};
  late DateTime _day = _firstBookable();
  late DateTime _month = DateTime(_day.year, _day.month);
  final _selKey = GlobalKey();

  /// The services ticked for this day, by name, and how much work of each
  /// (acres or hours). A day-rate service is always one day.
  final Set<String> _picked = {};
  final Map<String, double> _amounts = {};

  @override
  void initState() {
    super.initState();
    _pickDefault();
    _loadCalendar();
  }

  /// Fetches the owner's bookings and everything already booked on this
  /// machine, so days other people have taken show as booked.
  Future<void> _loadCalendar() async {
    try {
      await MachineryService.refreshBookings();
      final Map<String, List<_Job>> jobs = {};
      final MachineInfo? machine = widget.info;
      if (machine != null) {
        final MachineCalendar calendar = await MachineryService.schedule(
          machine.id,
        );
        // Days the provider has blocked: every service is taken.
        for (final day in calendar.blocked) {
          for (final s in _svc) {
            jobs
                .putIfAbsent(_key(day.date), () => [])
                .add(
                  _Job(
                    s,
                    _Status.confirmed,
                    day.state == 'MAINTENANCE'
                        ? 'In maintenance'
                        : 'Not available',
                    1,
                    '',
                  ),
                );
          }
        }
        for (final slot in calendar.slots) {
          if (slot.mine) continue; // drawn from my own bookings
          for (final i in slot.items) {
            jobs
                .putIfAbsent(_key(slot.date), () => [])
                .add(
                  _Job(
                    _Service(i.name, '', 'Booked', i.rate, i.unit, ''),
                    _Status.confirmed,
                    'Another estate',
                    i.qty,
                    slot.time,
                  ),
                );
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        if (!_bookable(_day)) {
          _day = _firstBookable();
          _month = DateTime(_day.year, _day.month);
        }
        // Drop ticks on services that turned out to be taken.
        final Set<String> free = {for (final s in _freeSvc(_day)) s.name};
        _picked.removeWhere((name) => !free.contains(name));
        if (_picked.isEmpty) _pickDefault();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load the calendar: ${e.message}')),
      );
    }
  }

  /// Start with the first free service ticked, so there is always a sensible
  /// selection to adjust.
  void _pickDefault() {
    _picked.clear();
    final List<_Service> free = _freeSvc(_day);
    if (free.isNotEmpty) _picked.add(free.first.name);
  }

  double _amountOf(_Service s) =>
      s.unit == 'day' ? 1 : (_amounts[s.name] ?? (s.unit == 'hour' ? 4 : 4.5));

  int _lineCost(_Service s) =>
      s.unit == 'day' ? s.rate : (s.rate * _amountOf(s)).round();

  List<_Service> _selectedOn(List<_Service> free) =>
      free.where((s) => _picked.contains(s.name)).toList();

  void _toggle(_Service s) {
    setState(() {
      if (!_picked.remove(s.name)) _picked.add(s.name);
    });
  }

  void _step(_Service s, double by) {
    setState(() {
      final double step = s.unit == 'hour' ? 1 : 0.5;
      _amounts[s.name] = (_amountOf(s) + by * step).clamp(step, 99.0);
    });
  }

  DateTime get _today {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Demo jobs plus the bookings made while the app has been open.
  List<_Job> _on(DateTime d) => [
    ...(_jobs[_key(d)] ?? const <_Job>[]),
    for (final b
        in machineBookings[widget.machineName] ?? const <MachineBooking>[])
      if (_key(b.date) == _key(d))
        for (final i in b.items)
          _Job(
            _Service(
              i.name,
              '',
              'Booked through CocoConnect',
              // Spread any negotiated discount over the services.
              (i.rate * b.total / (b.listTotal == 0 ? 1 : b.listTotal)).round(),
              i.unit,
              '',
            ),
            _Status.confirmed,
            'Your booking',
            i.qty,
            b.time,
            mine: b,
          ),
  ];

  List<_Service> _freeSvc(DateTime d) {
    final Set<String> taken = {for (final j in _on(d)) j.service.name};
    return _svc.where((s) => !taken.contains(s.name)).toList();
  }

  _Day _stateOf(DateTime d) {
    if (d.isBefore(_today)) return _Day.past;
    final List<_Job> jobs = _on(d);
    if (jobs.any((j) => j.status == _Status.confirmed)) return _Day.booked;
    if (jobs.isNotEmpty) return _Day.pending;
    return _Day.free;
  }

  bool _bookable(DateTime d) {
    final _Day s = _stateOf(d);
    return (s == _Day.free || s == _Day.pending) && _freeSvc(d).isNotEmpty;
  }

  DateTime _firstBookable() {
    DateTime d = _today;
    for (int i = 0; i < 120; i++) {
      if (_bookable(d)) return d;
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return _today;
  }

  /// Select a day and bring its booking panel into view, so the next step
  /// is on screen without hunting for it.
  void _pickDay(DateTime d) {
    setState(() {
      _day = d;
      _pickDefault();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? c = _selKey.currentContext;
      if (c == null) return;
      Scrollable.ensureVisible(
        c,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.04,
      );
    });
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  Future<void> _negotiate(List<_Service> selected) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MachineryNegotiationPage(
          machineName: widget.machineName ?? 'Machine',
          provider: widget.provider ?? 'Provider',
          category: _categoryOf(widget.type),
          items: [
            for (final s in selected)
              BookingItem(s.name, s.unit, _amountOf(s), s.rate, serviceId: s.id),
          ],
          date: _day,
          startTime: _startTime,
          estate: AuthService.currentUser?.location ?? 'Your estate',
          machineAt: widget.machineAt,
          estateAt: widget.estateAt,
          km: widget.km,
          info: widget.info,
        ),
      ),
    );
    // A booking made in there should show on the calendar now.
    if (mounted) {
      setState(_pickDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_Job> jobs = _on(_day);
    final _Day st = _stateOf(_day);
    final List<_Service> free = _freeSvc(_day);
    final List<_Service> selected = _selectedOn(free);
    final bool bookable =
        (st == _Day.free || st == _Day.pending) && free.isNotEmpty;

    final (String label, PillTone tone) = switch (st) {
      _Day.free => ('Available', PillTone.green),
      _Day.pending => ('Request pending', PillTone.neutral),
      _Day.booked => ('Booked', PillTone.red),
      _Day.past => ('Past date', PillTone.neutral),
    };

    return OwnerPage(
      bottom: bookable ? _bookBar(selected) : null,
      child: Column(
        children: [
          OwnerHeader(
            title: widget.machineName ?? 'Service Schedule',
            subtitle: widget.provider?.toUpperCase() ?? 'MACHINERY BOOKINGS',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (widget.info != null) ...[
                  _machineHeader(widget.info!),
                  const SizedBox(height: 14),
                ],
                const Padding(
                  padding: EdgeInsets.only(bottom: 10, left: 2),
                  child: Text(
                    'Tap an available date to select your service schedule.',
                    style: TextStyle(fontSize: 13, color: kOwnerMuted),
                  ),
                ),
                _calendar(),
                const SizedBox(height: 18),
                Row(
                  key: _selKey,
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      size: 20,
                      color: kOwnerGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_weekdays[_day.weekday - 1]}, ${_day.day} ${_months[_day.month - 1]} ${_day.year}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: kOwnerInk,
                        ),
                      ),
                    ),
                    OwnerPill(label, tone: tone),
                  ],
                ),
                const SizedBox(height: 10),
                if (st == _Day.past)
                  const OwnerCard(
                    child: Text(
                      'This date has already passed. Pick a later date.',
                      style: TextStyle(fontSize: 13.5, color: kOwnerMuted),
                    ),
                  ),
                if (st == _Day.booked || (st != _Day.past && free.isEmpty))
                  const OwnerCard(
                    child: Text(
                      'This machine is fully booked on this day. '
                      'Pick a green date instead.',
                      style: TextStyle(fontSize: 13.5, color: kOwnerMuted),
                    ),
                  ),
                for (final j in jobs) ...[
                  _jobCard(j),
                  const SizedBox(height: 10),
                ],
                if (bookable) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Choose Service',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: kOwnerInk,
                    ),
                  ),
                  Text(
                    st == _Day.pending
                        ? 'A request is waiting on this day; these are still free'
                        : 'Tick one or more services you need',
                    style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
                  ),
                  const SizedBox(height: 10),
                  for (final s in free) ...[
                    _serviceCard(
                      s,
                      selected: _picked.contains(s.name),
                      onTap: () => _toggle(s),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 4),
                  _selectionCard(selected),
                  const SizedBox(height: 10),
                  _estimateNote(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _machineHeader(MachineInfo m) => OwnerCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        MachinePhoto(m, width: 84, height: 84, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                machineLabel(m.type).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: kOwnerGreen,
                ),
              ),
              Text(
                m.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      m.provider,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: kOwnerMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, size: 14, color: kOwnerGreen),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Color(0xFFF2A900)),
                  const SizedBox(width: 3),
                  Text(
                    m.ratingText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: kOwnerInk,
                    ),
                  ),
                  Text(
                    ' (${m.jobs} jobs)',
                    style: const TextStyle(fontSize: 12, color: kOwnerMuted),
                  ),
                  if (widget.km > 0) ...[
                    const Text(
                      '  ·  ',
                      style: TextStyle(fontSize: 12, color: kOwnerMuted),
                    ),
                    Text(
                      '${widget.km.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 12, color: kOwnerMuted),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: 'from ${rupees(m.rate)}',
                  children: [
                    TextSpan(
                      text: ' / ${m.unit}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: kOwnerMuted,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: kOwnerBrown,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// The chosen services, each with its own acres (or hours) and cost.
  Widget _selectionCard(List<_Service> selected) {
    Widget stepBtn(IconData icon, bool dark, VoidCallback onTap) => Material(
      color: dark ? kOwnerGreen : const Color(0xFFE6EAFB),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 20, color: dark ? Colors.white : kOwnerInk),
        ),
      ),
    );

    final int total = selected.fold(0, (sum, s) => sum + _lineCost(s));

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 20,
                color: kOwnerGreen,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Your selection',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kOwnerInk,
                  ),
                ),
              ),
              OwnerPill(
                selected.length == 1
                    ? '1 service'
                    : '${selected.length} services',
                tone: selected.isEmpty ? PillTone.neutral : PillTone.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selected.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Tick at least one service above to continue.',
                style: TextStyle(fontSize: 13, color: kOwnerMuted),
              ),
            ),
          for (int i = 0; i < selected.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: kOwnerBorder),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected[i].name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: kOwnerInk,
                        ),
                      ),
                      Text(
                        '${rupees(selected[i].rate)} / ${selected[i].unit}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: kOwnerMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  rupees(_lineCost(selected[i])),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: kOwnerBrown,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (selected[i].unit == 'day')
              Row(
                children: const [
                  Icon(Icons.today_outlined, size: 17, color: kOwnerGreen),
                  SizedBox(width: 6),
                  Text(
                    '1 day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kOwnerInk,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  stepBtn(Icons.remove, false, () => _step(selected[i], -1)),
                  SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        Text(
                          qtyText(selected[i].unit, _amountOf(selected[i])),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: kOwnerInk,
                          ),
                        ),
                        if (selected[i].unit == 'acre')
                          Text(
                            '≈ ${(_amountOf(selected[i]) * 160).round()} coconut palms',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kOwnerMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  stepBtn(Icons.add, true, () => _step(selected[i], 1)),
                ],
              ),
          ],
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kOwnerGreenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimated total',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: kOwnerInk,
                    ),
                  ),
                  Text(
                    rupees(total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kOwnerGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _estimateNote() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _amberSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _amber.withValues(alpha: 0.3)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: _amber),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Prices are estimates. You agree the final price for all the '
            'work with the provider next.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: _amber),
          ),
        ),
      ],
    ),
  );

  Widget _bookBar(List<_Service> selected) {
    final int total = selected.fold(0, (sum, s) => sum + _lineCost(s));
    final String detail = selected.isEmpty
        ? 'No service selected'
        : selected.length == 1
        ? (selected.first.unit == 'day'
              ? 'Est. Cost (1 day)'
              : 'Est. Cost (${_fmt(_amountOf(selected.first))} '
                    '${selected.first.unit == 'hour' ? 'hrs' : 'acres'} × '
                    '${rupees(selected.first.rate)})')
        : 'Est. total · ${selected.length} services';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kOwnerBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  detail,
                  style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
                ),
              ),
              Text(
                rupees(total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OwnerPrimaryButton(
            label: 'Negotiate Booking',
            arrow: true,
            onPressed: selected.isEmpty ? null : () => _negotiate(selected),
          ),
        ],
      ),
    );
  }

  Widget _calendar() {
    final DateTime first = DateTime(_month.year, _month.month, 1);
    final int lead = first.weekday - 1;
    final int days = DateTime(_month.year, _month.month + 1, 0).day;

    Widget arrow(IconData icon, int by) => Material(
      color: kOwnerPanel,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _shift(by),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 20, color: kOwnerInk),
        ),
      ),
    );

    return OwnerCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]} ${_month.year}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kOwnerInk,
                  ),
                ),
              ),
              arrow(Icons.chevron_left, -1),
              const SizedBox(width: 8),
              arrow(Icons.chevron_right, 1),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: kOwnerMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (int week = 0; week * 7 < lead + days; week++)
            Row(
              children: [
                for (int dow = 0; dow < 7; dow++)
                  Expanded(child: _dayCell(week * 7 + dow - lead + 1, days)),
              ],
            ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Legend(color: kOwnerGreen, label: 'Available'),
              _Legend(color: _red, label: 'Booked'),
              _Legend(color: _amber, label: 'Pending'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Small coloured dots: your bookings with other machines that day',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: kOwnerMuted),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int n, int days) {
    if (n < 1 || n > days) return const SizedBox(height: 54);
    final DateTime d = DateTime(_month.year, _month.month, n);
    final bool selected = _key(d) == _key(_day);
    final bool today = _key(d) == _key(_today);
    final _Day st = _stateOf(d);
    // A day with a request but no service left is as good as booked.
    final bool full =
        st != _Day.past && st != _Day.booked && _freeSvc(d).isEmpty;

    final (Color strong, Color soft) = switch (st) {
      _Day.past => (const Color(0xFF9AA0A6), const Color(0xFFF4F4F2)),
      _Day.booked => (_red, const Color(0xFFFDECEC)),
      _Day.pending =>
        full ? (_red, const Color(0xFFFDECEC)) : (_amber, _amberSoft),
      _Day.free => (kOwnerGreen, kOwnerGreenSoft),
    };
    final bool dim = st == _Day.past;
    final bool strike = st == _Day.booked || full;

    // The owner's bookings with other machines on this day, one dot each in
    // that machine type's colour.
    final List<MachineBooking> others = [
      for (final b in allMachineBookings())
        if (b.machineName != widget.machineName && _key(b.date) == _key(d)) b,
    ];

    return GestureDetector(
      onTap: dim ? null : () => _pickDay(d),
      child: Container(
        height: 54,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? strong : soft,
          borderRadius: BorderRadius.circular(14),
          border: today && !selected
              ? Border.all(color: kOwnerGreen, width: 1.6)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$n',
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected || today
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : dim
                    ? const Color(0xFFB4B8BC)
                    : strong,
                decoration: strike ? TextDecoration.lineThrough : null,
                decorationColor: selected ? Colors.white : strong,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!dim) _dot(selected ? Colors.white : strong),
                  for (final b in others.take(2))
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: machineColor(b.info?.type ?? 'TRACTOR'),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.2),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 7,
    height: 7,
    margin: const EdgeInsets.symmetric(horizontal: 1.5),
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _photo(_Service s) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: s.photo.isEmpty
        // No service photo: show the machine's own photo instead.
        ? (widget.info != null
              ? MachinePhoto(widget.info!, width: 74, height: 74, radius: 0)
              : _photoFallback())
        : Image.asset(
            'assets/services/${s.photo}.jpg',
            width: 74,
            height: 74,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _photoFallback(),
          ),
  );

  Widget _photoFallback() => Container(
    width: 74,
    height: 74,
    color: kOwnerGreenSoft,
    child: const Icon(Icons.agriculture, color: kOwnerGreen, size: 32),
  );

  Widget _jobCard(_Job j) {
    final MachineBooking? b = j.mine;
    if (b == null) return _jobCardBody(j);
    // Your own booking: tap it to see its status, chat or cancel.
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MachineryBookingStatusPage(booking: b),
          ),
        );
        if (mounted) setState(() {});
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _jobCardBody(j),
          const Padding(
            padding: EdgeInsets.only(top: 6, left: 4),
            child: Text(
              'Tap to view booking status',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kOwnerGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobCardBody(_Job j) {
    final bool ok = j.status == _Status.confirmed;
    final Color c = ok ? _red : _amber;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: c),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    j.mine != null && widget.info != null
                        ? MachinePhoto(
                            widget.info!,
                            width: 74,
                            height: 74,
                            radius: 10,
                          )
                        : _photo(j.service),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  j.service.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: kOwnerInk,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: ok
                                      ? const Color(0xFFFDECEC)
                                      : _amberSoft,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  ok ? 'Confirmed' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: c,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            j.estate,
                            style: const TextStyle(
                              fontSize: 13,
                              color: kOwnerMuted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: kOwnerGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                j.time,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: kOwnerGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _chip(_qty(j.service, j.acres)),
                              const Spacer(),
                              Text(
                                rupees(j.amount),
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.bold,
                                  color: kOwnerBrown,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(
    _Service s, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? kOwnerGreen : Colors.transparent,
                width: 2,
              ),
            ),
            child: OwnerCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _photo(s),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kOwnerInk,
                          ),
                        ),
                        Text.rich(
                          TextSpan(
                            text: rupees(s.rate),
                            children: [
                              TextSpan(
                                text: ' / ${s.unit}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.normal,
                                  color: kOwnerMuted,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: kOwnerBrown,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: kOwnerMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _chip(
                              s.unit == 'day'
                                  ? 'Per day'
                                  : '${_qty(s, _amountOf(s))} = ${rupees(_lineCost(s))}',
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                s.note,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: kOwnerGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            top: 18,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: selected ? kOwnerGreen : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : const Color(0xFFBDBDBD),
                  width: 1.6,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 3),
                ],
              ),
              child: selected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: kOwnerPanel,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11.5, color: kOwnerInk)),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12.5, color: kOwnerInk)),
    ],
  );
}

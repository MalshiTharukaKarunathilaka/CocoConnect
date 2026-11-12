import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/auth_service.dart';
import '../widgets/machinery_widgets.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'my_bookings_page.dart';

const List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _mon = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Sat, 24 Oct 2026"
String fullDate(DateTime d) =>
    '${_days[d.weekday - 1]}, ${d.day} ${_mon[d.month - 1]} ${d.year}';

/// acre / hour / day -> the short word used after a price ("Rs. 6,800 / acre").
String perUnit(String unit) => switch (unit) {
  'hour' => 'hr',
  'day' => 'day',
  _ => 'acre',
};

/// "15 Acres", "6 Hours" or "1 Day".
String qtyText(String unit, double q) {
  final String v = q % 1 == 0 ? '${q.toInt()}' : '$q';
  return switch (unit) {
    'acre' => '$v ${q == 1 ? 'Acre' : 'Acres'}',
    'hour' => '$v ${q == 1 ? 'Hour' : 'Hours'}',
    _ => '1 Day',
  };
}

/// One service in a booking, with the amount of work asked for.
class BookingItem {
  final String name;
  final String unit; // acre / hour / day
  final double qty;
  final num rate; // list rate per unit (per day for 'day')

  const BookingItem(this.name, this.unit, this.qty, this.rate);

  /// The list price for this service.
  num get lineTotal => unit == 'day' ? rate : rate * qty;

  String get qtyLabel => qtyText(unit, qty);
}

/// "Slasher (4.5 Acres)" or "Slasher (4.5 Acres) and Disc Ploughing (4 Acres)".
String describeItems(List<BookingItem> items) {
  final List<String> parts = [
    for (final i in items) '${i.name} (${i.qtyLabel})',
  ];
  if (parts.length <= 1) return parts.join();
  return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
}

/// A machinery booking the estate owner agreed with a provider. It can hold
/// several services; [agreedTotal] is the price agreed for all of them.
class MachineBooking {
  final String id;
  final String machineName;
  final String provider;
  final String category; // Tractor / Backhoe / Hand Tractor
  final List<BookingItem> items;
  final num agreedTotal;
  final DateTime date;
  final String time; // start time, e.g. 06:00 AM
  final String estate;
  final LatLng? machineAt;
  final LatLng? estateAt;
  final double km;
  final DateTime createdAt;
  final List<ChatLine> chat;
  final MachineInfo? info;

  const MachineBooking({
    required this.id,
    required this.machineName,
    required this.provider,
    required this.category,
    required this.items,
    required this.agreedTotal,
    required this.date,
    required this.time,
    required this.estate,
    required this.createdAt,
    required this.chat,
    this.machineAt,
    this.estateAt,
    this.km = 0,
    this.info,
  });

  /// The agreed price for the whole booking.
  num get total => agreedTotal;

  /// What the same work costs at the provider's list rates.
  num get listTotal => items.fold<num>(0, (sum, i) => sum + i.lineTotal);

  /// "Slasher + Disc Ploughing".
  String get service => items.map((i) => i.name).join(' + ');

  /// "4.5 Acres" for one service, "2 services" for several.
  String get scope =>
      items.length == 1 ? items.first.qtyLabel : '${items.length} services';

  /// The job day has passed, so the booking counts as completed.
  bool get isCompleted {
    final DateTime n = DateTime.now();
    return date.isBefore(DateTime(n.year, n.month, n.day));
  }
}

/// Confirmed bookings, kept in memory for the demo (machine name -> bookings).
/// The calendar reads this so a booked day turns red straight away.
final Map<String, List<MachineBooking>> machineBookings = _sampleBookings();

/// Every booking, across all machines.
List<MachineBooking> allMachineBookings() => [
  for (final list in machineBookings.values) ...list,
];

/// A few bookings to start with, so My Bookings has something to show:
/// three finished jobs and two upcoming ones on the same day (a tractor and
/// a backhoe), which shows as two different coloured dots on the calendar.
Map<String, List<MachineBooking>> _sampleBookings() {
  final AppUser? me = AuthService.currentUser;
  final LatLng estate = LatLng(
    me?.latitude ?? 7.4863,
    me?.longitude ?? 80.3647,
  );
  final DateTime n = DateTime.now();
  DateTime day(int offset) => DateTime(n.year, n.month, n.day + offset);

  MachineBooking make(
    String id,
    MachineInfo m,
    String service,
    int offset,
    double qty,
    String start,
  ) {
    final LatLng at = LatLng(
      estate.latitude + m.dLat,
      estate.longitude + m.dLng,
    );
    return MachineBooking(
      id: id,
      machineName: m.name,
      provider: m.provider,
      category: machineLabel(m.type),
      items: [BookingItem(service, m.unit, qty, m.rate)],
      agreedTotal: BookingItem(service, m.unit, qty, m.rate).lineTotal,
      date: day(offset),
      time: start,
      estate: me?.location ?? 'Your estate',
      createdAt: DateTime(n.year, n.month, n.day + offset - 3, 10, 14),
      machineAt: at,
      estateAt: estate,
      km: const Distance().as(LengthUnit.Meter, estate, at) / 1000,
      info: m,
      chat: [
        ChatLine(
          true,
          'Hi, I would like to book $service (${qtyText(m.unit, qty)}) on '
          '${fullDate(day(offset))}. Your listed total is '
          '${rupees(BookingItem(service, m.unit, qty, m.rate).lineTotal)}.',
        ),
        ChatLine(
          false,
          'Thanks for the request! That works for me. I can start at $start.',
        ),
      ],
    );
  }

  final List<MachineBooking> all = [
    make('#MC-2031', demoMachines[2], 'Koku Nagula', -12, 3, '06:00 AM'),
    make('#MC-2054', demoMachines[6], 'Pit Digging', -6, 5, '06:00 AM'),
    make('#MC-2077', demoMachines[5], 'Inter-row Tilling', -20, 2, '12:00 PM'),
    make('#MC-3102', demoMachines[3], 'Disc Ploughing', 3, 4.5, '06:00 AM'),
    make('#MC-3118', demoMachines[7], 'Land Clearing', 3, 6, '06:00 AM'),
  ];
  final Map<String, List<MachineBooking>> byMachine = {};
  for (final b in all) {
    byMachine.putIfAbsent(b.machineName, () => []).add(b);
  }
  return byMachine;
}

class ChatLine {
  final bool mine;
  final String text;
  final DateTime at;

  ChatLine(this.mine, this.text) : at = DateTime.now();
}

/// One chat message bubble (mine on the right, the provider's on the left).
Widget chatBubble(ChatLine m) {
  final String hh = '${m.at.hour % 12 == 0 ? 12 : m.at.hour % 12}';
  final String mm = m.at.minute.toString().padLeft(2, '0');
  final String ap = m.at.hour < 12 ? 'AM' : 'PM';
  return Align(
    alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxWidth: 290),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: m.mine ? kOwnerGreen : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: m.mine ? null : Border.all(color: kOwnerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            m.text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: m.mine ? Colors.white : kOwnerInk,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$hh:$mm $ap',
            style: TextStyle(
              fontSize: 10.5,
              color: m.mine ? Colors.white70 : kOwnerMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Chat with the provider about the price. The provider answers with an offer;
/// the owner accepts it or counters until they agree, then the booking is made.
/// Replies are simulated for the demo.
class MachineryNegotiationPage extends StatefulWidget {
  final String machineName;
  final String provider;
  final String category;
  final List<BookingItem> items;
  final DateTime date;
  final String startTime;
  final String estate;
  final LatLng? machineAt;
  final LatLng? estateAt;
  final double km;
  final MachineInfo? info;

  const MachineryNegotiationPage({
    super.key,
    required this.machineName,
    required this.provider,
    required this.category,
    required this.items,
    required this.date,
    required this.startTime,
    required this.estate,
    this.machineAt,
    this.estateAt,
    this.km = 0,
    this.info,
  });

  @override
  State<MachineryNegotiationPage> createState() =>
      _MachineryNegotiationPageState();
}

class _MachineryNegotiationPageState extends State<MachineryNegotiationPage> {
  final List<ChatLine> _msgs = [];
  final _text = TextEditingController();
  final _counterCtl = TextEditingController();
  final _scroll = ScrollController();
  final List<Timer> _timers = [];
  int _pending = 0; // replies the provider is still "typing"

  int _total = 0; // the provider's current offer for the whole job
  bool _offerOpen = false;
  int _round = 0;

  /// The start time agreed in the chat. It begins as the provider's default
  /// and changes when the owner and provider settle on another time.
  late String _start = widget.startTime;

  bool get _typing => _pending > 0;

  int get _listTotal =>
      widget.items.fold<num>(0, (sum, i) => sum + i.lineTotal).round();

  String get _scope => widget.items.length == 1
      ? widget.items.first.qtyLabel
      : '${widget.items.length} services';

  @override
  void initState() {
    super.initState();
    _total = _listTotal;
    _msgs.add(
      ChatLine(
        true,
        'Hi, I would like to book ${describeItems(widget.items)} on '
        '${fullDate(widget.date)}. Your listed total is ${rupees(_listTotal)}.',
      ),
    );
    _reply(
      'Thanks for the request! ${rupees(_listTotal)} for the job works for '
      'me. I can start at $_start. Tell me if another time suits you better.',
      offer: _listTotal,
    );
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _text.dispose();
    _counterCtl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// The provider types for a moment, then answers (and may put an offer up,
  /// or settle on a new start time).
  void _reply(String text, {int? offer, String? start}) {
    setState(() => _pending++);
    _toBottom();
    _timers.add(
      Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _pending--;
          _msgs.add(ChatLine(false, text));
          if (start != null) _start = start;
          if (offer != null) {
            _total = offer;
            _offerOpen = true;
            _round++;
          }
        });
        _toBottom();
      }),
    );
  }

  /// "8 am", "8:30 PM", "at 7" -> "08:00 AM". Null when no time is mentioned.
  String? _timeIn(String text) {
    final String t = text.toLowerCase();
    final RegExp withSuffix = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)',
    );
    final RegExp bare = RegExp(
      r'\b(?:at|around|by|from)\s+(\d{1,2})(?::(\d{2}))?\b',
    );
    int h;
    int m;
    bool? pm;
    final RegExpMatch? a1 = withSuffix.firstMatch(t);
    if (a1 != null) {
      h = int.parse(a1.group(1)!);
      m = int.tryParse(a1.group(2) ?? '0') ?? 0;
      pm = a1.group(3)!.startsWith('p');
    } else {
      final RegExpMatch? a2 = bare.firstMatch(t);
      if (a2 == null) return null;
      h = int.parse(a2.group(1)!);
      m = int.tryParse(a2.group(2) ?? '0') ?? 0;
      // No am/pm: 5-11 means morning, 12 and 1-4 mean afternoon.
      pm = h == 12 || h <= 4;
    }
    if (h < 1 || h > 12 || m > 59) return null;
    int h24 = h % 12 + (pm ? 12 : 0);
    return _clock12(h24, m);
  }

  static String _clock12(int h24, int m) {
    final int h = h24 % 12 == 0 ? 12 : h24 % 12;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} '
        '${h24 < 12 ? 'AM' : 'PM'}';
  }

  /// The provider works between 06:00 AM and 05:00 PM.
  bool _inHours(String clock) {
    final int h = int.parse(clock.substring(0, 2)) % 12;
    final int h24 = h + (clock.endsWith('PM') ? 12 : 0);
    final int mins = h24 * 60 + int.parse(clock.substring(3, 5));
    return mins >= 6 * 60 && mins <= 17 * 60;
  }

  void _sendText(String t) {
    t = t.trim();
    if (t.isEmpty) return;
    setState(() => _msgs.add(ChatLine(true, t)));
    _toBottom();

    final String? time = _timeIn(t);
    final String low = t.toLowerCase();
    if (time != null) {
      if (_inHours(time)) {
        _reply(
          time == _start
              ? 'Yes, $time is what we have. See you then!'
              : 'Sure, I can start at $time on ${fullDate(widget.date)}.',
          start: time,
        );
      } else {
        _reply(
          'Sorry, $time is outside my hours. I work from 06:00 AM to '
          '05:00 PM. What else suits you?',
        );
      }
    } else if (low.contains('earl')) {
      _reply('I can start as early as 06:00 AM. Shall I do 06:00 AM?');
    } else if (low.contains('late')) {
      _reply('I can start later, up to around 01:00 PM. What time suits you?');
    } else if (low.contains('time') || low.contains('start')) {
      _reply('Right now I have you down for $_start. Name any time you like.');
    } else if (_offerOpen) {
      _reply('Noted. Let me know if you would like to accept the offer.');
    }
  }

  void _send() {
    final String t = _text.text;
    _text.clear();
    _sendText(t);
  }

  Future<void> _counter() async {
    _counterCtl.text = '${(_total * 0.95 / 50).round() * 50}';
    final int? n = await showDialog<int>(
      context: context,
      builder: (ctx) => Theme(
        // Use the app's green instead of Flutter's default purple.
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kOwnerGreen),
        ),
        child: AlertDialog(
          title: const Text('Your counter offer'),
          content: TextField(
            controller: _counterCtl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              prefixText: 'Rs. ',
              suffixText: 'for the job',
              helperText: 'Your price for all the work together',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(_counterCtl.text.trim())),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
    if (n == null || n <= 0 || !mounted) return;

    setState(() {
      _offerOpen = false;
      _msgs.add(
        ChatLine(
          true,
          'Can you do ${rupees(n)} for ${describeItems(widget.items)}?',
        ),
      );
    });
    if (n >= _total) {
      _reply('Deal, ${rupees(n)} works for me.', offer: n);
    } else {
      // Meet in the middle, in steps of Rs. 50.
      final int m = ((n + _total) / 2 / 50).round() * 50;
      final int best = m.clamp(n, _total);
      _reply(
        'Fuel cost is high right now. Best I can do is ${rupees(best)} for '
        'the whole job. Can start $_start.',
        offer: best,
      );
    }
  }

  void _accept() {
    final MachineBooking b = MachineBooking(
      id: '#MC-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}',
      machineName: widget.machineName,
      provider: widget.provider,
      category: widget.category,
      items: widget.items,
      agreedTotal: _total,
      date: widget.date,
      time: _start,
      estate: widget.estate,
      createdAt: DateTime.now(),
      chat: List.of(_msgs),
      machineAt: widget.machineAt,
      estateAt: widget.estateAt,
      km: widget.km,
      info: widget.info,
    );
    machineBookings.putIfAbsent(widget.machineName, () => []).add(b);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BookingConfirmedPage(booking: b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      bottom: _inputBar(),
      child: Column(
        children: [
          OwnerHeader(
            title: widget.provider,
            subtitle:
                'NEGOTIATING · ${widget.items.map((i) => i.name).join(' + ').toUpperCase()}',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: _summary(),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                for (final m in _msgs) chatBubble(m),
                if (_typing)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Provider is typing…',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: kOwnerMuted,
                      ),
                    ),
                  ),
                if (_offerOpen) ...[const SizedBox(height: 12), _offerCard()],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary() => OwnerCard(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        if (widget.info != null)
          MachinePhoto(widget.info!, width: 48, height: 48, radius: 10)
        else
          const Icon(Icons.agriculture, color: kOwnerGreen, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.items.map((i) => i.name).join(' + '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
              Text(
                '${fullDate(widget.date)} · $_scope',
                style: const TextStyle(fontSize: 12, color: kOwnerMuted),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Offer',
              style: TextStyle(fontSize: 11, color: kOwnerMuted),
            ),
            Text(
              rupees(_total),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kOwnerGreen,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _offerCard() => OwnerCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sell, size: 18, color: kOwnerGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _round <= 1 ? 'Offer Received' : 'Counteroffer Received',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: kOwnerInk,
                ),
              ),
            ),
            OwnerPill(_scope),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kOwnerPanel,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              for (final i in widget.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              i.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: kOwnerInk,
                              ),
                            ),
                            Text(
                              i.unit == 'day'
                                  ? '1 day'
                                  : '${i.qtyLabel} × ${rupees(i.rate)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: kOwnerMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        rupees(i.lineTotal),
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: kOwnerMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 8, color: kOwnerBorder),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _round <= 1 ? 'Offer total' : 'Counteroffer total',
                    style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
                  ),
                  Text(
                    rupees(_total),
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: kOwnerGreen,
                    ),
                  ),
                ],
              ),
              if (_total < _listTotal)
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'You save ${rupees(_listTotal - _total)} on the list price',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kOwnerGreen,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.schedule, size: 17, color: kOwnerGreen),
            const SizedBox(width: 8),
            const Text(
              'Start time',
              style: TextStyle(fontSize: 13, color: kOwnerMuted),
            ),
            const Spacer(),
            Text(
              _start,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: kOwnerInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Want another time? Ask in the chat below.',
          style: TextStyle(fontSize: 12, color: kOwnerMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _counter,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kOwnerInk,
                    side: const BorderSide(color: kOwnerBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Decline / Counter',
                      maxLines: 1,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _accept,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'Accept Offer',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kOwnerGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _quickTime(String label, String message) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ActionChip(
      avatar: const Icon(Icons.schedule, size: 15, color: kOwnerGreen),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      backgroundColor: kOwnerGreenSoft,
      side: BorderSide.none,
      onPressed: () => _sendText(message),
    ),
  );

  Widget _inputBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: kOwnerBorder)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickTime('Start earlier', 'Can you start earlier?'),
              _quickTime('6:00 AM', 'Can you start at 6:00 AM?'),
              _quickTime('9:00 AM', 'Can you start at 9:00 AM?'),
              _quickTime('1:00 PM', 'Can you start at 1:00 PM?'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _text,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: kOwnerPanel,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: kOwnerGreen,
              child: IconButton(
                onPressed: _send,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Shown after the owner accepts an offer.
class BookingConfirmedPage extends StatelessWidget {
  final MachineBooking booking;

  const BookingConfirmedPage({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final MachineBooking b = booking;
    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(title: 'BOOKING CONFIRMED'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: kOwnerGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Booking Confirmed!',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: kOwnerInk,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Booking ID:',
                      style: TextStyle(fontSize: 13.5, color: kOwnerMuted),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kOwnerGreenSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        b.id,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: kOwnerGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                OwnerCard(
                  child: Column(
                    children: [
                      _row('Machine', '${b.category} — ${b.machineName}'),
                      _row('Provider', b.provider),
                      _row('Date', '${fullDate(b.date)} (${b.time})'),
                      for (final i in b.items) _row(i.name, i.qtyLabel),
                      if (b.total < b.listTotal)
                        _row('You saved', rupees(b.listTotal - b.total)),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: kOwnerInk,
                            ),
                          ),
                          Text(
                            rupees(b.total),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: kOwnerGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                OwnerPrimaryButton(
                  label: 'View Bookings',
                  arrow: true,
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyBookingsPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: const Text(
                      'Return to Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: kOwnerInk,
                      backgroundColor: const Color(0xFFEEF0FB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: kOwnerMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kOwnerInk,
            ),
          ),
        ),
      ],
    ),
  );
}

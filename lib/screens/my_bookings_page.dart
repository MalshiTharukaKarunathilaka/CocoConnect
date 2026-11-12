import 'package:flutter/material.dart';
import '../widgets/machinery_widgets.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import '../services/api_client.dart';
import '../services/machinery_service.dart';
import 'machinery_booking_status_page.dart';
import 'machinery_negotiation_page.dart';

const List<String> _weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const List<String> _monthNames = [
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

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// All of the estate owner's machinery bookings: Upcoming and Completed.
/// The calendar marks each booked day with one dot per booking, coloured by
/// machine type, so a day with a tractor and a backhoe shows two dots.
class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  int _tab = 0; // 0 upcoming, 1 completed
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// The bookings live on the server; this pulls the latest copy.
  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await MachineryService.refreshBookings();
      if (!mounted) return;
      setState(() => _loading = false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  DateTime get _today {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _typeOf(MachineBooking b) => b.info?.type ?? 'TRACTOR';

  void _pickDay(DateTime d) {
    setState(() {
      if (_day != null && _key(_day!) == _key(d)) {
        _day = null; // tap again to clear
      } else {
        _day = d;
        _tab = d.isBefore(_today) ? 1 : 0;
      }
    });
  }

  Future<void> _open(MachineBooking b) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MachineryBookingStatusPage(booking: b),
      ),
    );
    // It may have been cancelled in there.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<MachineBooking> all = allMachineBookings();
    final List<MachineBooking> upcoming =
        all.where((b) => !b.isCompleted).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final List<MachineBooking> done = all.where((b) => b.isCompleted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    List<MachineBooking> shown = _tab == 0 ? upcoming : done;
    if (_day != null) {
      shown = shown.where((b) => _key(b.date) == _key(_day!)).toList();
    }

    final Map<String, List<MachineBooking>> byDay = {};
    for (final b in all) {
      byDay.putIfAbsent(_key(b.date), () => []).add(b);
    }

    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(title: 'My Bookings', subtitle: 'MACHINERY'),
          const SizedBox(height: 12),
          OwnerTabs(
            labels: [
              'Upcoming (${upcoming.length})',
              'Completed (${done.length})',
            ],
            selected: _tab,
            onSelected: (i) => setState(() {
              _tab = i;
              _day = null;
              // Show the month the bookings in this tab are in.
              final List<MachineBooking> list = i == 0 ? upcoming : done;
              if (list.isNotEmpty) {
                _month = DateTime(list.first.date.year, list.first.date.month);
              }
            }),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OwnerCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: kOwnerRed),
                            ),
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                _calendar(byDay),
                const SizedBox(height: 16),
                if (_day != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fullDate(_day!),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: kOwnerInk,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _day = null),
                          child: const Text('Show all'),
                        ),
                      ],
                    ),
                  ),
                if (_loading && all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(color: kOwnerGreen),
                    ),
                  )
                else if (shown.isEmpty)
                  _empty()
                else
                  for (final b in shown) _card(b),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => OwnerCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
    child: Column(
      children: [
        Icon(
          _tab == 0 ? Icons.event_available_outlined : Icons.history,
          size: 38,
          color: kOwnerMuted,
        ),
        const SizedBox(height: 10),
        Text(
          _day != null
              ? 'No bookings on this day.'
              : _tab == 0
              ? 'No upcoming bookings yet.\nPick a machine on the map and choose a date.'
              : 'No completed bookings yet.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: kOwnerMuted,
          ),
        ),
      ],
    ),
  );

  Widget _calendar(Map<String, List<MachineBooking>> byDay) {
    final DateTime first = DateTime(_month.year, _month.month, 1);
    final int lead = first.weekday - 1;
    final int days = DateTime(_month.year, _month.month + 1, 0).day;

    Widget arrow(IconData icon, int by) => Material(
      color: kOwnerPanel,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () =>
            setState(() => _month = DateTime(_month.year, _month.month + by)),
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
                  '${_monthNames[_month.month - 1]} ${_month.year}',
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
              for (final w in _weekdayLetters)
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
                  Expanded(
                    child: _cell(week * 7 + dow - lead + 1, days, byDay),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _TypeKey('TRACTOR'),
              _TypeKey('BACKHOE'),
              _TypeKey('HAND_TRACTOR'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(int n, int days, Map<String, List<MachineBooking>> byDay) {
    if (n < 1 || n > days) return const SizedBox(height: 46);
    final DateTime d = DateTime(_month.year, _month.month, n);
    final List<MachineBooking> list = byDay[_key(d)] ?? const [];
    final bool selected = _day != null && _key(_day!) == _key(d);
    final bool today = _key(d) == _key(_today);
    final bool past = d.isBefore(_today);

    return GestureDetector(
      onTap: () => _pickDay(d),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected
              ? kOwnerGreen
              : list.isNotEmpty
              ? const Color(0xFFF4F8F5)
              : Colors.transparent,
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
                fontWeight: today || selected || list.isNotEmpty
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : past
                    ? const Color(0xFF9AA0A6)
                    : kOwnerInk,
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final b in list.take(3))
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: machineColor(_typeOf(b)),
                        shape: BoxShape.circle,
                        // A white ring keeps the dot visible on the green cell.
                        border: selected
                            ? Border.all(color: Colors.white, width: 1.2)
                            : null,
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

  String _when(MachineBooking b) {
    final int diff = DateTime(
      b.date.year,
      b.date.month,
      b.date.day,
    ).difference(_today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1) return 'In $diff days';
    return '${-diff} days ago';
  }

  Widget _card(MachineBooking b) {
    final String type = _typeOf(b);
    final Color c = machineColor(type);
    final MachineInfo? m = b.info;
    final bool done = b.isCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _open(b),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kOwnerBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
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
                        if (m != null)
                          MachinePhoto(m, width: 78, height: 78, radius: 10)
                        else
                          Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              color: kOwnerGreenSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(machineIcon(type), color: c),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      b.machineName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.bold,
                                        color: kOwnerInk,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  OwnerPill(
                                    done ? 'Completed' : 'Confirmed',
                                    icon: done
                                        ? Icons.done_all
                                        : Icons.check_circle_outline,
                                    tone: done
                                        ? PillTone.neutral
                                        : PillTone.green,
                                  ),
                                ],
                              ),
                              Text(
                                '${b.provider} · ${b.service}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: kOwnerMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.event,
                                    size: 14,
                                    color: kOwnerGreen,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${b.date.day} ${_monthNames[b.date.month - 1].substring(0, 3)} · ${b.time} · ${_when(b)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: kOwnerGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kOwnerPanel,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      b.scope,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: kOwnerInk,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    rupees(b.total),
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
        ),
      ),
    );
  }
}

/// A coloured dot and the machine type it stands for.
class _TypeKey extends StatelessWidget {
  final String type;

  const _TypeKey(this.type);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: machineColor(type),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      Text(
        machineLabel(type),
        style: const TextStyle(fontSize: 12.5, color: kOwnerInk),
      ),
    ],
  );
}

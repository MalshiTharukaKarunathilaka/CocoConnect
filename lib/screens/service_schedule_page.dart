import 'package:flutter/material.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';

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
    this.note,
  );
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

enum _Status { confirmed, pending }

/// A service booked on a day.
class _Job {
  final _Service service;
  final _Status status;
  final String estate;
  final double acres;
  final String time;

  const _Job(this.service, this.status, this.estate, this.acres, this.time);

  int get amount =>
      service.unit == 'acre' ? (service.rate * acres).round() : service.rate;
}

/// Sample bookings around today, for showing the idea to clients.
Map<String, List<_Job>> _demoJobs() {
  final DateTime t = DateTime.now();
  String key(int offset) => _key(DateTime(t.year, t.month, t.day + offset));
  return {
    key(0): [
      _Job(
        _services[0],
        _Status.confirmed,
        'Green Valley Estate',
        4.5,
        '07:00 AM - 12:00 PM',
      ),
      _Job(
        _services[1],
        _Status.confirmed,
        'Green Valley Estate',
        4.5,
        '01:00 PM - 05:00 PM',
      ),
    ],
    key(2): [
      _Job(
        _services[2],
        _Status.pending,
        'Malkaduwawa Plantation',
        8,
        '06:00 AM - 12:00 PM',
      ),
    ],
    key(4): [
      _Job(
        _services[4],
        _Status.confirmed,
        'Serenity Palms Estate',
        6,
        'Full day',
      ),
      _Job(
        _services[3],
        _Status.pending,
        'Kelani Palms',
        3,
        '01:00 PM - 05:00 PM',
      ),
    ],
    key(7): [
      _Job(
        _services[3],
        _Status.confirmed,
        'Sirisena Estate',
        5,
        '07:00 AM - 11:00 AM',
      ),
    ],
    key(9): [
      _Job(
        _services[0],
        _Status.pending,
        'Kiribathgoda Estate',
        2,
        '08:00 AM - 10:00 AM',
      ),
      _Job(
        _services[1],
        _Status.pending,
        'Kiribathgoda Estate',
        2,
        '10:00 AM - 01:00 PM',
      ),
    ],
    key(12): [
      _Job(
        _services[2],
        _Status.confirmed,
        'Green Serenity Estate',
        4.5,
        '06:00 AM - 12:00 PM',
      ),
    ],
  };
}

String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Month calendar of machinery services: red for confirmed jobs, amber for
/// pending ones. Picking a day lists its jobs and the services still free.
class ServiceSchedulePage extends StatefulWidget {
  const ServiceSchedulePage({super.key});

  @override
  State<ServiceSchedulePage> createState() => _ServiceSchedulePageState();
}

class _ServiceSchedulePageState extends State<ServiceSchedulePage> {
  final Map<String, List<_Job>> _jobs = _demoJobs();
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _day = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  List<_Job> _on(DateTime d) => _jobs[_key(d)] ?? const [];

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final List<_Job> jobs = _on(_day);
    final Set<_Service> taken = {for (final j in jobs) j.service};
    final List<_Service> free = _services
        .where((s) => !taken.contains(s))
        .toList();

    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(
            title: 'Service Schedule',
            subtitle: 'MACHINERY BOOKINGS',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _calendar(),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: kOwnerGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_weekdays[_day.weekday - 1]}, ${_day.day} ${_months[_day.month - 1]}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: kOwnerInk,
                        ),
                      ),
                    ),
                    OwnerPill(
                      jobs.isEmpty ? 'Free day' : '${jobs.length} booked',
                      tone: jobs.isEmpty ? PillTone.neutral : PillTone.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (jobs.isEmpty)
                  const OwnerCard(
                    child: Text(
                      'No services booked on this day.',
                      style: TextStyle(fontSize: 13.5, color: kOwnerMuted),
                    ),
                  ),
                for (final j in jobs) ...[
                  _jobCard(j),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Available Services',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: kOwnerInk,
                  ),
                ),
                const Text(
                  'Still free to book on this day',
                  style: TextStyle(fontSize: 12.5, color: kOwnerMuted),
                ),
                const SizedBox(height: 10),
                for (final s in free) ...[
                  _serviceCard(s),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendar() {
    final DateTime first = DateTime(_month.year, _month.month, 1);
    final int lead = first.weekday - 1;
    final int days = DateTime(_month.year, _month.month + 1, 0).day;

    return OwnerCard(
      child: Column(
        children: [
          Row(
            children: [
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
              IconButton(
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left, color: kOwnerInk),
              ),
              IconButton(
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right, color: kOwnerInk),
              ),
            ],
          ),
          Row(
            children: [
              for (final w in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(fontSize: 12, color: kOwnerMuted),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (int week = 0; week * 7 < lead + days; week++)
            Row(
              children: [
                for (int dow = 0; dow < 7; dow++)
                  Expanded(child: _dayCell(week * 7 + dow - lead + 1, days)),
              ],
            ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Legend(color: _red, label: 'Confirmed'),
              _Legend(color: _amber, label: 'Pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(int n, int days) {
    if (n < 1 || n > days) return const SizedBox(height: 50);
    final DateTime d = DateTime(_month.year, _month.month, n);
    final bool selected = _key(d) == _key(_day);
    final DateTime now = DateTime.now();
    final bool today = _key(d) == _key(DateTime(now.year, now.month, now.day));
    final List<_Job> jobs = _on(d);
    final bool confirmed = jobs.any((j) => j.status == _Status.confirmed);
    final bool pending = jobs.any((j) => j.status == _Status.pending);

    return GestureDetector(
      onTap: () => setState(() => _day = d),
      child: Container(
        height: 50,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? kOwnerGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: today && !selected ? Border.all(color: kOwnerGreen) : null,
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
                    : confirmed
                    ? _red
                    : kOwnerInk,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (confirmed) _dot(selected ? Colors.white : _red),
                if (pending) _dot(_amber),
              ],
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
    child: Image.asset(
      'assets/services/${s.photo}.jpg',
      width: 74,
      height: 74,
      fit: BoxFit.cover,
    ),
  );

  Widget _jobCard(_Job j) {
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
                    _photo(j.service),
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
                              _chip(
                                j.service.unit == 'acre'
                                    ? '${j.acres % 1 == 0 ? j.acres.toInt() : j.acres} acres'
                                    : '1 day',
                              ),
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

  Widget _serviceCard(_Service s) {
    return OwnerCard(
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
                      s.unit == 'acre'
                          ? '4.5 acres = ${rupees(s.rate * 4.5)}'
                          : 'Per day',
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

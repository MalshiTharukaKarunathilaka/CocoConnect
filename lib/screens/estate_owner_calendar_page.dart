import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import 'job_detail_page.dart';
import 'post_day_job_page.dart';

const Color _calendarGreen = Color(0xFF246B45);
const Color _calendarBackground = Color(0xFFFCF8F3);
const Color _calendarInk = Color(0xFF152238);

class EstateOwnerCalendarPage extends StatefulWidget {
  const EstateOwnerCalendarPage({super.key});

  @override
  State<EstateOwnerCalendarPage> createState() =>
      _EstateOwnerCalendarPageState();
}

class _EstateOwnerCalendarPageState extends State<EstateOwnerCalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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

  final Map<int, Color> _dayStatuses = const {
    8: Color(0xFFF0A315),
    15: _calendarGreen,
    16: _calendarGreen,
    17: _calendarGreen,
    19: _calendarGreen,
    20: Color(0xFFF0A315),
    22: _calendarGreen,
    24: Color(0xFFF0A315),
    25: _calendarGreen,
    26: _calendarGreen,
    28: _calendarGreen,
    30: Color(0xFFF0A315),
  };

  final Map<int, IconData> _dayTypes = const {
    7: Icons.agriculture,
    8: Icons.agriculture,
    12: Icons.build,
    15: Icons.agriculture,
    17: Icons.build,
    19: Icons.agriculture,
    20: Icons.eco,
    22: Icons.eco,
    24: Icons.build,
    25: Icons.star_border,
    26: Icons.eco,
    28: Icons.eco,
    30: Icons.agriculture,
  };

  static const Set<String> _poyaDays2026 = {
    '2026-01-03',
    '2026-02-01',
    '2026-03-03',
    '2026-04-02',
    '2026-05-01',
    '2026-05-31',
    '2026-06-29',
    '2026-07-29',
    '2026-08-28',
    '2026-09-26',
    '2026-10-26',
    '2026-11-24',
    '2026-12-24',
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(_month.year, _month.month, 15);
  }

  void _changeMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
      _selectedDay = null;
    });
  }

  void _selectDay(int day) {
    setState(() {
      _selectedDay = DateTime(_month.year, _month.month, day);
    });
    if (day == 15) {
      _showDayActions();
    }
  }

  void _showDayActions() {
    final selectedDay = DateTime(_month.year, _month.month, 15);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      builder: (context) => _DayActionsSheet(
        date: selectedDay,
        onAddJob: () {
          Navigator.pop(context);
          Navigator.push(
            this.context,
            MaterialPageRoute(
              builder: (_) => PostDayJobPage(requiredDate: selectedDay),
            ),
          );
        },
        onViewJobs: () {
          Navigator.pop(context);
          Navigator.push(
            this.context,
            MaterialPageRoute(builder: (_) => JobDetailPage(date: selectedDay)),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _calendarBackground,
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                    children: [
                      _estateSummary(),
                      const SizedBox(height: 12),
                      _calendarCard(),
                      const SizedBox(height: 12),
                      _categoryCard(),
                    ],
                  ),
                ),
                const _CalendarBottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: const Icon(
              Icons.arrow_back,
              size: 28,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KapConnect',
                style: TextStyle(
                  color: _calendarGreen,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'DAY JOBS',
                style: TextStyle(
                  color: Color(0xFF718096),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE9E3D8),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _language('EN', active: true),
                _language('SI'),
                _language('TA'),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _calendarGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 29,
            ),
          ),
        ],
      ),
    );
  }

  Widget _language(String value, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? _calendarGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF555555),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _estateSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E2D9)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFF0EDE6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.park, size: 28, color: _calendarGreen),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kurunegala Palm Estate',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _calendarInk,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F0E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 17,
                  color: Color(0xFF718096),
                ),
                SizedBox(width: 4),
                Text(
                  'Zone 04',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D4A5D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarCard() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingDays = firstDay.weekday - 1;
    final rows = ((leadingDays + daysInMonth + 1) / 7).ceil();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE9E2D9)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]}\n${_month.year}',
                  style: const TextStyle(
                    color: _calendarInk,
                    fontSize: 26,
                    height: 1.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _monthButton(Icons.chevron_left, () => _changeMonth(-1)),
              const SizedBox(width: 8),
              _monthButton(Icons.chevron_right, () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: const TextStyle(
                        color: Color(0xFF3D4A5D),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (int row = 0; row < rows; row++)
            Row(
              children: [
                for (int column = 0; column < 7; column++)
                  Expanded(
                    child: _dayCell(
                      row * 7 + column - leadingDays + 1,
                      daysInMonth,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _categoryCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9E2D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _Legend(color: Color(0xFFF0A315), label: 'Partially Filled'),
              SizedBox(width: 22),
              _Legend(color: _calendarGreen, label: 'Fully Filled'),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFEDE5DA)),
          ),
          const Text(
            'CATEGORY / DAY TYPE',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: .5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _CategoryChip(Icons.eco, 'Nut Gatherer'),
              _CategoryChip(Icons.agriculture, 'Machine Weeder'),
              _CategoryChip(Icons.build, 'Manual Worker'),
              _CategoryChip(Icons.star_border, 'Holiday'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE9E6DF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 28, color: const Color(0xFF68736B)),
        ),
      ),
    );
  }

  Widget _dayCell(int day, int daysInMonth) {
    final bool isPreviousMonth = day < 1;
    final bool isNextMonth = day > daysInMonth;
    final int displayDay = isPreviousMonth
        ? DateTime(_month.year, _month.month, 0).day + day
        : isNextMonth
        ? day - daysInMonth
        : day;
    final bool isPreviewDay = isPreviousMonth || isNextMonth;
    final DateTime cellDate = DateTime(
      _month.year,
      _month.month,
      displayDay,
    );
    final DateTime today = DateTime.now();
    final DateTime todayDate = DateTime(today.year, today.month, today.day);
    final bool isGreenDate =
        !isPreviewDay &&
        ((_month.year == 2026 &&
                _month.month == DateTime.november &&
                const {
                  6,
                  7,
                  9,
                  10,
                  11,
                  12,
                  13,
                  14,
                  18,
                  20,
                  21,
                  23,
                  24,
                  27,
                  29,
                  30,
                }.contains(displayDay)) ||
            (_month.year == 2026 && _month.month == DateTime.december) ||
            _month.year == 2027);
    final bool isPastDay = !isPreviewDay && cellDate.isBefore(todayDate);
    final bool isTodayOrTomorrow =
        !isPreviewDay &&
        !isPastDay &&
        (cellDate.isAtSameMomentAs(todayDate) ||
            cellDate.isAtSameMomentAs(
              todayDate.add(const Duration(days: 1)),
            ));

    final selected =
        !isPreviewDay &&
        _selectedDay?.year == _month.year &&
        _selectedDay?.month == _month.month &&
        _selectedDay?.day == day;
    final statusColor = isPreviewDay ? null : _dayStatuses[day];
    final dayType = isPreviewDay ? null : _dayTypes[day];
    final isPoyaDay =
        !isPreviewDay &&
        _poyaDays2026.contains(
          '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
        );

    return GestureDetector(
      onTap: isPreviewDay ? null : () => _selectDay(day),
      child: SizedBox(
        height: 78,
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.fromLTRB(8, 7, 7, 5),
          decoration: BoxDecoration(
            color: isNextMonth && displayDay == 1
                ? const Color(0xFFBFD5C7)
                : selected
                ? _calendarGreen
                : isPreviewDay
                ? const Color(0xFFF4F3F0)
                : isGreenDate
                ? const Color(0xFFBDD3C4)
                : isPastDay
                ? const Color(0xFFEBE9E3)
              : isTodayOrTomorrow
              ? const Color(0xFFBDD3C4)
              : statusColor == null
              ? const Color(0xFFEBE9E3)
              : statusColor == const Color(0xFFF0A315)
                ? const Color(0xFFF0EEE8)
                : const Color(0xFFBDD3C4),
            borderRadius: BorderRadius.circular(17),
            border: isNextMonth && displayDay == 1
                ? Border.all(color: const Color(0xFF2A9F78), width: 1.5)
                : selected
                ? Border.all(color: const Color(0xFF0B9368), width: 3)
                : null,
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  isNextMonth && displayDay == 1
                      ? '$displayDay ${_months[(_month.month) % 12].substring(0, 3)}'
                      : '$displayDay',
                  style: TextStyle(
                    color: isPreviewDay
                        ? const Color(0xFF687078)
                        : selected
                        ? Colors.white
                        : _calendarInk,
                    fontSize: 16,
                    fontWeight: isPreviewDay || selected
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (statusColor != null)
                Positioned(
                  top: 1,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: selected || statusColor == const Color(0xFFF0A315)
                          ? const Color(0xFFFFB318)
                          : const Color(0xFF07835F),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (isPoyaDay)
                const Positioned(
                  bottom: 1,
                  left: 0,
                  child: Icon(Icons.star_border, size: 18, color: Colors.red),
                )
              else if (dayType != null)
                Positioned(
                  bottom: 1,
                  left: 0,
                  child: Icon(
                    dayType,
                    size: 18,
                    color: selected
                        ? const Color(0xFFB7E2C7)
                        : const Color(0xFF4D6D5A),
                  ),
                ),
              if (isNextMonth && displayDay == 1)
                const Positioned(
                  bottom: 0,
                  left: 1,
                  child: Text(
                    '+',
                    style: TextStyle(
                      color: _calendarGreen,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayActionsSheet extends StatelessWidget {
  final DateTime date;
  final VoidCallback onAddJob;
  final VoidCallback onViewJobs;

  const _DayActionsSheet({
    required this.date,
    required this.onAddJob,
    required this.onViewJobs,
  });

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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

  @override
  Widget build(BuildContext context) {
    final label =
        '${_weekdays[date.weekday - 1]}, ${date.day} '
        '${_months[date.month - 1]} ${date.year}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(36, 16, 36, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E1DA),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 34),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 25),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4ED),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD4E7D9)),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _calendarGreen,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 38),
            _ActionButton(
              icon: Icons.add,
              label: 'Add Job for This Date',
              backgroundColor: const Color(0xFF197549),
              foregroundColor: Colors.white,
              onTap: onAddJob,
            ),
            const SizedBox(height: 18),
            _ActionButton(
              icon: Icons.format_list_bulleted,
              label: 'View Jobs',
              backgroundColor: const Color(0xFFF0F5EF),
              foregroundColor: _calendarGreen,
              onTap: onViewJobs,
            ),
            const SizedBox(height: 38),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F4EC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _calendarGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Schedule Day',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onViewJobs,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Manage'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _calendarGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
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
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 86,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 32),
        label: Text(
          label,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CategoryChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EFE6),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _calendarGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _calendarInk,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarBottomNavigation extends StatelessWidget {
  const _CalendarBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8E2D6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _item(
            context,
            Icons.dashboard_outlined,
            'Dashboard',
            onTap: () => openTab(context, AppTab.dashboard),
          ),
          _item(context, Icons.calendar_month, 'Calendar', active: true),
          _item(
            context,
            Icons.receipt_long_outlined,
            'Orders',
            onTap: () => openTab(context, AppTab.orders),
          ),
          _item(
            context,
            Icons.person_outline,
            'Profile',
            onTap: () => openTab(context, AppTab.profile),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool active = false,
  }) {
    final color = active ? _calendarGreen : const Color(0xFF66615D);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFDDEEE0) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                active ? Icons.calendar_month : icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF66615D), fontSize: 12),
        ),
      ],
    );
  }
}

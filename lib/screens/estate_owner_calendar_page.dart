import 'package:flutter/material.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/owner_service.dart';
import '../services/chat_service.dart';
import '../services/api_client.dart';
import 'post_day_job_page.dart';
import 'scheduled_jobs_page.dart';

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
  List<DayJob> _postedJobs = [];
  int _notificationCount = 0;

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
    _loadPostedJobs();
    _loadNotificationCount();
  }

  Future<void> _loadNotificationCount() async {
    try {
      final items = await ChatService.getNotifications();
      final count = await ChatService.unseenCount(items);
      if (mounted) setState(() => _notificationCount = count);
    } on ApiException {
      // Keep the calendar usable if notifications are unavailable.
    }
  }

  Future<void> _loadPostedJobs() async {
    try {
      final jobs = await OwnerService.getDayJobs();
      if (mounted) {
        setState(() => _postedJobs = jobs);
      }
    } catch (error) {
      debugPrint('Could not load posted jobs for calendar: $error');
    }
  }

  void _changeMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
      _selectedDay = null;
    });
    _loadPostedJobs();
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
    });
    _showDayActions();
  }

  void _showDayActions() {
    final selectedDay = _selectedDay;
    if (selectedDay == null) {
      return;
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final isPast = selectedDate.isBefore(todayDate);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
      ),
      builder: (context) => _DayActionsSheet(
        date: selectedDay,
        showScheduleActions: !isPast,
        onAddJob: () {
          Navigator.pop(context);
          Navigator.push(
            this.context,
            MaterialPageRoute(
              builder: (_) => PostDayJobPage(requiredDate: selectedDay),
            ),
          ).then((_) => _loadPostedJobs());
        },
        onViewJobs: () {
          Navigator.pop(context);
          Navigator.push(
            this.context,
            MaterialPageRoute(
              builder: (_) => ScheduledJobsPage(date: selectedDay),
            ),
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
                _CalendarBottomNavigation(notificationCount: _notificationCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kapconnect',
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _months[_month.month - 1],
                      style: const TextStyle(
                        color: _calendarInk,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_month.year}',
                      style: const TextStyle(
                        color: _calendarInk,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _monthButton(Icons.chevron_left, () => _changeMonth(-1)),
              const SizedBox(width: 8),
              _monthButton(Icons.chevron_right, () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final weekday in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: const TextStyle(
                        color: Color(0xFF3D4A5D),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - leadingDays;
              return _dayCell(dayOffset + 1, daysInMonth);
            },
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: Color(0xFFF0A315), label: 'Partially filled'),
              SizedBox(width: 24),
              _Legend(color: _calendarGreen, label: 'Fully filled'),
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
              _CategoryChip(Icons.agriculture, 'Machine Worker'),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF0EEE8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, size: 24, color: const Color(0xFF68736B)),
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
    final DateTime cellDate = DateTime(_month.year, _month.month, day);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final isPastDay = !isPreviewDay && cellDate.isBefore(todayDate);
    final isTodayOrFuture = !isPreviewDay && !isPastDay;
    final jobsOnDay = _postedJobs.where((job) {
      return job.requiredDate.year == cellDate.year &&
          job.requiredDate.month == cellDate.month &&
          job.requiredDate.day == cellDate.day;
    }).toList();
    final selected =
        _selectedDay?.year == cellDate.year &&
        _selectedDay?.month == cellDate.month &&
        _selectedDay?.day == cellDate.day;
    final statusColor = isPreviewDay || jobsOnDay.isEmpty
        ? null
        : jobsOnDay.every(
            (job) => job.confirmedWorkers >= job.workersNeeded,
          )
        ? _calendarGreen
        : const Color(0xFFF0A315);
    final jobIcons = isPreviewDay
        ? <IconData>[]
        : jobsOnDay.map((job) => _iconForJobCategory(job.category)).toList();
    final isPoyaDay =
        !isPreviewDay &&
        _poyaDays2026.contains(
          '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
        );

    return GestureDetector(
      onTap: () => _selectDay(cellDate),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
        decoration: BoxDecoration(
          color: isNextMonth && displayDay == 1
              ? const Color(0xFFBFD5C7)
              : selected
              ? _calendarGreen
              : isPreviewDay
              ? const Color(0xFFF4F3F0)
              : isTodayOrFuture
              ? const Color(0xFFBDD3C4)
              : const Color(0xFFEBE9E3),
          borderRadius: BorderRadius.circular(16),
          border: isNextMonth && displayDay == 1
              ? Border.all(color: const Color(0xFF2A9F78), width: 1.5)
              : selected
              ? Border.all(color: const Color(0xFF0B9368), width: 2)
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
                  fontSize: 14,
                  fontWeight: isPreviewDay || selected
                      ? FontWeight.bold
                      : FontWeight.w500,
                ),
              ),
            ),
            if (statusColor != null)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 8,
                  height: 8,
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
                child: Icon(Icons.star_border, size: 16, color: Colors.red),
              )
            else if (jobIcons.isNotEmpty)
              Positioned(
                bottom: 1,
                left: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final icon in jobIcons)
                      Padding(
                        padding: const EdgeInsets.only(right: 1),
                        child: Icon(
                          icon,
                          size: 11,
                          color: selected
                              ? const Color(0xFFB7E2C7)
                              : const Color(0xFF4D6D5A),
                        ),
                      ),
                  ],
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
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  IconData _iconForJobCategory(String category) {
    final value = category.toLowerCase();
    if (value.contains('machine') || value.contains('weeder')) {
      return Icons.agriculture;
    }
    if (value.contains('nut') || value.contains('gather')) {
      return Icons.eco;
    }
    if (value.contains('holiday')) {
      return Icons.star_border;
    }
    return Icons.build;
  }
}

class _DayActionsSheet extends StatelessWidget {
  final DateTime date;
  final bool showScheduleActions;
  final VoidCallback onAddJob;
  final VoidCallback onViewJobs;

  const _DayActionsSheet({
    required this.date,
    required this.showScheduleActions,
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

  @override
  Widget build(BuildContext context) {
    final bool isScheduleView = showScheduleActions;
    final label =
        '${_weekdays[date.weekday - 1]}, '
        '${date.day.toString().padLeft(2, '0')} '
        '${_months[date.month - 1]} ${date.year}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFFE0DDD6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4ED),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD4E7D9)),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _calendarGreen,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (isScheduleView) ...[
              _ActionButton(
                icon: Icons.add,
                label: 'Add Job for This Date',
                backgroundColor: const Color(0xFF1E653F),
                foregroundColor: Colors.white,
                onTap: onAddJob,
              ),
              const SizedBox(height: 14),
            ],
            _ActionButton(
              icon: Icons.format_list_bulleted,
              label: 'View Jobs',
              backgroundColor: const Color(0xFFEAF4ED),
              foregroundColor: _calendarGreen,
              onTap: onViewJobs,
            ),
            if (isScheduleView) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5EE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _calendarGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Schedule',
                            style: TextStyle(
                              color: _calendarInk,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Day',
                            style: TextStyle(
                              color: _calendarInk,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onViewJobs,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _calendarGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Manage',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
      height: 52,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22, color: foregroundColor),
        label: Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
  final int notificationCount;

  const _CalendarBottomNavigation({this.notificationCount = 0});

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
            Icons.notifications_none,
            'Alerts',
            badge: notificationCount,
            onTap: () => openTab(context, AppTab.alerts),
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
    int badge = 0,
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
              child: Badge(
                isLabelVisible: badge > 0,
                label: Text(badge > 99 ? '99+' : '$badge'),
                backgroundColor: Colors.red,
                child: Icon(
                  active ? Icons.calendar_month : icon,
                  size: 22,
                  color: color,
                ),
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

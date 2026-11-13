import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/day_job_chat_service.dart';
import '../services/worker_service.dart';
import 'auth_gate.dart';
import 'worker_chat_page.dart';
import 'estate_jobs_map_page.dart';

const _workerGreen = Color(0xFF2D704D);
const _workerBackground = Color(0xFFFCF9F3);
const _workerInk = Color(0xFF252525);
const _workerMuted = Color(0xFF6D6D66);

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard>
    with WidgetsBindingObserver {
  static const _months = [
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

  late Future<List<WorkerJob>> _jobs;
  final _searchController = TextEditingController();
  int _tab = 0;
  bool _myJobsOnly = false;
  int _notificationCount = 0;
  Timer? _notificationTimer;
  String? _category;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  String? _selectedEstate;
  int? _radiusKm = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _jobs = WorkerService.getAvailableJobs();
    _refreshNotificationCount();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshNotificationCount(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadJobs();
    }
  }

  void _reloadJobs() {
    if (!mounted) return;
    setState(() => _jobs = WorkerService.getAvailableJobs());
  }

  Future<void> _refreshNotificationCount() async {
    try {
      final items = await ChatService.getNotifications();
      final count = await ChatService.unseenCount(items);
      if (mounted) setState(() => _notificationCount = count);
    } on ApiException {
      // The jobs dashboard remains usable when notifications are unavailable.
    }
  }

  Future<void> _refresh() async {
    _reloadJobs();
    await _jobs;
  }

  Future<void> _apply(WorkerJob job) async {
    try {
      await WorkerService.applyForJob(job.id);
      if (!mounted) return;
      final refreshedJobs = WorkerService.getAvailableJobs();
      setState(() => _jobs = refreshedJobs);
      await refreshedJobs;
      await _showJobConfirmation(job);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showJobConfirmation(WorkerJob job) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: _workerBackground,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Job confirmation',
                  style: TextStyle(
                    color: _workerInk,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              Container(
                width: 184,
                height: 184,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F1E9),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(30),
                child: Container(
                  decoration: const BoxDecoration(
                    color: _workerGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 62),
                ),
              ),
              const SizedBox(height: 52),
              const Text(
                'Job accepted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _workerInk,
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'You’re confirmed for this job.\n'
                'You can find it in My jobs anytime.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _workerMuted,
                  fontSize: 21,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 38),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(30, 28, 30, 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.category,
                            style: const TextStyle(
                              color: _workerInk,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _confirmationStatus('Confirmed'),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(height: 1, color: Color(0xFFE9E2D9)),
                    ),
                    const _ConfirmationInfo(
                      icon: Icons.access_time,
                      text: 'Full day',
                    ),
                    const SizedBox(height: 22),
                    _ConfirmationInfo(
                      icon: Icons.payments_outlined,
                      text: 'Rs. ${job.dailyRate.toStringAsFixed(0)} / day',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 42),
              SizedBox(
                width: 250,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _workerGreen,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                  child: const Text(
                    'Okay',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

  Widget _confirmationStatus(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1E9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _workerGreen,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          color: _workerBackground,
          child: SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(child: _content()),
                _bottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleBack,
            child: const Icon(Icons.arrow_back, size: 31, color: _workerInk),
          ),
          const SizedBox(width: 14),
          const Flexible(
            child: Text(
              'Kapconnect',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _workerGreen,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          _languageChip('EN', active: true),
          _languageChip('SI'),
          _languageChip('TA'),
        ],
      ),
    );
  }

  void _handleBack() {
    if (_tab == 1) {
      if (_selectedEstate != null) {
        setState(() => _selectedEstate = null);
        return;
      }
      setState(() {
        _tab = 0;
        _selectedDate = null;
        _selectedEstate = null;
        _myJobsOnly = false;
        _category = null;
      });
      _reloadJobs();
      return;
    }
    Navigator.maybePop(context);
  }

  Widget _languageChip(String text, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _workerGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: active ? Colors.white : _workerMuted,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _content() {
    if (_tab == 2) {
      return _notifications();
    }
    if (_tab == 3) {
      return _profilePage();
    }
    if (_tab == 1) {
      return _nearbyWorkPage();
    }

    return RefreshIndicator(
      color: _workerGreen,
      onRefresh: _refresh,
      child: FutureBuilder<List<WorkerJob>>(
        future: _jobs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final jobs = snapshot.data ?? const <WorkerJob>[];
          return _dashboardContent(
            jobs,
            error: snapshot.hasError ? '${snapshot.error}' : null,
          );
        },
      ),
    );
  }

  Widget _dashboardContent(List<WorkerJob> jobs, {String? error}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      children: [
        if (error != null) _errorBanner(error),
        _profileCard(),
        const SizedBox(height: 24),
        _searchBox(),
        const SizedBox(height: 14),
        _myJobsButton(),
        const SizedBox(height: 24),
        _categoryShortcuts(),
        const SizedBox(height: 18),
        _calendarCard(jobs),
        const SizedBox(height: 10),
        _calendarDetailsCard(),
        const SizedBox(height: 22),
        _liveJobs(jobs, onlyApplied: _tab == 1),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7A26D)),
      ),
      child: Text(
        'Jobs could not be loaded yet.\n$message',
        style: const TextStyle(color: Color(0xFF8A4B1E), fontSize: 12),
      ),
    );
  }

  Widget _profileCard() {
    final user = AuthService.currentUser;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFE9E6DC),
            child: Icon(Icons.person, color: _workerGreen, size: 48),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Worker',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _workerInk,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.verified, color: _workerGreen, size: 24),
                    SizedBox(width: 6),
                    Icon(Icons.location_on_outlined, color: _workerGreen),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Kurunegala District',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _workerMuted, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ratingBadge(),
        ],
      ),
    );
  }

  Widget _ratingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F1E8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, color: Color(0xFFFFB36D), size: 22),
          SizedBox(width: 4),
          Text(
            '4.8 (64)',
            style: TextStyle(
              color: _workerInk,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search Jobs',
        hintStyle: const TextStyle(
          color: Color(0xFF969690),
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(Icons.search, size: 34, color: _workerInk),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(34),
          borderSide: const BorderSide(color: _workerGreen, width: 1.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(34),
          borderSide: const BorderSide(color: _workerGreen, width: 2),
        ),
      ),
    );
  }

  Widget _myJobsButton() {
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _tab = 1;
          _myJobsOnly = true;
          _category = null;
          _selectedDate = null;
          _selectedEstate = null;
        });
        _reloadJobs();
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: _workerGreen,
        minimumSize: const Size.fromHeight(44),
        side: const BorderSide(color: _workerGreen, width: 1.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      child: const Text(
        'My Jobs',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _categoryShortcuts() {
    return Column(
      children: [
        _categoryTile('Nut Gatherer', Icons.eco, 'Nut Gatherer'),
        _categoryTile('Manual Worker', Icons.build, 'Manual'),
        _categoryTile('Machine Weeder', Icons.agriculture, 'Machine'),
      ],
    );
  }

  Widget _categoryTile(String label, IconData icon, String category) {
    final selected = _category == category;
    return GestureDetector(
      onTap: () => setState(() => _category = selected ? null : category),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: _workerGreen, width: 1.5)
              : Border.all(color: const Color(0xFFF0EBE1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFD8EEE1)
                    : const Color(0xFFF4F0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _workerGreen, size: 26),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: _workerInk,
                fontSize: 17,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calendarCard(List<WorkerJob> jobs) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final leading = firstDay.weekday - 1;
    final jobDays = jobs
        .where(
          (job) =>
              job.requiredDate.year == _month.year &&
              job.requiredDate.month == _month.month,
        )
        .map((job) => job.requiredDate.day)
        .toSet();
    final jobsByDay = <int, List<WorkerJob>>{};
    for (final job in jobs.where(
      (job) =>
          job.requiredDate.year == _month.year &&
          job.requiredDate.month == _month.month,
    )) {
      jobsByDay.putIfAbsent(job.requiredDate.day, () => []).add(job);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_months[_month.month - 1]}\n${_month.year}',
                  style: const TextStyle(
                    color: _workerInk,
                    fontSize: 21,
                    height: 1.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _calendarMonthButton(Icons.chevron_left, -1),
              const SizedBox(width: 8),
              _calendarMonthButton(Icons.chevron_right, 1),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        color: _workerMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
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
              final dayOffset = index - leading;
              final date = DateTime(_month.year, _month.month, dayOffset + 1);
              final isCurrentMonth = date.month == _month.month;
              final marked = isCurrentMonth && jobDays.contains(date.day);
              final dayJobs = isCurrentMonth ? jobsByDay[date.day] : null;
              final dayIcons = dayJobs == null
                  ? const <IconData>[]
                  : dayJobs
                      .map((job) => _calendarIconForCategory(job.category))
                      .toList();
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              final isFutureOrToday =
                  isCurrentMonth && !date.isBefore(todayDate);
              final isToday =
                  isCurrentMonth &&
                  today.year == date.year &&
                  today.month == date.month &&
                  today.day == date.day;

              return GestureDetector(
                onTap: isCurrentMonth
                    ? () {
                        setState(() {
                          _selectedDate = date;
                          _selectedEstate = null;
                          _tab = 1;
                          _myJobsOnly = false;
                          _category = null;
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: isFutureOrToday
                        ? const Color(0xFFD8EBDD)
                        : const Color(0xFFF1EFEA),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday
                        ? Border.all(color: _workerGreen, width: 1.5)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isCurrentMonth
                                ? _workerInk
                                : const Color(0xFF9A9A94),
                            fontSize: 13,
                            fontWeight: isToday || marked
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (marked)
                        Positioned(
                          top: 1,
                          right: 3,
                          child: _calendarStatusDot(dayJobs!),
                        ),
                      if (marked)
                        Positioned(
                          bottom: 3,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final icon in dayIcons)
                                Icon(
                                  icon,
                                  color: _workerGreen,
                                  size: 11,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Legend(color: Color(0xFFF0A315), label: 'Partially filled'),
              _Legend(color: _workerGreen, label: 'Fully filled'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarStatusDot(List<WorkerJob> jobs) {
    final fullyFilled = jobs.every(
      (job) =>
          job.workersNeeded > 0 &&
          job.confirmedWorkers >= job.workersNeeded,
    );
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: fullyFilled ? _workerGreen : const Color(0xFFF0A315),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _calendarMonthButton(IconData icon, int change) {
    return Container(
      width: 42,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEE8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => setState(
          () => _month = DateTime(_month.year, _month.month + change),
        ),
        icon: Icon(icon, color: _workerMuted, size: 22),
      ),
    );
  }

  IconData _calendarIconForCategory(String? category) {
    final value = (category ?? '').toLowerCase();
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

  Widget _calendarDetailsCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS',
            style: TextStyle(
              color: _workerMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _StatusDot(color: Color(0xFFF0A315), label: 'Partially Filled'),
              SizedBox(width: 20),
              _StatusDot(color: _workerGreen, label: 'Fully Filled'),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE7E2D9)),
          ),
          const Text(
            'CATEGORY / DAY TYPE',
            style: TextStyle(
              color: _workerMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: _CalendarTypeChip(
                  icon: Icons.eco,
                  label: 'Nut Gatherer',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _CalendarTypeChip(
                  icon: Icons.agriculture,
                  label: 'Machine Worker',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Expanded(
                child: _CalendarTypeChip(
                  icon: Icons.build,
                  label: 'Manual Worker',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _CalendarTypeChip(
                  icon: Icons.star_border,
                  label: 'Holiday',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _liveJobs(List<WorkerJob> jobs, {bool onlyApplied = false}) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = jobs.where((job) {
      final matchesSearch =
          query.isEmpty ||
          job.category.toLowerCase().contains(query) ||
          job.location.toLowerCase().contains(query);
      final matchesCategory =
          _category == null ||
          job.category.toLowerCase().contains(_category!.toLowerCase());
      final matchesApplied = !onlyApplied || job.applicationId != null;
      return matchesSearch && matchesCategory && matchesApplied;
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          onlyApplied ? 'My Jobs' : 'Available Jobs',
          style: const TextStyle(
            color: _workerInk,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const Text('No matching jobs available right now.')
        else
          for (final job in filtered) _jobCard(job),
      ],
    );
  }

  Widget _nearbyWorkPage() {
    return FutureBuilder<List<WorkerJob>>(
      future: _jobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final jobs = snapshot.data ?? const <WorkerJob>[];
        final date = _selectedDate;
        final selectedJobs = jobs.where((job) {
          final matchesDate =
              date == null ||
              (job.requiredDate.year == date.year &&
                  job.requiredDate.month == date.month &&
                  job.requiredDate.day == date.day);
          final matchesCategory =
              _category == null ||
              job.category.toLowerCase().contains(_category!.toLowerCase());
          return matchesDate &&
              matchesCategory &&
              (!_myJobsOnly || _isAcceptedJob(job));
        }).toList();
        final estateJobs = <String, List<WorkerJob>>{};
        for (final job in selectedJobs) {
          estateJobs.putIfAbsent(job.estateName, () => []).add(job);
        }
        final detailsJobs = _selectedEstate == null
            ? const <WorkerJob>[]
            : estateJobs[_selectedEstate] ?? const <WorkerJob>[];
        return RefreshIndicator(
          color: _workerGreen,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              if (_selectedEstate == null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _myJobsOnly ? 'My jobs' : 'Jobs for the\nDay',
                        style: TextStyle(
                          color: _workerInk,
                          fontSize: 38,
                          height: 1.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8F3DE),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _myJobsOnly
                            ? '${selectedJobs.length} jobs'
                            : '${selectedJobs.length} jobs\nnear you',
                        style: const TextStyle(
                          color: _workerGreen,
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _nearbyFilters(selectedJobs, allJobs: jobs),
                const SizedBox(height: 22),
                _distanceFilter(),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EstateJobsMapPage(
                        jobs: jobs,
                        radiusKm: _radiusKm ?? 20,
                        nearbyOnly: _radiusKm != null,
                      ),
                    ),
                  ),
                  child: _nearbyMap(),
                ),
                const SizedBox(height: 20),
              ],
              if (selectedJobs.isEmpty)
                _emptyJobsMessage()
              else if (_selectedEstate == null) ...[
                const SizedBox(height: 4),
                Text(
                  _myJobsOnly
                      ? 'Accepted jobs'
                      : _selectedDate == null
                      ? 'Estates near you'
                      : 'Jobs for ${_selectedDate!.day} '
                            '${_months[_selectedDate!.month - 1]}',
                  style: const TextStyle(
                    color: _workerMuted,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 14),
                for (final entry in estateJobs.entries)
                  _estateJobCard(entry.key, entry.value),
              ]
              else ...[
                _jobDetailsHeader(detailsJobs),
                const SizedBox(height: 16),
                for (final job in detailsJobs) _nearbyJobCard(job),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _handleBack,
                    style: FilledButton.styleFrom(
                      backgroundColor: _workerGreen,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Back to Dashboard',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  bool _isAcceptedJob(WorkerJob job) {
    return job.applicationStatus?.toLowerCase() == 'accepted';
  }

  Widget _nearbyFilters(
    List<WorkerJob> jobs, {
    List<WorkerJob>? allJobs,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _filterButton('All', selected: _category == null),
              _filterIcon(Icons.eco, 'Nut Gatherer'),
              _filterIcon(Icons.agriculture, 'Machine'),
              _filterIcon(Icons.build, 'Manual'),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _myJobsOnly = !_myJobsOnly;
                    _selectedDate = null;
                    _selectedEstate = null;
                  }),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _workerGreen,
                    side: const BorderSide(color: _workerGreen, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: Text(
                    _myJobsOnly ? 'All Jobs' : 'My Jobs',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.circle, size: 12, color: _workerGreen),
              const SizedBox(width: 8),
              Text(
                _selectedDate == null
                    ? 'View all estates across Sri Lanka'
                    : 'Jobs for ${_selectedDate!.day} '
                          '${_months[_selectedDate!.month - 1]}',
                style: const TextStyle(color: _workerMuted, fontSize: 14),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EstateJobsMapPage(
                      jobs: allJobs ?? jobs,
                      nearbyOnly: false,
                    ),
                  ),
                ),
                child: const Text(
                  'Open map',
                  style: TextStyle(
                    color: _workerGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _estateJobCard(String estateName, List<WorkerJob> jobs) {
    final firstJob = jobs.first;
    final initials = estateName
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0])
        .join()
        .toUpperCase();
    return GestureDetector(
      onTap: () => setState(() => _selectedEstate = estateName),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F0E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                initials.isEmpty ? 'ES' : initials,
                style: const TextStyle(
                  color: _workerGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estateName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _workerInk,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Owner: ${firstJob.estateOwnerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _workerMuted, fontSize: 15),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${jobs.length} job${jobs.length == 1 ? '' : 's'} available',
                    style: const TextStyle(
                      color: _workerGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: _workerGreen,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _category = null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _workerGreen : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _workerGreen, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _workerGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _filterIcon(IconData icon, String category) {
    return IconButton(
      onPressed: () => setState(() => _category = category),
      icon: Icon(
        icon,
        color: _category == category ? _workerGreen : _workerMuted,
        size: 28,
      ),
    );
  }

  Widget _distanceFilter() {
    const options = <int?>[2, 5, 10, 20, 30, null];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = options[index];
          final selected = value == _radiusKm;
          return ChoiceChip(
            label: Text(value == null ? 'ALL' : '${value} km'),
            selected: selected,
            selectedColor: _workerGreen,
            labelStyle: TextStyle(
              color: selected ? Colors.white : _workerInk,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) => setState(() => _radiusKm = value),
          );
        },
      ),
    );
  }

  Widget _nearbyMap() {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFD8F1E2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB4D9C0)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.location_on, color: _workerGreen, size: 54),
          ),
          Positioned(
            top: 18,
            left: 18,
            child: _mapLabel(
              _radiusKm == null ? 'All estates' : '${_radiusKm} km radius',
            ),
          ),
          Positioned(
            top: 18,
            right: 16,
            child: _mapLabel(
              AuthService.currentUser?.location?.trim().isNotEmpty == true
                  ? AuthService.currentUser!.location!.trim()
                  : 'Current location',
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _radiusKm == null
                    ? 'Showing all estates across Sri Lanka'
                    : 'Active Match Zone: 0 - ${_radiusKm} km',
                style: TextStyle(
                  color: _workerInk,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _workerInk, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _jobDetailsHeader(List<WorkerJob> jobs) {
    final firstJob = jobs.first;
    final words = firstJob.estateName.trim().split(RegExp(r'\s+'));
    final initials = words.isEmpty || words.first.isEmpty
        ? 'ES'
        : words.take(2).map((word) => word[0]).join().toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Job details',
          style: TextStyle(
            color: _workerInk,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F0E8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: _workerGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      firstJob.estateName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _workerInk,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Owner: ${firstJob.estateOwnerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _workerMuted, fontSize: 15),
                    ),
                  ],
                ),
              ),
              Icon(
                _calendarIconForCategory(firstJob.category),
                color: _workerGreen,
                size: 31,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '${firstJob.location}  ·  2.4 km away',
          style: const TextStyle(color: _workerMuted, fontSize: 16),
        ),
        const SizedBox(height: 5),
        Text(
          _formatJobDate(firstJob.requiredDate),
          style: const TextStyle(
            color: _workerGreen,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Available jobs',
                style: TextStyle(
                  color: _workerInk,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4EC),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '${jobs.length} jobs',
                style: const TextStyle(
                  color: _workerGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _nearbyJobCard(WorkerJob job) {
    final applied = job.applicationId != null;
    final accepted = job.applicationStatus?.toLowerCase() == 'accepted';
    final completed =
        job.status.toLowerCase() == 'completed' ||
        job.applicationStatus?.toLowerCase() == 'completed';
    final available = (job.workersNeeded - job.confirmedWorkers).clamp(
      0,
      job.workersNeeded,
    );
    final progress = job.workersNeeded == 0
        ? 0.0
        : (job.confirmedWorkers / job.workersNeeded).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.category,
                  style: const TextStyle(
                    color: _workerInk,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EC),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  completed
                      ? 'Completed'
                      : accepted
                      ? 'Accepted'
                      : applied
                      ? 'Applied'
                      : 'Open',
                  style: const TextStyle(
                    color: _workerGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _jobDescription(job.category),
            style: const TextStyle(color: _workerMuted, fontSize: 16, height: 1.35),
          ),
          const SizedBox(height: 10),
          Text(
            'Rs.${job.dailyRate.toStringAsFixed(0)} / day',
            style: const TextStyle(
              color: _workerGreen,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$available places available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _workerGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${job.confirmedWorkers} of ${job.workersNeeded} accepted',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _workerMuted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: _workerMuted,
                size: 15,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _formatJobDate(job.requiredDate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _workerMuted, fontSize: 14),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'Required: ${job.workersNeeded}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _workerMuted, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFEAF1EB),
              valueColor: const AlwaysStoppedAnimation<Color>(_workerGreen),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: completed
                  ? null
                  : accepted
                  ? null
                  : () => _apply(job),
              style: OutlinedButton.styleFrom(
                foregroundColor: _workerGreen,
                side: const BorderSide(color: _workerGreen, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: Text(
                completed
                    ? 'Completed'
                    : accepted
                    ? 'Accepted'
                    : 'Accept job',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!completed)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openNegotiation(job),
                icon: const Icon(Icons.arrow_forward, size: 20),
                label: const Text('Negotiate'),
                style: FilledButton.styleFrom(
                  backgroundColor: _workerGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
          if (!accepted && !completed) ...[
            const SizedBox(height: 12),
            const Text(
              'Apply to confirm this job.',
              style: TextStyle(color: _workerMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeclineMessage(WorkerJob job) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Decline is not available yet.')),
    );
  }

  Future<void> _openNegotiation(WorkerJob job) async {
    if (job.applicationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apply for this job before negotiating.')),
      );
      return;
    }
    try {
      final chatId = await DayJobChatService.openChat(job.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerChatPage(chatId: chatId),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  String _jobDescription(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('nut')) {
      return 'Gather fallen coconuts and sort them for collection.';
    }
    if (normalized.contains('machine')) {
      return 'Operate and assist with agricultural machinery work.';
    }
    return 'Help with general estate work, clearing and daily maintenance.';
  }

  String _formatJobDate(DateTime date) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = [
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
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _emptyJobsMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cardDecoration(),
      child: const Text(
        'No jobs found for this date.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _workerMuted, fontSize: 16),
      ),
    );
  }

  Widget _jobCard(WorkerJob job) {
    final applied = job.applicationId != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.category,
            style: const TextStyle(
              color: _workerInk,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Date: ${job.requiredDate.toLocal().toString().split(' ').first}'),
          Text('Location: ${job.location}'),
          Text('Daily rate: Rs. ${job.dailyRate.toStringAsFixed(0)}'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: applied ? null : () => _apply(job),
              style: FilledButton.styleFrom(
                backgroundColor: _workerGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(applied ? 'Application sent' : 'Apply for job'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notifications() {
    return FutureBuilder<List<AppNotification>>(
      future: ChatService.getNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? const <AppNotification>[];
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'No new alerts',
              style: TextStyle(color: _workerMuted, fontSize: 17),
            ),
          );
        }
        ChatService.markSeen(items);
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              tileColor: Colors.white,
              leading: const Icon(Icons.chat_bubble, color: _workerGreen),
              title: Text(item.title),
              subtitle: Text(item.body),
              trailing: const Icon(Icons.chevron_right),
              onTap: item.type == NotificationType.dayJobChat &&
                      item.dayJobChatId != null
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerChatPage(
                            chatId: item.dayJobChatId!,
                          ),
                        ),
                      );
                      if (mounted) _refreshNotificationCount();
                    }
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _profilePage() {
    final user = AuthService.currentUser;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 30),
        const CircleAvatar(
          radius: 52,
          backgroundColor: Color(0xFFE9E6DC),
          child: Icon(Icons.person, color: _workerGreen, size: 58),
        ),
        const SizedBox(height: 14),
        Center(
          child: Column(
            children: [
              Text(user?.name ?? 'Worker', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _editWorkerProfile,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit profile'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text(user?.phone ?? '', style: const TextStyle(color: _workerMuted))),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: Column(
            children: const [
              _WorkerProfileDetail(
                icon: Icons.badge_outlined,
                title: 'Worker type',
                value: 'Day Job Worker',
              ),
              Divider(height: 24),
              _WorkerProfileDetail(
                icon: Icons.work_outline,
                title: 'Work categories',
                value: 'Nut gathering, manual and machine work',
              ),
              Divider(height: 24),
              _WorkerProfileDetail(
                icon: Icons.check_circle_outline,
                title: 'Availability',
                value: 'Available for nearby jobs',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration(),
          child: const Row(
            children: [
              Expanded(
                child: _WorkerProfileStat(
                  value: '0',
                  label: 'Completed jobs',
                ),
              ),
              Expanded(
                child: _WorkerProfileStat(
                  value: 'New',
                  label: 'Worker rating',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => logOut(context),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }

  Future<void> _editWorkerProfile() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    final nameController = TextEditingController(text: user.name);
    final locationController = TextEditingController(text: user.location ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit worker details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: 'Location')),
            TextField(controller: TextEditingController(text: user.phone), readOnly: true, decoration: const InputDecoration(labelText: 'Phone')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await AuthService.updateProfile(name: nameController.text.trim(), location: locationController.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    locationController.dispose();
    if (saved == true && mounted) setState(() {});
  }

  void _showProfile() => setState(() => _tab = 3);

  Widget _bottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.grid_view_rounded, 'Dashboard', 0),
          _navItem(Icons.work_outline, 'Jobs', 1),
          _navItem(
            Icons.notifications_none,
            'Alerts',
            2,
            badge: _notificationCount,
          ),
          _navItem(Icons.account_circle_outlined, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label,
    int index, {
    int badge = 0,
  }) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tab = index;
          if (index == 1) {
            _myJobsOnly = false;
            _category = null;
          }
          if (index == 2) _notificationCount = 0;
        });
        if (index == 0 || index == 1) _reloadJobs();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text(badge > 99 ? '99+' : '$badge'),
            backgroundColor: Colors.red,
            child: Icon(
              icon,
              color: selected ? _workerGreen : _workerMuted,
              size: 29,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: selected ? _workerGreen : _workerMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(color: Color(0x10000000), blurRadius: 5, offset: Offset(0, 2)),
      ],
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
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _workerMuted, fontSize: 12)),
      ],
    );
  }
}

class _WorkerProfileDetail extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _WorkerProfileDetail({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _workerGreen, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _workerMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: _workerInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkerProfileStat extends StatelessWidget {
  final String value;
  final String label;

  const _WorkerProfileStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _workerGreen,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _workerMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _workerInk, fontSize: 12)),
      ],
    );
  }
}

class _CalendarTypeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CalendarTypeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F0E8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: _workerGreen, size: 15),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _workerInk,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ConfirmationInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _workerGreen, size: 32),
        const SizedBox(width: 18),
        Text(
          text,
          style: const TextStyle(
            color: _workerInk,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../services/owner_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'job_detail_page.dart';
import 'post_day_job_page.dart';

const _green = Color(0xFF246B45);
const _greenBright = Color(0xFF0B9B70);
const _background = Color(0xFFFCF9F3);
const _ink = Color(0xFF1D1D1D);
const _muted = Color(0xFF77716D);
const _line = Color(0xFFE8E1D7);

enum _JobsFilter { all, completed }

class ScheduledJobsPage extends StatefulWidget {
  final DateTime date;

  const ScheduledJobsPage({super.key, required this.date});

  @override
  State<ScheduledJobsPage> createState() => _ScheduledJobsPageState();
}

class _ScheduledJobsPageState extends State<ScheduledJobsPage> {
  late Future<List<DayJob>> _jobs;
  _JobsFilter _filter = _JobsFilter.all;

  static const _months = [
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
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _jobs = OwnerService.getDayJobs(widget.date);
  }

  DateTime get _selectedDate =>
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  bool get _isPast {
    final now = DateTime.now();
    return _selectedDate.isBefore(DateTime(now.year, now.month, now.day));
  }

  bool _isCompleted(DayJob job) =>
      _isPast || job.status.toUpperCase() == 'COMPLETED';

  Future<void> _refresh() async {
    final refreshed = OwnerService.getDayJobs(widget.date);
    setState(() => _jobs = refreshed);
    await refreshed;
  }

  Future<void> _openPostJob() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDayJobPage(requiredDate: widget.date),
      ),
    );
    if (added == true && mounted) await _refresh();
  }

  Future<void> _openDetails(DayJob job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailPage(job: job)),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 430,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _background,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: FutureBuilder<List<DayJob>>(
                    future: _jobs,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: _green),
                        );
                      }
                      if (snapshot.hasError) return _errorState();
                      return _content(snapshot.data ?? const <DayJob>[]);
                    },
                  ),
                ),
                const _JobsBottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(List<DayJob> jobs) {
    final completed = jobs.where(_isCompleted).toList();
    final visible = List<DayJob>.from(
      _filter == _JobsFilter.completed ? completed : jobs,
    )..sort((a, b) => a.category.compareTo(b.category));
    return RefreshIndicator(
      color: _green,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          _header(jobs),
          const SizedBox(height: 20),
          _summary(jobs),
          if (!_isPast) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _openPostJob,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Job for This Date'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _filters(jobs.length, completed.length),
          const SizedBox(height: 24),
          Row(
            children: [
              Flexible(
                child: Text(
                  _filter == _JobsFilter.completed
                      ? 'COMPLETED JOBS'
                      : 'ALL JOBS',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              _countBubble(visible.length),
              const Spacer(),
              const Text(
                'Sorted by job name',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            _emptyState()
          else
            for (final job in visible) ...[
              _jobCard(job),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _header(List<DayJob> jobs) {
    final location = jobs.isEmpty ? 'Estate operations' : jobs.first.location;
    return Row(
      children: [
        Material(
          color: Colors.white,
          elevation: 1,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(18),
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.arrow_back, color: _ink, size: 28),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Job Details',
                style: TextStyle(
                  color: _ink,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _muted, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summary(List<DayJob> jobs) {
    final required = jobs.fold<int>(0, (sum, job) => sum + job.workersNeeded);
    final confirmed = jobs.fold<int>(
      0,
      (sum, job) => sum + job.confirmedWorkers,
    );
    final completed = jobs.where(_isCompleted).length;
    final status = jobs.isEmpty
        ? 'No Jobs'
        : completed == jobs.length
        ? 'Completed'
        : confirmed >= required
        ? 'Fulfilled'
        : 'Open';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6EF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFC8E8D5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: _green,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'SCHEDULED DAY JOBS',
                      style: TextStyle(
                        color: _green,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'ID: #DJ-${widget.date.year}'
                '${widget.date.month.toString().padLeft(2, '0')}'
                '${widget.date.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${_weekdays[widget.date.weekday - 1]}, '
            '${widget.date.day.toString().padLeft(2, '0')} '
            '${_months[widget.date.month - 1]} ${widget.date.year}',
            style: const TextStyle(
              color: _ink,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _line),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'ASSIGNMENTS',
                  '${jobs.length} ${jobs.length == 1 ? 'Job' : 'Jobs'}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _summaryItem('SHIFT', 'Full Day')),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryItem('DAY STATUS', status, highlighted: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, {bool highlighted = false}) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFEEFBF4) : const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(18),
        border: highlighted ? Border.all(color: const Color(0xFFB5EFD1)) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              color: highlighted ? _greenBright : const Color(0xFFAAA5A0),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: highlighted ? _green : _ink,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(int allCount, int completedCount) {
    return Row(
      children: [
        _filterButton(_JobsFilter.all, 'All ($allCount)'),
        const SizedBox(width: 10),
        _filterButton(_JobsFilter.completed, 'Completed ($completedCount)'),
      ],
    );
  }

  Widget _filterButton(_JobsFilter value, String label) {
    final selected = _filter == value;
    return OutlinedButton(
      onPressed: () => setState(() => _filter = value),
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? _green : Colors.white,
        foregroundColor: selected ? Colors.white : _muted,
        side: BorderSide(color: selected ? _green : _line),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _jobCard(DayJob job) {
    final completed = _isCompleted(job);
    final required = job.workersNeeded;
    final confirmed = job.confirmedWorkers.clamp(0, required);
    final progress = required == 0 ? 0.0 : confirmed / required;
    final percentage = (progress * 100).round();
    final status = completed
        ? 'Completed'
        : confirmed >= required
        ? 'Fulfilled'
        : confirmed > 0
        ? 'Partially Filled'
        : 'Open';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF19BE88),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(26),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            job.category,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _statusPill(status),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, color: _green),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Day job (8 hrs)',
                              style: TextStyle(color: _ink),
                            ),
                          ),
                          const Icon(Icons.payments_outlined, color: _green),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Rs. ${job.dailyRate.toStringAsFixed(0)} / day',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups,
                          color: Color(0xFFAAA5A0),
                          size: 22,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '$confirmed / $required Workers Confirmed',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '$percentage% Staffed',
                          style: const TextStyle(
                            color: _greenBright,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        color: _green,
                        backgroundColor: const Color(0xFFE9E5DD),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _openDetails(job),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('View Details'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEFBF4),
                          foregroundColor: _green,
                          side: const BorderSide(color: Color(0xFF9BE9C5)),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
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

  Widget _statusPill(String status) {
    final positive = status == 'Completed' || status == 'Fulfilled';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: positive ? const Color(0xFFD4F8E5) : const Color(0xFFFFE7D5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: positive ? const Color(0xFF92E8BA) : const Color(0xFFF4C19B),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.check_circle : Icons.schedule,
            color: positive ? _greenBright : const Color(0xFF9A5725),
            size: 17,
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: positive ? _green : const Color(0xFF7B431B),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countBubble(int count) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFECEAE6),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          const Icon(Icons.work_outline, color: _green, size: 48),
          const SizedBox(height: 10),
          Text(
            _filter == _JobsFilter.completed
                ? 'No completed jobs for this date.'
                : 'No jobs posted for this date.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_outlined, color: _muted, size: 52),
        const SizedBox(height: 12),
        const Text(
          'Could not load scheduled jobs.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: _refresh, child: const Text('Try again')),
      ],
    );
  }
}

class _JobsBottomNavigation extends StatelessWidget {
  const _JobsBottomNavigation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          _item(
            Icons.dashboard_outlined,
            'Dashboard',
            () => openTab(context, AppTab.dashboard),
          ),
          _item(Icons.calendar_month, 'Calendar', null, active: true),
          _item(
            Icons.receipt_long_outlined,
            'Orders',
            () => openTab(context, AppTab.orders),
          ),
          _item(
            Icons.notifications_none,
            'Alerts',
            () => openTab(context, AppTab.alerts),
          ),
          _item(
            Icons.person_outline,
            'Profile',
            () => openTab(context, AppTab.profile),
          ),
        ],
      ),
    );
  }

  Widget _item(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    final color = active ? _green : const Color(0xFF77716D);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFDDEEE0) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

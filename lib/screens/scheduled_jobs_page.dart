import 'package:flutter/material.dart';
import '../services/owner_service.dart';
import '../widgets/owner_widgets.dart';
import 'job_detail_page.dart';
import 'post_day_job_page.dart';

const _green = kOwnerGreen;
const _greenBright = Color(0xFF0B9B70);
const _ink = kOwnerInk;
const _muted = kOwnerMuted;
const _line = kOwnerBorder;

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

  bool _isFullyStaffed(DayJob job) =>
      job.workersNeeded > 0 && job.confirmedWorkers >= job.workersNeeded;

  bool _isCompleted(DayJob job) => job.status.toUpperCase() == 'COMPLETED';

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
    return OwnerPage(
      child: FutureBuilder<List<DayJob>>(
        future: _jobs,
        builder: (context, snapshot) {
          final jobs = snapshot.data ?? const <DayJob>[];
          return Column(
            children: [
              _header(jobs),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: CircularProgressIndicator(color: _green),
                      )
                    : snapshot.hasError
                    ? _errorState()
                    : _content(jobs),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(List<DayJob> jobs) {
    final completed = jobs.where(_isCompleted).toList();
    final visible = List<DayJob>.from(
      _isPast && _filter == _JobsFilter.completed ? completed : jobs,
    )..sort((a, b) => a.category.compareTo(b.category));
    return RefreshIndicator(
      color: _green,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          _summary(jobs),
          if (!_isPast) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _openPostJob,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Job for This Date'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _filters(jobs.length, completed.length),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                child: Text(
                  _isPast && _filter == _JobsFilter.completed
                      ? 'COMPLETED JOBS'
                      : 'ALL JOBS',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              _countBubble(visible.length),
            ],
          ),
          const SizedBox(height: 8),
          if (visible.isEmpty)
            _emptyState()
          else
            for (final job in visible) ...[
              _jobCard(job),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _header(List<DayJob> jobs) {
    final location = jobs.isEmpty ? 'Estate operations' : jobs.first.location;
    return OwnerHeader(title: 'Job Details', subtitle: location);
  }

  Widget _summary(List<DayJob> jobs) {
    final required = jobs.fold<int>(0, (sum, job) => sum + job.workersNeeded);
    final confirmed = jobs.fold<int>(
      0,
      (sum, job) =>
          sum + job.confirmedWorkers.clamp(0, job.workersNeeded).toInt(),
    );
    final vacancies = (required - confirmed).clamp(0, required).toInt();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6EF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFC8E8D5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: _green,
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SCHEDULED DAY JOBS',
                      style: TextStyle(
                        color: _green,
                        fontSize: 11,
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
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${_weekdays[widget.date.weekday - 1]}, '
            '${widget.date.day.toString().padLeft(2, '0')} '
            '${_months[widget.date.month - 1]} ${widget.date.year}',
            style: const TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  label: 'Total Jobs',
                  value: jobs.length,
                  icon: Icons.assignment_outlined,
                  background: const Color(0xFFF5F2EC),
                  foreground: _ink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryMetric(
                  label: 'Required',
                  value: required,
                  icon: Icons.groups_outlined,
                  background: const Color(0xFFF5F2EC),
                  foreground: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  label: 'Confirmed',
                  value: confirmed,
                  icon: Icons.how_to_reg_outlined,
                  background: const Color(0xFFEAF8EF),
                  foreground: _green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryMetric(
                  label: 'Vacancies',
                  value: vacancies,
                  icon: Icons.person_search_outlined,
                  background: const Color(0xFFFFF0E6),
                  foreground: const Color(0xFFA95828),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required String label,
    required int value,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      height: 58,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: foreground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Icon(icon, color: foreground.withValues(alpha: 0.65), size: 17),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters(int allCount, int completedCount) {
    return Row(
      children: [
        _filterButton(_JobsFilter.all, 'All ($allCount)'),
        if (_isPast) ...[
          const SizedBox(width: 10),
          _filterButton(_JobsFilter.completed, 'Completed ($completedCount)'),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _jobCard(DayJob job) {
    final completed = _isCompleted(job);
    final awaiting = job.status.toUpperCase() == 'AWAITING_WORKER_ACK';
    final awaitingOwner = job.status.toUpperCase() == 'AWAITING_OWNER_ACK';
    final fullyStaffed = _isFullyStaffed(job);
    final required = job.workersNeeded;
    final confirmed = job.confirmedWorkers.clamp(0, required);
    final progress = required == 0 ? 0.0 : confirmed / required;
    final status = completed
        ? 'Completed'
        : awaiting
        ? 'Awaiting worker'
        : awaitingOwner
        ? 'Worker completed'
        : fullyStaffed
        ? 'Fulfilled'
        : 'Open';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _statusPill(status),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EF),
                        borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups,
                          color: Color(0xFFAAA5A0),
                          size: 19,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$confirmed / $required Workers Confirmed',
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: _green,
                        backgroundColor: const Color(0xFFE9E5DD),
                      ),
                    ),
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: awaitingOwner
                          ? FilledButton.icon(
                              onPressed: () => _openDetails(job),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Review & Complete'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFD9A441),
                                foregroundColor: Colors.white,
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _openDetails(job),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('View Details'),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFEEFBF4),
                                foregroundColor: _green,
                                side: const BorderSide(color: Color(0xFF9BE9C5)),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
    final isAwaitingOwner = status == 'Worker completed';
    final bg = isAwaitingOwner
        ? const Color(0xFFFFF3D8)
        : positive
        ? const Color(0xFFD4F8E5)
        : const Color(0xFFFFE7D5);
    final border = isAwaitingOwner
        ? const Color(0xFFE7B64C)
        : positive
        ? const Color(0xFF92E8BA)
        : const Color(0xFFF4C19B);
    final fg = isAwaitingOwner
        ? const Color(0xFF845800)
        : positive
        ? _green
        : const Color(0xFF7B431B);
    final iconColor = isAwaitingOwner
        ? const Color(0xFFD9A441)
        : positive
        ? _greenBright
        : const Color(0xFF9A5725);
    final iconData = isAwaitingOwner
        ? Icons.fact_check_outlined
        : positive
        ? Icons.check_circle
        : Icons.schedule;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: iconColor, size: 15),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              color: fg,
              fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          const Icon(Icons.work_outline, color: _green, size: 48),
          const SizedBox(height: 10),
          Text(
            _isPast && _filter == _JobsFilter.completed
                ? 'No completed jobs for this date.'
                : 'No jobs posted for this date.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13),
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

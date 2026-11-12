import 'package:flutter/material.dart';
import 'job_detail_page.dart';
import 'post_day_job_page.dart';
import '../services/owner_service.dart';

const Color _scheduledGreen = Color(0xFF2A704E);
const Color _scheduledBackground = Color(0xFFFCF9F3);
const Color _scheduledInk = Color(0xFF1D1D1D);

class ScheduledJobsPage extends StatefulWidget {
  final DateTime date;

  const ScheduledJobsPage({super.key, required this.date});

  @override
  State<ScheduledJobsPage> createState() => _ScheduledJobsPageState();
}

class _ScheduledJobsPageState extends State<ScheduledJobsPage> {
  late Future<List<DayJob>> _jobs;

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

  @override
  void initState() {
    super.initState();
    _jobs = OwnerService.getDayJobs(widget.date);
  }

  Future<void> _openPostJob() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDayJobPage(requiredDate: widget.date),
      ),
    );
    if (added == true && mounted) {
      setState(() {
        _jobs = OwnerService.getDayJobs(widget.date);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
    );
    final isPast = selectedDate.isBefore(todayDate);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 390,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _scheduledBackground,
          child: SafeArea(
            child: FutureBuilder<List<DayJob>>(
              future: _jobs,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load jobs: ${snapshot.error}'),
                  );
                }
                final jobs = snapshot.data ?? const <DayJob>[];
                return isPast
                    ? _pastJobs(context, jobs)
                    : _upcomingJobs(context, jobs);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _pastJobs(BuildContext context, List<DayJob> jobs) {
    return Column(
      children: [
        _header(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _dateBanner(),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'ALL JOBS (${jobs.length})',
                  style: TextStyle(
                    color: _scheduledInk,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No jobs posted for this date.'),
                ),
              for (final job in jobs)
                _jobCard(
                  context,
                  job: job,
                  title: job.category,
                  time: 'Day job',
                  rate: 'Rs. ${job.dailyRate.toStringAsFixed(0)}',
                  workers:
                      '${job.confirmedWorkers} / ${job.workersNeeded} Workers Confirmed',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _upcomingJobs(BuildContext context, List<DayJob> jobs) {
    return Column(
      children: [
        _header(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _upcomingSummary(jobs),
              const SizedBox(height: 18),
              SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: _openPostJob,
                  icon: const Icon(Icons.add_circle_outline, size: 25),
                  label: const Text(
                    'Add Job for This Date',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _scheduledGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'ACTIVE ALLOCATIONS (${jobs.length})',
                  style: TextStyle(
                    color: _scheduledInk,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No jobs posted for this date.'),
                ),
              for (final job in jobs)
                _allocationCard(
                  context,
                  job: job,
                  title: job.category,
                  status: job.confirmedWorkers >= job.workersNeeded
                      ? 'Fully Filled'
                      : job.confirmedWorkers > 0
                      ? 'Partially Filled'
                      : 'Open',
                  confirmed: job.confirmedWorkers,
                  required: job.workersNeeded,
                  time: 'Day job',
                  rate: 'Rs. ${job.dailyRate.toStringAsFixed(0)}',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _upcomingSummary(List<DayJob> jobs) {
    final requiredWorkers = jobs.fold<int>(
      0,
      (total, job) => total + job.workersNeeded,
    );
    final confirmedWorkers = jobs.fold<int>(
      0,
      (total, job) => total + job.confirmedWorkers,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: _scheduledGreen),
              SizedBox(width: 12),
              Text(
                'SCHEDULED DAY JOBS',
                style: TextStyle(
                  color: _scheduledGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _fullDateLabel(),
            style: const TextStyle(
              color: _scheduledInk,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _summaryTile(
                'Total Jobs',
                '${jobs.length}',
                Icons.assignment_outlined,
              ),
              const SizedBox(width: 12),
                _summaryTile(
                  'Required',
                  '$requiredWorkers',
                  Icons.groups_outlined,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _summaryTile(
                'Confirmed',
                '$confirmedWorkers',
                Icons.person_add_alt_1_outlined,
                color: const Color(0xFFE0F8E8),
                textColor: _scheduledGreen,
              ),
              const SizedBox(width: 12),
              _summaryTile(
                'Vacancies',
                '${requiredWorkers - confirmedWorkers}',
                Icons.person_search_outlined,
                color: const Color(0xFFFFEEE4),
                textColor: const Color(0xFF985621),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(
    String label,
    String value,
    IconData icon, {
    Color color = const Color(0xFFF7F3ED),
    Color textColor = _scheduledInk,
  }) {
    return Expanded(
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: textColor, fontSize: 16)),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Icon(icon, color: textColor.withAlpha(100), size: 25),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allocationCard(
    BuildContext context, {
    required DayJob job,
    required String title,
    required String status,
    required int confirmed,
    required int required,
    required String time,
    required String rate,
  }) {
    final progress = required == 0 ? 0.0 : confirmed / required;
    final statusColor = status == 'Fully Filled'
        ? const Color(0xFFA8EDC5)
        : status == 'Partially Filled'
        ? const Color(0xFFFFDCC8)
        : const Color(0xFFE9E6DF);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: _scheduledInk, fontSize: 22),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: _scheduledInk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _detailLabel(Icons.access_time, time),
              _detailLabel(Icons.payments_outlined, '$rate / day'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                '$confirmed / $required Workers Confirmed',
                style: const TextStyle(
                  color: _scheduledInk,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${required - confirmed} Vacancies left',
                style: const TextStyle(color: Color(0xFF985621)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFEDEAE4),
              color: const Color(0xFF985621),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobDetailPage(job: job),
                ),
              ),
              icon: const Icon(Icons.arrow_forward, size: 22),
              label: const Text('View Details'),
              style: TextButton.styleFrom(
                foregroundColor: _scheduledGreen,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailLabel(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: _scheduledGreen, size: 23),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF526159), fontSize: 15),
        ),
      ],
    );
  }

  String _fullDateLabel() {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[widget.date.weekday - 1]}, ${widget.date.day.toString().padLeft(2, '0')} '
        '${_months[widget.date.month - 1].substring(0, 3)} ${widget.date.year}';
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 32, color: _scheduledInk),
          ),
          const SizedBox(width: 4),
          const Text(
            'Job Details',
            style: TextStyle(
              color: _scheduledInk,
              fontSize: 27,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const CircleAvatar(
            radius: 30,
            backgroundColor: _scheduledGreen,
            child: Icon(Icons.person_outline, color: Colors.white, size: 31),
          ),
        ],
      ),
    );
  }

  Widget _dateBanner() {
    final weekday = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][widget.date.weekday - 1];
    final month = [
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
    ][widget.date.month - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(44, 26, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: _scheduledGreen),
              SizedBox(width: 12),
              Text(
                'SCHEDULED DAY JOBS',
                style: TextStyle(
                  color: _scheduledGreen,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$weekday, ${widget.date.day.toString().padLeft(2, '0')} '
            '${month.substring(0, 3)} ${widget.date.year}',
            style: const TextStyle(
              color: _scheduledInk,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _jobCard(
    BuildContext context, {
    required DayJob job,
    required String title,
    required String time,
    required String rate,
    required String workers,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _scheduledInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const _CompletedPill(),
            ],
          ),
          const SizedBox(height: 30),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    color: _scheduledGreen,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Color(0xFF526159),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.payments_outlined,
                    color: _scheduledGreen,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$rate / day',
                    style: const TextStyle(
                      color: _scheduledInk,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            workers,
            style: const TextStyle(
              color: _scheduledInk,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JobDetailPage(job: job),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: _scheduledGreen,
                padding: EdgeInsets.zero,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: _scheduledGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedPill extends StatelessWidget {
  const _CompletedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFA8EDC5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Text(
        'Completed',
        style: TextStyle(
          color: Color(0xFF17633D),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

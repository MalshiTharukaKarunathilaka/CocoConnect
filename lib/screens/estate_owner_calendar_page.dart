import 'dart:async';
import '../widgets/role_navigation_page.dart';
import '../widgets/language_selector.dart';
import 'package:flutter/material.dart';
import '../services/owner_service.dart';
import '../services/holiday_service.dart';
import '../widgets/holiday_widgets.dart';
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
  String? _categoryFilter;
  Timer? _pollTimer;
  final Set<int> _shownCompletionAcknowledgements = <int>{};

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

  @override
  void initState() {
    super.initState();
    _loadPostedJobs();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _loadPostedJobs();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }


  Future<void> _loadPostedJobs() async {
    try {
      final jobs = await OwnerService.getDayJobs();
      if (mounted) {
        setState(() => _postedJobs = jobs);
        _scheduleCompletionAcknowledgement(jobs);
      }
    } catch (error) {
      debugPrint('Could not load posted jobs for calendar: $error');
    }
  }

  void _scheduleCompletionAcknowledgement(List<DayJob> jobs) {
    DayJob? pending;
    for (final job in jobs) {
      if (job.status.toUpperCase() == 'AWAITING_OWNER_ACK' &&
          !_shownCompletionAcknowledgements.contains(job.id)) {
        pending = job;
        break;
      }
    }
    if (pending == null) return;
    _shownCompletionAcknowledgements.add(pending.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showCompletionAcknowledgement(pending!);
    });
  }

  Future<void> _showCompletionAcknowledgement(DayJob job) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          backgroundColor: const Color(0xFFFCF8EF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: _calendarGreen),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Job completion acknowledgement',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _calendarInk,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF718096)),
                onPressed: () => Navigator.pop(dialogContext),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE7B64C)),
                ),
                child: Text(
                  '${job.requiredDate.day.toString().padLeft(2, '0')}/'
                  '${job.requiredDate.month.toString().padLeft(2, '0')}/'
                  '${job.requiredDate.year}',
                  style: const TextStyle(
                    color: Color(0xFF845800),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A worker has marked their work as finished on this day job. '
                'Please confirm that the job is complete.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 12),
              _ackDetail('Category', job.category),
              _ackDetail('Location', job.location),
              _ackDetail(
                'Workers',
                '${job.confirmedWorkers} of ${job.workersNeeded} confirmed',
              ),
              _ackDetail(
                'Daily Rate',
                'Rs. ${job.dailyRate.toStringAsFixed(0)} · ${job.paymentMethod}',
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          actions: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showCancelCompletionDialog(job);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA32820),
                        side: const BorderSide(color: Color(0xFFA32820), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _showRateWorkerCompletionDialog(job);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _calendarGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRateWorkerCompletionDialog(DayJob job) async {
    if (!mounted) return;
    int selectedRating = 5;
    bool submitting = false;
    final workerName = job.acceptedWorkers.isNotEmpty
        ? job.acceptedWorkers.first.name
        : 'Worker';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final ratingLabels = {
            1: 'Poor',
            2: 'Fair',
            3: 'Good',
            4: 'Very Good',
            5: 'Excellent',
          };

          return AlertDialog(
            scrollable: true,
            backgroundColor: const Color(0xFFFCF8EF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.star, color: Color(0xFFFFB300)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rate Worker Performance',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _calendarInk,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Confirm completion of ${job.category} by rating $workerName.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int star = 1; star <= 5; star++)
                      IconButton(
                        onPressed: submitting
                            ? null
                            : () => setDialogState(() => selectedRating = star),
                        icon: Icon(
                          star <= selectedRating ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFFB300),
                          size: 38,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$selectedRating / 5 · ${ratingLabels[selectedRating] ?? ''}',
                  style: const TextStyle(
                    color: _calendarGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: submitting
                            ? null
                            : () {
                                Navigator.pop(dialogContext);
                                _showCompletionAcknowledgement(job);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                setDialogState(() => submitting = true);
                                try {
                                  await OwnerService.completeDayJob(
                                    job.id,
                                    rating: selectedRating,
                                  );
                                  if (!mounted) return;
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  _loadPostedJobs();
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Job confirmed and worker rating submitted! Deal finished.',
                                      ),
                                    ),
                                  );
                                } on ApiException catch (error) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(content: Text(error.message)),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setDialogState(() => submitting = false);
                                  }
                                }
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(submitting ? 'Saving…' : 'Submit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _calendarGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCancelCompletionDialog(DayJob job) async {
    if (!mounted) return;
    const reasons = [
      'Work not finished yet',
      'Incomplete or poor quality work',
      'Workers left early / did not show up',
      'Payment or working hours dispute',
      'Other',
    ];
    String selectedReason = reasons.first;
    final noteController = TextEditingController();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            backgroundColor: const Color(0xFFFCF8EF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: Color(0xFFA32820)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cancel Job Completion',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _calendarInk,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select why you are not confirming completion:',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                for (final reason in reasons)
                  InkWell(
                    onTap: submitting
                        ? null
                        : () => setDialogState(() => selectedReason = reason),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            selectedReason == reason
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: selectedReason == reason
                                ? const Color(0xFFA32820)
                                : const Color(0xFFCBD5E1),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: selectedReason == reason
                                    ? _calendarInk
                                    : const Color(0xFF4A5568),
                                fontWeight: selectedReason == reason
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Optional note:',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  enabled: !submitting,
                  decoration: InputDecoration(
                    hintText: 'Add comments or instructions for the worker...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFFA0AEC0)),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFA32820), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: submitting
                            ? null
                            : () {
                                Navigator.pop(dialogContext);
                                _showCompletionAcknowledgement(job);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                setDialogState(() => submitting = true);
                                try {
                                  await OwnerService.cancelDayJobCompletion(
                                    jobId: job.id,
                                    reason: selectedReason,
                                    note: noteController.text,
                                  );
                                  if (!mounted) return;
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  _loadPostedJobs();
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Job completion cancelled. Reason recorded.',
                                      ),
                                    ),
                                  );
                                } on ApiException catch (error) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(content: Text(error.message)),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setDialogState(() => submitting = false);
                                  }
                                }
                              },
                        icon: submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.close, size: 18),
                        label: Text(submitting ? 'Submitting…' : 'Submit Cancel'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFA32820),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ackDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _calendarInk,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completionAcknowledgementBanner(List<DayJob> jobs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3D8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7B64C)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFE3A3),
            foregroundColor: Color(0xFF845800),
            child: Icon(Icons.fact_check_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${jobs.length} completion ${jobs.length == 1 ? 'acknowledgement' : 'acknowledgements'}',
                  style: const TextStyle(
                    color: _calendarInk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Worker marked job as completed. Review and confirm.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Review acknowledgement',
            onPressed: () => _showCompletionAcknowledgement(jobs.first),
            icon: const Icon(Icons.arrow_forward, color: _calendarGreen),
          ),
        ],
      ),
    );
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
    final pendingAckJob = _postedJobs.where((job) {
      return job.requiredDate.year == selectedDate.year &&
          job.requiredDate.month == selectedDate.month &&
          job.requiredDate.day == selectedDate.day &&
          job.status.toUpperCase() == 'AWAITING_OWNER_ACK';
    }).firstOrNull;

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
        pendingAckJob: pendingAckJob,
        onAcknowledge: pendingAckJob != null
            ? () {
                _showCompletionAcknowledgement(pendingAckJob);
              }
            : null,
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
          ).then((_) => _loadPostedJobs());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactMobile = MediaQuery.sizeOf(context).height <= 850;
    return RoleNavigationPage(
      chatScope: ChatScope.dayJobs,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        body: Center(
          child: Container(
            width: 390,
            constraints: const BoxConstraints(maxWidth: 430),
            color: _calendarBackground,
            child: SafeArea(
              child: Column(
                children: [
                  _header(compact: compactMobile),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        compactMobile ? 0 : 10,
                        14,
                        18,
                      ),
                      children: [
                        if (_postedJobs.any(
                          (job) =>
                              job.status.toUpperCase() == 'AWAITING_OWNER_ACK',
                        )) ...[
                          _completionAcknowledgementBanner(
                            _postedJobs
                                .where(
                                  (job) =>
                                      job.status.toUpperCase() ==
                                      'AWAITING_OWNER_ACK',
                                )
                                .toList(),
                          ),
                          SizedBox(height: compactMobile ? 4 : 8),
                        ],
                        _categoryCard(compact: compactMobile),
                        SizedBox(height: compactMobile ? 5 : 12),
                        HolidayListener(
                          years: [_month.year],
                          builder: (_) => _calendarCard(
                            compact: compactMobile,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header({required bool compact}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, compact ? 2 : 12, 12, compact ? 0 : 4),
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
          const LanguageSelector(),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

  Widget _calendarCard({required bool compact}) {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingDays = firstDay.weekday - 1;
    final calendarCellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 12 : 20,
        16,
        compact ? 10 : 16,
      ),
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
          SizedBox(height: compact ? 10 : 20),
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
          SizedBox(height: compact ? 6 : 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calendarCellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - leadingDays;
              final day = dayOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              return _dayCell(day);
            },
          ),
          SizedBox(height: compact ? 8 : 16),
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

  Widget _categoryCard({required bool compact}) {
    final chips = <Widget>[
      _CategoryChip(
        Icons.eco,
        'Nut Gatherer',
        compact: compact,
        selected: _categoryFilter == 'Nut Gatherer',
        onTap: () => _toggleCategoryFilter('Nut Gatherer'),
      ),
      _CategoryChip(
        Icons.agriculture,
        'Machine Weeder',
        compact: compact,
        selected: _categoryFilter == 'Machine Weeder',
        onTap: () => _toggleCategoryFilter('Machine Weeder'),
      ),
      _CategoryChip(
        Icons.build,
        'Manual Worker',
        compact: compact,
        selected: _categoryFilter == 'Manual Worker',
        onTap: () => _toggleCategoryFilter('Manual Worker'),
      ),
      _CategoryChip(
        Icons.star,
        'Holiday',
        compact: compact,
        iconColor: Colors.red,
        selected: _categoryFilter == 'Holiday',
        onTap: () => _toggleCategoryFilter('Holiday'),
      ),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        compact ? 8 : 18,
        compact ? 10 : 14,
        compact ? 8 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9E2D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATEGORY / DAY TYPE',
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: .5,
            ),
          ),
          SizedBox(height: compact ? 6 : 12),
          Wrap(
            spacing: compact ? 8 : 10,
            runSpacing: compact ? 5 : 10,
            children: chips,
          ),
          if (_categoryFilter != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Showing $_categoryFilter dates',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _categoryFilter = null),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(foregroundColor: _calendarGreen),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _toggleCategoryFilter(String category) {
    setState(() {
      _categoryFilter = _categoryFilter == category ? null : category;
    });
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

  Widget _dayCell(int day) {
    final DateTime cellDate = DateTime(_month.year, _month.month, day);
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final isPastDay = cellDate.isBefore(todayDate);
    final isTodayOrFuture = !isPastDay;
    final allJobsOnDay = _postedJobs.where((job) {
      return job.requiredDate.year == cellDate.year &&
          job.requiredDate.month == cellDate.month &&
          job.requiredDate.day == cellDate.day;
    }).toList();
    final jobsOnDay = _categoryFilter == null
        ? allJobsOnDay
        : _categoryFilter == 'Holiday'
        ? const <DayJob>[]
        : allJobsOnDay
              .where(
                (job) => _jobMatchesCategory(job.category, _categoryFilter!),
              )
              .toList();
    final selected =
        _selectedDay?.year == cellDate.year &&
        _selectedDay?.month == cellDate.month &&
        _selectedDay?.day == cellDate.day;
    final statusColor = jobsOnDay.isEmpty
        ? null
        : jobsOnDay.every((job) => job.confirmedWorkers >= job.workersNeeded)
        ? _calendarGreen
        : const Color(0xFFF0A315);
    final hasAwaitingAck = allJobsOnDay.any(
      (job) => job.status.toUpperCase() == 'AWAITING_OWNER_ACK',
    );
    final jobIcons = jobsOnDay
        .map((job) => _iconForJobCategory(job.category))
        .toSet()
        .toList();
    final isPoyaDay = HolidayService.of(cellDate) != null;
    final showHoliday =
        isPoyaDay && (_categoryFilter == null || _categoryFilter == 'Holiday');

    return GestureDetector(
      onTap: () => _selectDay(cellDate),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
        decoration: BoxDecoration(
          color: selected
              ? _calendarGreen
              : isTodayOrFuture
              ? const Color(0xFFBDD3C4)
              : const Color(0xFFEBE9E3),
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: const Color(0xFF0B9368), width: 2)
              : null,
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Text(
                '$day',
                style: TextStyle(
                  color: selected ? Colors.white : _calendarInk,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (hasAwaitingAck)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9A441),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              )
            else if (statusColor != null)
              Positioned(
                top: 1,
                right: 1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor == const Color(0xFFF0A315)
                        ? const Color(0xFFFFB318)
                        : selected
                        ? const Color(0xFF57D49B)
                        : const Color(0xFF07835F),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (showHoliday)
              const Positioned(
                bottom: 1,
                left: 0,
                child: Icon(Icons.star, size: 16, color: Colors.red),
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

  bool _jobMatchesCategory(String jobCategory, String filter) {
    final value = jobCategory.toLowerCase();
    return switch (filter) {
      'Nut Gatherer' => value.contains('nut') || value.contains('gather'),
      'Machine Weeder' => value.contains('machine') || value.contains('weeder'),
      'Manual Worker' =>
        value.contains('manual') ||
            (!value.contains('machine') &&
                !value.contains('weeder') &&
                !value.contains('nut') &&
                !value.contains('gather')),
      _ => false,
    };
  }
}

class _DayActionsSheet extends StatelessWidget {
  final DateTime date;
  final bool showScheduleActions;
  final DayJob? pendingAckJob;
  final VoidCallback? onAcknowledge;
  final VoidCallback onAddJob;
  final VoidCallback onViewJobs;

  const _DayActionsSheet({
    required this.date,
    required this.showScheduleActions,
    this.pendingAckJob,
    this.onAcknowledge,
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
            if (pendingAckJob != null) ...[
              _ActionButton(
                icon: Icons.check_circle_outline,
                label: 'Acknowledge Completion',
                backgroundColor: const Color(0xFFD9A441),
                foregroundColor: Colors.white,
                onTap: () {
                  Navigator.pop(context);
                  onAcknowledge?.call();
                },
              ),
              const SizedBox(height: 14),
            ],
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
  final Color iconColor;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _CategoryChip(
    this.icon,
    this.label, {
    this.iconColor = _calendarGreen,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filter calendar by $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 155,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFDDEEE0) : const Color(0xFFF4EFE6),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? _calendarGreen : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? _calendarGreen : _calendarInk,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 16, color: _calendarGreen),
            ],
          ),
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

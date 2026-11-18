import '../widgets/auto_filled_field.dart';
import '../widgets/language_selector.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/day_job_chat_service.dart';
import '../services/holiday_service.dart';
import '../services/worker_service.dart';
import '../widgets/profile_widgets.dart';
import '../widgets/buyer_widgets.dart';
import '../widgets/holiday_widgets.dart';
import 'worker_chat_page.dart';
import 'estate_jobs_map_page.dart';
import 'day_job_chats_list.dart';
import 'estate_owner_worker_profile_page.dart';

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
  late Future<WorkerProfileSummary> _profileSummary;
  WorkerProfileSummary? _profileCache;
  final _searchController = TextEditingController();
  int _tab = 0;
  bool _myJobsOnly = false;
  int _notificationCount = 0;
  int _chatCount = 0;
  Timer? _notificationTimer;
  String? _category;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDate;
  String? _selectedEstate;
  int? _radiusKm;
  int? _decliningJobId;
  int? _acknowledgingJobId;
  final Set<int> _shownCompletionAcknowledgements = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _jobs = WorkerService.getAvailableJobs();
    _profileSummary = _fetchProfile();
    _refreshNotificationCount();
    _refreshChatCount();
    _notificationTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshNotificationCount();
      _refreshChatCount();
      if (_tab == 0 || _tab == 1) _reloadJobs();
      if (_tab == 4) _reloadProfile();
    });
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
      _reloadProfile();
    }
  }

  void _reloadJobs() {
    if (!mounted) return;
    setState(() {
      _jobs = WorkerService.getAvailableJobs();
    });
  }

  void _reloadProfile() {
    if (!mounted) return;
    setState(() {
      _profileSummary = _fetchProfile();
    });
  }

  Future<WorkerProfileSummary> _fetchProfile() async {
    final profile = await WorkerService.getProfile();
    _profileCache = profile;
    if (mounted) setState(() {});
    return profile;
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

  Future<void> _refreshChatCount() async {
    try {
      final chats = await DayJobChatService.getChats();
      final count = chats.fold(0, (total, chat) => total + chat.unreadCount);
      if (mounted) setState(() => _chatCount = count);
    } on ApiException {
      // Keep the previous badge if chat refresh is temporarily unavailable.
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

      // Show the acknowledgement as soon as acceptance succeeds. A failure
      // while refreshing the jobs list must not hide the confirmation popup.
      await _showJobConfirmation(job);

      final refreshedJobs = WorkerService.getAvailableJobs();
      setState(() {
        _jobs = refreshedJobs;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.message.toLowerCase().contains('already accepted')) {
        await _showJobConfirmation(job);
        return;
      }
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Job confirmation',
                    style: TextStyle(
                      color: _workerInk,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 128,
                  height: 128,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE6F1E9),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(22),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _workerGreen,
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
                const Text(
                  'Job accepted!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _workerInk,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You’re confirmed for this job.\n'
                  'You can find it in My jobs anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _workerMuted,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
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
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _confirmationStatus('Confirmed'),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: Color(0xFFE9E2D9)),
                      ),
                      const _ConfirmationInfo(
                        icon: Icons.access_time,
                        text: 'Full day',
                      ),
                      const SizedBox(height: 12),
                      _ConfirmationInfo(
                        icon: Icons.payments_outlined,
                        text: 'Rs. ${job.dailyRate.toStringAsFixed(0)} / day',
                      ),
                      const SizedBox(height: 22),
                      _ConfirmationInfo(
                        icon: Icons.calendar_today_outlined,
                        text: _formatJobDate(job.requiredDate),
                      ),
                      if (job.location.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _ConfirmationInfo(
                          icon: Icons.location_on_outlined,
                          text: job.location,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 190,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: _workerGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(34),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
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
    final showBackButton =
        _tab != 0 ||
        _selectedDate != null ||
        _myJobsOnly ||
        _selectedEstate != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
      child: Row(
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: _handleBack,
              child: const Icon(Icons.arrow_back, size: 31, color: _workerInk),
            ),
            const SizedBox(width: 14),
          ],
          const Flexible(
            child: Text(
              'KapConnect',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _workerGreen,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          const Flexible(child: LanguageSelector()),
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
    if (_tab != 0) {
      setState(() => _tab = 0);
      _reloadJobs();
      return;
    }
    Navigator.maybePop(context);
  }

  Widget _content() {
    if (_tab == 2) {
      return DayJobChatsList(
        showTitle: true,
        onUnreadChanged: (count) {
          if (mounted && count != _chatCount) {
            setState(() => _chatCount = count);
          }
        },
      );
    }
    if (_tab == 3) {
      return _notifications();
    }
    if (_tab == 4) {
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
          _scheduleCompletionAcknowledgement(jobs);
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
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
      children: [
        if (error != null) _errorBanner(error),
        if (jobs.any((job) => job.needsCompletionAcknowledgement)) ...[
          _completionAcknowledgementBanner(
            jobs.where((job) => job.needsCompletionAcknowledgement).toList(),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(child: SizedBox(height: 48, child: _searchBox())),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 48, child: _myJobsButton())),
          ],
        ),
        const SizedBox(height: 16),
        _categoryShortcuts(),
        const SizedBox(height: 12),
        _calendarCard(jobs),
        const SizedBox(height: 10),
        _calendarDetailsCard(),
        const SizedBox(height: 22),
        _liveJobs(jobs, onlyApplied: _tab == 1),
      ],
    );
  }

  void _scheduleCompletionAcknowledgement(List<WorkerJob> jobs) {
    if (_tab != 0 && _tab != 1) return;
    WorkerJob? pending;
    for (final job in jobs) {
      if (job.needsCompletionAcknowledgement &&
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

  Widget _completionAcknowledgementBanner(List<WorkerJob> jobs) {
    return Container(
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
                    color: _workerInk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'The land owner marked work as finished. Review and confirm.',
                  style: TextStyle(color: _workerMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Review acknowledgement',
            onPressed: () => _showCompletionAcknowledgement(jobs.first),
            icon: const Icon(Icons.arrow_forward, color: _workerGreen),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompletionAcknowledgement(WorkerJob job) async {
    if (!mounted) return;
    var ratingStep = false;
    var selectedRating = 0;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final acknowledging = _acknowledgingJobId == job.id;
          return AlertDialog(
            scrollable: true,
            backgroundColor: _workerBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Icon(
                  ratingStep ? Icons.star_outline : Icons.fact_check_outlined,
                  color: _workerGreen,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ratingStep
                        ? 'Rate the land owner'
                        : 'Job completion acknowledgement',
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${job.requiredDate.day.toString().padLeft(2, '0')}/'
                  '${job.requiredDate.month.toString().padLeft(2, '0')}/'
                  '${job.requiredDate.year}',
                  style: const TextStyle(
                    color: _workerGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                _acknowledgementDetail('Job category', job.category),
                _acknowledgementDetail('Land', job.estateName),
                _acknowledgementDetail(
                  'Location',
                  job.estateLocation.isEmpty
                      ? job.location
                      : job.estateLocation,
                ),
                _acknowledgementDetail(
                  'Job details',
                  '${job.workersNeeded} ${job.workersNeeded == 1 ? 'worker' : 'workers'} · '
                      'Rs. ${job.dailyRate.toStringAsFixed(0)} / day · ${job.paymentMethod}',
                ),
                const SizedBox(height: 10),
                if (!ratingStep)
                  const Text(
                    'Confirm only if you completed this job. Next, rate the land owner to finish your acknowledgement.',
                    style: TextStyle(color: _workerMuted, height: 1.35),
                  )
                else ...[
                  const Text(
                    'How was your experience with this land owner?',
                    style: TextStyle(
                      color: _workerInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    runSpacing: 4,
                    children: [
                      for (var value = 1; value <= 5; value++)
                        IconButton(
                          tooltip: '$value star${value == 1 ? '' : 's'}',
                          onPressed: acknowledging
                              ? null
                              : () => setDialogState(
                                  () => selectedRating = value,
                                ),
                          icon: Icon(
                            value <= selectedRating
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFFFB300),
                            size: 34,
                          ),
                        ),
                    ],
                  ),
                  Center(
                    child: Text(
                      selectedRating == 0
                          ? 'Select a rating to continue'
                          : '$selectedRating out of 5',
                      style: const TextStyle(color: _workerMuted),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      acknowledging || (ratingStep && selectedRating == 0)
                      ? null
                      : () async {
                          if (!ratingStep) {
                            setDialogState(() => ratingStep = true);
                            return;
                          }
                          setState(() => _acknowledgingJobId = job.id);
                          setDialogState(() {});
                          try {
                            await WorkerService.acknowledgeJobCompletion(
                              jobId: job.id,
                              rating: selectedRating,
                            );
                            if (!mounted) return;
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _reloadJobs();
                            _reloadProfile();
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Job completed and land owner rating saved.',
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
                              setState(() => _acknowledgingJobId = null);
                            }
                          }
                        },
                  icon: acknowledging
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          ratingStep ? Icons.star : Icons.check_circle_outline,
                        ),
                  label: Text(
                    acknowledging
                        ? 'Saving...'
                        : ratingStep
                        ? 'Give rating & finish'
                        : 'Complete job',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _workerGreen,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _acknowledgementDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: _workerMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _workerInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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

  Widget _searchBox() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search Jobs',
        hintStyle: const TextStyle(
          color: Color(0xFF969690),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: const Icon(Icons.search, size: 26, color: _workerInk),
        suffixIcon: _searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
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
        minimumSize: const Size.fromHeight(40),
        side: const BorderSide(color: _workerGreen, width: 1.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      child: const Text(
        'My Jobs',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _categoryShortcuts() {
    return Row(
      children: [
        Expanded(
          child: _categoryTile('Nut Gatherer', Icons.eco, 'Nut Gatherer'),
        ),
        Expanded(child: _categoryTile('Manual Worker', Icons.build, 'Manual')),
        Expanded(
          child: _categoryTile('Machine Weeder', Icons.agriculture, 'Machine'),
        ),
      ],
    );
  }

  Widget _categoryTile(String label, IconData icon, String category) {
    final selected = _category == category;
    return GestureDetector(
      onTap: () => setState(() => _category = selected ? null : category),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _workerGreen : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _workerGreen : const Color(0xFFE4E1DC),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: selected ? Colors.white : _workerGreen, size: 20),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final word in label.split(' '))
                    Text(
                      word,
                      maxLines: 1,
                      style: TextStyle(
                        color: selected ? Colors.white : _workerInk,
                        fontSize: 11,
                        height: 1.05,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w600,
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

  Widget _calendarCard(List<WorkerJob> jobs) {
    return HolidayListener(
      years: [_month.year],
      builder: (_) => _calendarCardContent(jobs),
    );
  }

  Widget _calendarCardContent(List<WorkerJob> jobs) {
    final calendarJobs = _category == null
        ? jobs
        : jobs
              .where(
                (job) => job.category.toLowerCase().contains(
                  _category!.toLowerCase(),
                ),
              )
              .toList();
    final firstDay = DateTime(_month.year, _month.month, 1);
    final leading = firstDay.weekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final calendarCellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final jobDays = calendarJobs
        .where(
          (job) =>
              job.requiredDate.year == _month.year &&
              job.requiredDate.month == _month.month,
        )
        .map((job) => job.requiredDate.day)
        .toSet();
    final jobsByDay = <int, List<WorkerJob>>{};
    for (final job in calendarJobs.where(
      (job) =>
          job.requiredDate.year == _month.year &&
          job.requiredDate.month == _month.month,
    )) {
      jobsByDay.putIfAbsent(job.requiredDate.day, () => []).add(job);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: _cardDecoration(),
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
                        color: _workerInk,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_month.year}',
                      style: const TextStyle(
                        color: _workerInk,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _calendarMonthButton(Icons.chevron_left, -1),
              const SizedBox(width: 8),
              _calendarMonthButton(Icons.chevron_right, 1),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
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
            itemCount: calendarCellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - leading;
              final day = dayOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(_month.year, _month.month, day);
              final holiday = HolidayService.of(date);
              final marked = jobDays.contains(day);
              final dayJobs = jobsByDay[day];
              final dayIcons = dayJobs == null
                  ? const <IconData>[]
                  : dayJobs
                        .map((job) => _calendarIconForCategory(job.category))
                        .toList();
              final today = DateTime.now();
              final todayDate = DateTime(today.year, today.month, today.day);
              final isFutureOrToday = !date.isBefore(todayDate);
              final isToday =
                  today.year == date.year &&
                  today.month == date.month &&
                  today.day == date.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                    _selectedEstate = null;
                    _tab = 1;
                    _myJobsOnly = false;
                    _category = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                  decoration: BoxDecoration(
                    color: isFutureOrToday
                        ? const Color(0xFFD8EBDD)
                        : const Color(0xFFF1EFEA),
                    borderRadius: BorderRadius.circular(16),
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
                            color: _workerInk,
                            fontSize: 14,
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
                      if (marked || holiday != null)
                        Positioned(
                          bottom: 3,
                          left: 0,
                          right: 0,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (holiday != null)
                                  const HolidayFlag(size: 12),
                                if (holiday != null && dayIcons.isNotEmpty)
                                  const SizedBox(width: 2),
                                for (final icon in dayIcons)
                                  Icon(icon, color: _workerGreen, size: 11),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 18,
            runSpacing: 8,
            children: [
              _WorkerCalendarLegend(
                color: Color(0xFFF0A315),
                label: 'Partially filled',
              ),
              _WorkerCalendarLegend(color: _workerGreen, label: 'Fully filled'),
              HolidayLegend(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendarStatusDot(List<WorkerJob> jobs) {
    final fullyFilled = jobs.every(
      (job) =>
          job.workersNeeded > 0 && job.confirmedWorkers >= job.workersNeeded,
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEE8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: () => setState(
          () => _month = DateTime(_month.year, _month.month + change),
        ),
        icon: Icon(icon, color: const Color(0xFF68736B), size: 24),
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
            'CATEGORY / JOB TYPE',
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
                  label: 'Machine Weeder',
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
        _scheduleCompletionAcknowledgement(jobs);
        final date = _selectedDate;
        final selectedJobs = jobs.where((job) {
          if (_myJobsOnly) {
            return _isAcceptedJob(job);
          }
          final matchesDate =
              date == null ||
              (job.requiredDate.year == date.year &&
                  job.requiredDate.month == date.month &&
                  job.requiredDate.day == date.day);
          final matchesCategory =
              _category == null ||
              job.category.toLowerCase().contains(_category!.toLowerCase());
          final matchesRadius =
              _radiusKm == null ||
              (job.distanceKm != null && job.distanceKm! <= _radiusKm!);
          return matchesDate && matchesCategory && matchesRadius;
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
            padding: _selectedEstate == null
                ? const EdgeInsets.fromLTRB(16, 10, 16, 18)
                : const EdgeInsets.fromLTRB(16, 8, 16, 18),
            children: [
              if (_selectedEstate == null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _myJobsOnly ? 'My jobs' : 'Jobs for the Day',
                        style: TextStyle(
                          color: _workerInk,
                          fontSize: 28,
                          height: 1.1,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8F3DE),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _myJobsOnly
                            ? '${selectedJobs.length} jobs'
                            : '${selectedJobs.length} jobs near you',
                        style: const TextStyle(
                          color: _workerGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _nearbyFilters(selectedJobs, allJobs: jobs),
                if (!_myJobsOnly) ...[
                  const SizedBox(height: 10),
                  _distanceFilter(),
                  const SizedBox(height: 7),
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
                  const SizedBox(height: 10),
                ],
              ],
              if (selectedJobs.isEmpty)
                _emptyJobsMessage()
              else if (_selectedEstate == null) ...[
                const SizedBox(height: 2),
                Text(
                  _myJobsOnly
                      ? 'Accepted jobs'
                      : _selectedDate == null
                      ? 'Lands near you'
                      : 'Jobs for ${_selectedDate!.day} '
                            '${_months[_selectedDate!.month - 1]}',
                  style: const TextStyle(color: _workerMuted, fontSize: 14),
                ),
                const SizedBox(height: 7),
                for (final entry in estateJobs.entries)
                  _estateJobCard(entry.key, entry.value),
              ] else ...[
                _jobDetailsHeader(detailsJobs),
                const SizedBox(height: 8),
                for (final job in detailsJobs) _nearbyJobCard(job, jobs),
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

  Widget _nearbyFilters(List<WorkerJob> jobs, {List<WorkerJob>? allJobs}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              if (!_myJobsOnly) ...[
                _filterButton('All', selected: _category == null),
                _filterIcon(Icons.eco, 'Nut Gatherer'),
                _filterIcon(Icons.agriculture, 'Machine'),
                _filterIcon(Icons.build, 'Manual'),
              ],
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
          if (!_myJobsOnly) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.circle, size: 12, color: _workerGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedDate == null
                        ? 'View all lands across Sri Lanka'
                        : 'Jobs for ${_selectedDate!.day} '
                              '${_months[_selectedDate!.month - 1]}',
                    style: const TextStyle(color: _workerMuted, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EstateJobsMapPage(
                        jobs: allJobs ?? jobs,
                        radiusKm: _radiusKm ?? 20,
                        nearbyOnly: _radiusKm != null,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Open map',
                    style: TextStyle(
                      color: _workerGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F0E8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                initials.isEmpty ? 'ES' : initials,
                style: const TextStyle(
                  color: _workerGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 11),
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
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Owner: ${firstJob.estateOwnerName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _workerMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _myJobsOnly
                        ? '${jobs.length} accepted job${jobs.length == 1 ? '' : 's'}'
                        : '${jobs.length} job${jobs.length == 1 ? '' : 's'} available',
                    style: const TextStyle(
                      color: _workerGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _workerGreen, size: 25),
          ],
        ),
      ),
    );
  }

  Widget _filterButton(String label, {required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _category = null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
        size: 22,
      ),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _distanceFilter() {
    const options = <int?>[null, 2, 5, 10, 20, 30];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in options)
          ChoiceChip(
            label: Text(value == null ? 'ALL' : '$value km'),
            selected: value == _radiusKm,
            selectedColor: _workerGreen,
            labelStyle: TextStyle(
              color: value == _radiusKm ? Colors.white : _workerInk,
              fontWeight: FontWeight.bold,
            ),
            onSelected: (_) => setState(() => _radiusKm = value),
          ),
      ],
    );
  }

  Widget _nearbyMap() {
    return Container(
      height: 126,
      decoration: BoxDecoration(
        color: const Color(0xFFD8F1E2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFB4D9C0)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.location_on, color: _workerGreen, size: 42),
          ),
          Positioned(
            top: 9,
            left: 9,
            child: _mapLabel(
              _radiusKm == null ? 'All lands' : '$_radiusKm km radius',
            ),
          ),
          Positioned(
            top: 9,
            right: 9,
            child: _mapLabel(
              AuthService.currentUser?.location?.trim().isNotEmpty == true
                  ? AuthService.currentUser!.location!.trim()
                  : 'Current location',
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 9,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _radiusKm == null
                    ? 'Showing all lands across Sri Lanka'
                    : 'Active Match Zone: 0 - $_radiusKm km',
                style: TextStyle(
                  color: _workerInk,
                  fontSize: 13,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _workerInk,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
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
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          button: true,
          label: 'View ${firstJob.estateName} location',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openEstateLocation(firstJob, jobs),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F0E8),
                      borderRadius: BorderRadius.circular(17),
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                firstJob.estateName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _workerInk,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF65B985),
                              size: 15,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Owner: ${firstJob.estateOwnerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _workerMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 5),
                        _estateRatingPill(firstJob),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'View land location',
                    onPressed: () => _openEstateLocation(firstJob, jobs),
                    icon: const Icon(
                      Icons.location_on,
                      color: _workerGreen,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          firstJob.distanceKm == null
              ? firstJob.location
              : '${firstJob.location}  ·  ${firstJob.distanceKm!.toStringAsFixed(1)} km away',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _workerMuted, fontSize: 13),
        ),
        const SizedBox(height: 3),
        Text(
          _formatJobDate(firstJob.requiredDate),
          style: const TextStyle(
            color: _workerGreen,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Available jobs',
                style: TextStyle(
                  color: _workerInk,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

  Widget _estateRatingPill(WorkerJob job) {
    final average = job.estateOwnerAverageRating;
    final label = average == null
        ? 'New (0)'
        : '${average.toStringAsFixed(1)} (${job.estateOwnerRatingCount})';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD47A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Color(0xFFF5A623), size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9A6400),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEstateLocation(
    WorkerJob estateJob,
    List<WorkerJob> jobs,
  ) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => EstateJobsMapPage(
          jobs: jobs,
          initialEstateId: estateJob.estateOwnerId,
          initialEstateName: estateJob.estateName,
        ),
      ),
    );
  }

  Widget _nearbyJobCard(WorkerJob job, List<WorkerJob> allJobs) {
    final applicationStatus = job.applicationStatus?.toLowerCase();
    final estateLocation = job.estateLocation.trim().isNotEmpty
        ? job.estateLocation.trim()
        : job.location.trim();
    final accepted = applicationStatus == 'accepted';
    final applied =
        job.applicationId != null && applicationStatus != 'declined';
    final declining = _decliningJobId == job.id;
    final completed =
        job.status.toLowerCase() == 'completed' ||
        job.applicationStatus?.toLowerCase() == 'completed';
    final canDecline = accepted && job.canDecline && !completed;
    final available = (job.workersNeeded - job.confirmedWorkers).clamp(
      0,
      job.workersNeeded,
    );
    final progress = job.workersNeeded == 0
        ? 0.0
        : (job.confirmedWorkers / job.workersNeeded).clamp(0.0, 1.0);

    // Bidirectional completion state
    final awaitingOwnerAck = job.workerInitiatedCompletion; // worker went first
    final awaitingWorkerAck = job.needsCompletionAcknowledgement; // owner went first
    final initiating = _acknowledgingJobId == job.id;
    final canComplete = job.canInitiateCompletion;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
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
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EC),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  completed
                      ? 'Completed'
                      : awaitingOwnerAck
                      ? 'Awaiting Owner'
                      : awaitingWorkerAck
                      ? 'Awaiting You'
                      : accepted
                      ? 'Accepted'
                      : applied
                      ? 'Applied'
                      : 'Open',
                  style: const TextStyle(
                    color: _workerGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _jobDescription(job.category),
            style: const TextStyle(
              color: _workerMuted,
              fontSize: 13,
              height: 1.25,
            ),
          ),
          if (estateLocation.isNotEmpty) ...[
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _workerGreen),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFFD67A18),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      estateLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _workerInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Rs.${job.dailyRate.toStringAsFixed(0)} / day',
            style: const TextStyle(
              color: _workerGreen,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$available places available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _workerGreen,
                    fontSize: 13,
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
                  style: const TextStyle(color: _workerMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
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
                  style: const TextStyle(color: _workerMuted, fontSize: 12),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  'Required: ${job.workersNeeded}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: _workerMuted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFEAF1EB),
              valueColor: const AlwaysStoppedAnimation<Color>(_workerGreen),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: completed
                        ? null
                        : accepted
                        ? !canDecline || declining
                              ? null
                              : () => _declineJob(job)
                        : () => _acceptOrShowSameDayConflict(job, allJobs),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _workerGreen,
                      side: const BorderSide(color: _workerGreen, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                    ),
                    child: Text(
                      completed
                          ? 'Completed'
                          : accepted
                          ? !canDecline
                                ? 'Job in progress'
                                : declining
                                ? 'Declining...'
                                : 'Decline job'
                          : 'Accept job',
                    ),
                  ),
                ),
              ),
              if (!completed) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton.icon(
                      onPressed: () => _openNegotiation(job),
                      icon: const Icon(Icons.chat_outlined, size: 17),
                      label: const Text('Negotiate'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _workerGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (completed && accepted) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton.icon(
                      onPressed: () => _openEstateOwnerProfile(job),
                      icon: const Icon(Icons.person_outline, size: 18),
                      label: const Text('View Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _workerGreen,
                        side: const BorderSide(color: _workerGreen, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton.icon(
                      onPressed: () => _rateEstateOwner(job),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: Text(
                        job.estateOwnerRating == null
                            ? 'Give Rating'
                            : 'Rating ${job.estateOwnerRating}/5',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _workerGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!accepted && !completed) ...[
            const SizedBox(height: 6),
            const Text(
              'Apply to confirm this job.',
              style: TextStyle(color: _workerMuted, fontSize: 12),
            ),
          ],
          // ── Bidirectional completion row ──────────────────────────────
          if (accepted && !completed) ...[
            const SizedBox(height: 8),
            if (awaitingWorkerAck) ...[
              // Owner already initiated — worker needs to acknowledge
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.icon(
                  onPressed: initiating
                      ? null
                      : () => _showCompletionAcknowledgement(job),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Acknowledge Completion'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF256B45),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                ),
              ),
            ] else if (awaitingOwnerAck) ...[
              // Worker already initiated — waiting for owner
              SizedBox(
                width: double.infinity,
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.hourglass_top_rounded, size: 18),
                  label: const Text('Waiting for land owner…'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9A6B12),
                    side: const BorderSide(color: Color(0xFF9A6B12), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                ),
              ),
            ] else if (canComplete) ...[
              // Worker can initiate completion
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.icon(
                  onPressed: initiating ? null : () => _initiateCompletion(job),
                  icon: const Icon(Icons.task_alt_rounded, size: 18),
                  label: initiating
                      ? const Text('Submitting…')
                      : const Text('Complete Job'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF256B45),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(21),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _openEstateOwnerProfile(WorkerJob job) async {
    final rating = await Navigator.push<int?>(
      context,
      MaterialPageRoute(builder: (_) => EstateOwnerWorkerProfilePage(job: job)),
    );
    if (rating != null && rating != job.estateOwnerRating) {
      _reloadJobs();
    }
  }

  Future<void> _rateEstateOwner(WorkerJob job) async {
    var selected = job.estateOwnerRating ?? 0;
    final rating = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text('Rate ${job.estateOwnerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                job.estateName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _workerMuted),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 4,
                children: [
                  for (var value = 1; value <= 5; value++)
                    IconButton(
                      onPressed: () => setDialogState(() => selected = value),
                      icon: Icon(
                        value <= selected ? Icons.star : Icons.star_border,
                        color: value <= selected
                            ? const Color(0xFFE3A008)
                            : const Color(0xFFD9D5CC),
                      ),
                    ),
                ],
              ),
              Text(
                selected == 0 ? 'Select a rating' : '$selected / 5',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected == 0
                  ? null
                  : () => Navigator.pop(dialogContext, selected),
              style: FilledButton.styleFrom(backgroundColor: _workerGreen),
              child: Text(
                job.estateOwnerRating == null ? 'Save Rating' : 'Update Rating',
              ),
            ),
          ],
        ),
      ),
    );
    if (rating == null || !mounted) return;

    try {
      await WorkerService.rateEstateOwner(jobId: job.id, rating: rating);
      if (!mounted) return;
      _reloadJobs();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Land owner rating saved.')));
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _acceptOrShowSameDayConflict(
    WorkerJob job,
    List<WorkerJob> allJobs,
  ) async {
    final conflictingJob = allJobs.where((other) {
      return other.id != job.id &&
          other.applicationStatus?.toLowerCase() == 'accepted' &&
          other.requiredDate.year == job.requiredDate.year &&
          other.requiredDate.month == job.requiredDate.month &&
          other.requiredDate.day == job.requiredDate.day;
    }).firstOrNull;

    if (conflictingJob == null) {
      await _apply(job);
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Job already selected'),
        content: Text(
          'You cannot select two jobs on the same day. Decline your '
          '${conflictingJob.category} job first if you want to accept this job.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateCompletion(WorkerJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete this job?'),
        content: Text(
          'You are marking the ${job.category} job on '
          '${_formatJobDate(job.requiredDate)} as completed.\n\n'
          'The land owner will be asked to confirm before the job is closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF256B45),
            ),
            child: const Text('Complete Job'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acknowledgingJobId = job.id);
    try {
      await WorkerService.initiateJobCompletion(job.id);
      if (!mounted) return;
      setState(() {
        _acknowledgingJobId = null;
        _jobs = WorkerService.getAvailableJobs();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completion request sent. Waiting for the land owner to confirm.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _acknowledgingJobId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _acknowledgingJobId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit completion request.')),
      );
    }
  }

  Future<void> _declineJob(WorkerJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Decline this job?'),
        content: Text(
          'Your place on the ${job.category} job will become available to another worker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep job'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Decline job'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _decliningJobId = job.id);
    try {
      await WorkerService.declineJob(job.id);
      if (!mounted) return;
      setState(() {
        _decliningJobId = null;
        _jobs = WorkerService.getAvailableJobs();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job declined. Your place is now available.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _decliningJobId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openNegotiation(WorkerJob job) async {
    if (job.applicationId == null ||
        job.applicationStatus?.toLowerCase() != 'accepted') {
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
        MaterialPageRoute(builder: (_) => WorkerChatPage(chatId: chatId)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
    return 'Help with general land work, clearing and daily maintenance.';
  }

  String _formatJobDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
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
      child: Text(
        _myJobsOnly
            ? 'You have no accepted jobs yet.'
            : 'No jobs found for this date.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _workerMuted, fontSize: 16),
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
          Text(
            'Date: ${job.requiredDate.toLocal().toString().split(' ').first}',
          ),
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
              onTap:
                  item.type == NotificationType.dayJobChat &&
                      item.dayJobChatId != null
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkerChatPage(chatId: item.dayJobChatId!),
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
    return FutureBuilder<WorkerProfileSummary>(
      future: _profileSummary,
      initialData: _profileCache,
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return _profileContent(snapshot.data!);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: _workerGreen),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: _workerMuted,
                    size: 44,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Could not load your worker profile.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reloadProfile,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _profileContent(WorkerProfileSummary profile) {
    final categories = profile.workCategories.isEmpty
        ? 'No completed or accepted job categories yet'
        : profile.workCategories.join(', ');
    final average = profile.averageRating;
    final ratingLabel = average == null ? 'New' : average.toStringAsFixed(1);
    final activeLabel = profile.activeJobs == 0
        ? 'Available for nearby jobs'
        : '${profile.activeJobs} active ${profile.activeJobs == 1 ? 'job' : 'jobs'}';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const ProfileTitle(),
        const SizedBox(height: 16),
        ProfileIdentityCard(
          name: profile.name,
          role: 'Day Job Worker',
          phone: profile.phone,
          location: profile.location,
        ),
        const SizedBox(height: 18),
        const ProfileSectionLabel('MY ACTIVITY'),
        const SizedBox(height: 8),
        ProfileStatsGrid(
          children: [
            ProfileStatTile(
              value: '${profile.completedJobs}',
              label: 'Completed jobs',
              icon: Icons.check_circle_outline,
            ),
            ProfileStatTile(
              value: '${profile.acceptedJobs}',
              label: 'Accepted jobs',
              icon: Icons.work_outline,
            ),
            ProfileStatTile(
              value: ratingLabel,
              label: 'Average rating',
              icon: Icons.star_outline,
            ),
          ],
        ),
        const SizedBox(height: 18),
        const ProfileSectionLabel('WORK DETAILS'),
        const SizedBox(height: 8),
        BuyerCard(
          child: Column(
            children: [
              _WorkerProfileDetail(
                icon: Icons.work_outline,
                title: 'Work categories',
                value: categories,
              ),
              const Divider(height: 24),
              _WorkerProfileDetail(
                icon: Icons.check_circle_outline,
                title: 'Availability',
                value: activeLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const ProfileSectionLabel('ACCOUNT'),
        const SizedBox(height: 8),
        ProfileAccountCard(onEdit: _editWorkerProfile),
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
        scrollable: true,
        title: const Text('Edit worker details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: TextEditingController(text: user.phone),
              readOnly: true,
              decoration: autoFilledDecoration(label: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await AuthService.updateProfile(
                name: nameController.text.trim(),
                location: locationController.text.trim(),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    locationController.dispose();
    if (saved == true && mounted) _reloadProfile();
  }

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
          _navItem(Icons.chat_bubble_outline, 'Chats', 2, badge: _chatCount),
          _navItem(
            Icons.notifications_none,
            'Alerts',
            3,
            badge: _notificationCount,
          ),
          _navItem(Icons.account_circle_outlined, 'Profile', 4),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, {int badge = 0}) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tab = index;
            if (index == 1) {
              _myJobsOnly = false;
              _category = null;
            }
            if (index == 3) _notificationCount = 0;
          });
          if (index == 0 || index == 1) _reloadJobs();
          if (index == 4) _reloadProfile();
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
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: selected ? _workerGreen : _workerMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
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

class _WorkerCalendarLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _WorkerCalendarLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: _workerMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
        Icon(icon, color: _workerGreen, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _workerInk,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

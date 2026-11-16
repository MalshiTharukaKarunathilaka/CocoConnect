import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/owner_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'accepted_workers_page.dart';
import 'worker_profile_page.dart';

const Color _detailGreen = Color(0xFF2A704E);
const Color _detailBackground = Color(0xFFFCF9F3);
const Color _detailInk = Color(0xFF193126);

class JobDetailPage extends StatefulWidget {
  final DayJob job;

  const JobDetailPage({super.key, required this.job});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  late bool _isCompleted;
  late bool _awaitingWorkerAcknowledgement;
  bool _completing = false;
  bool _deleting = false;
  late final Map<int, int?> _workerRatings;

  DayJob get job => widget.job;
  bool get _isFullyStaffed =>
      job.workersNeeded > 0 && job.confirmedWorkers >= job.workersNeeded;
  bool get _isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requiredDate = DateTime(
      job.requiredDate.year,
      job.requiredDate.month,
      job.requiredDate.day,
    );
    return requiredDate.isAfter(today);
  }

  @override
  void initState() {
    super.initState();
    _isCompleted = job.status.toUpperCase() == 'COMPLETED';
    _awaitingWorkerAcknowledgement =
        job.status.toUpperCase() == 'AWAITING_WORKER_ACK';
    _workerRatings = {
      for (final worker in job.acceptedWorkers) worker.id: worker.rating,
    };
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(
      job.requiredDate.year,
      job.requiredDate.month,
      job.requiredDate.day,
    );
    final showCompletedLayout = _isCompleted || selectedDate.isBefore(today);

    return Scaffold(
      backgroundColor: _detailBackground,
      body: SizedBox.expand(
        child: Container(
          color: _detailBackground,
          child: SafeArea(
            child: showCompletedLayout
                ? _pastJobLayout(context)
                : _upcomingJobLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _pastJobLayout(BuildContext context) {
    return Column(
      children: [
        _header(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            children: [
              _status(),
              const SizedBox(height: 8),
              _jobSummary(),
              if (!_isCompleted) ...[
                const SizedBox(height: 10),
                _completionButton(),
              ],
              if (_isFuture) ...[const SizedBox(height: 10), _deleteButton()],
              if (_isCompleted || _awaitingWorkerAcknowledgement) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text(
                      'All Workers',
                      style: TextStyle(
                        color: _detailInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFA8EDC5),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${job.acceptedWorkers.length}',
                        style: TextStyle(
                          color: _detailGreen,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final worker in job.acceptedWorkers) ...[
                  _workerCard(context, worker),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ),
        ),
        _bottomNavigation(),
      ],
    );
  }

  Widget _upcomingJobLayout(BuildContext context) {
    return Column(
      children: [
        _header(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
            children: [
              _status(),
              const SizedBox(height: 6),
              _jobSummary(),
              const SizedBox(height: 6),
              _workerProgress(),
              const SizedBox(height: 6),
              _completionButton(),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AcceptedWorkersPage(job: job),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 26),
                  label: const Text(
                    'View Accepted Workers',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _detailGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                ),
              ),
              if (_isFuture) ...[const SizedBox(height: 8), _deleteButton()],
            ],
          ),
        ),
        _bottomNavigation(),
      ],
    );
  }

  Widget _workerProgress() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD5E3DB), width: 1.5),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: job.workersNeeded == 0
                  ? 0
                  : job.confirmedWorkers / job.workersNeeded,
              minHeight: 6,
              backgroundColor: Color(0xFFEDE7DC),
              color: _detailGreen,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${job.confirmedWorkers} Accepted',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _detailInk,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Target: ${job.workersNeeded} Workers',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _detailInk,
                    fontSize: 13,
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

  Widget _completionButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: _isCompleted || _awaitingWorkerAcknowledgement || _completing
            ? null
            : _completeJob,
        style: FilledButton.styleFrom(
          backgroundColor: _detailGreen,
          disabledBackgroundColor: _detailGreen,
          disabledForegroundColor: Colors.white,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(34),
          ),
        ),
        child: _completing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                _isCompleted
                    ? 'Completed'
                    : _awaitingWorkerAcknowledgement
                    ? 'Awaiting worker acknowledgement'
                    : 'Complete Job',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _deleteButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _deleting ? null : _deleteJob,
        icon: _deleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFC62828),
                ),
              )
            : const Icon(Icons.delete_outline),
        label: Text(_deleting ? 'Deleting...' : 'Delete Job'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFC62828),
          side: const BorderSide(color: Color(0xFFC62828)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(34),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this job?'),
        content: const Text(
          'This future job and its worker applications will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await OwnerService.deleteDayJob(job.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _showMessage(context, error.message);
    } catch (_) {
      if (mounted) _showMessage(context, 'Could not delete this job.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _completeJob() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requiredDate = DateTime(
      job.requiredDate.year,
      job.requiredDate.month,
      job.requiredDate.day,
    );

    if (requiredDate.isAfter(today)) {
      _showMessage(
        context,
        'This is a future day. You cannot complete this job yet.',
      );
      return;
    }
    if (!_isFullyStaffed) {
      _showMessage(
        context,
        'All required workers must be accepted before completion.',
      );
      return;
    }

    setState(() => _completing = true);
    try {
      await OwnerService.completeDayJob(job.id);
      if (!mounted) return;
      setState(() => _awaitingWorkerAcknowledgement = true);
      _showMessage(
        context,
        'Completion sent. The job will be completed after the accepted workers acknowledge it.',
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(context, error.message);
    } catch (_) {
      if (mounted) _showMessage(context, 'Could not complete this job.');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: const BoxDecoration(
        color: _detailBackground,
        border: Border(bottom: BorderSide(color: Color(0xFFE9E2D9))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 32, color: _detailInk),
          ),
          const SizedBox(width: 4),
          const Text(
            'Job Detail',
            style: TextStyle(
              color: _detailInk,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _status() {
    final status = _isCompleted
        ? 'COMPLETED'
        : _awaitingWorkerAcknowledgement
        ? 'AWAITING WORKER'
        : _isFullyStaffed
        ? 'IN PROGRESS'
        : 'OPEN';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F1DF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          '●  NG-${job.id.toString().padLeft(3, '0')} · $status',
          style: const TextStyle(
            color: _detailGreen,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _jobSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD5E3DB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            job.category,
            style: TextStyle(
              color: _detailInk,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Estate job',
            style: TextStyle(color: Color(0xFF65766C), fontSize: 14),
          ),
          const SizedBox(height: 6),
          _infoTile(Icons.location_on_outlined, 'Location', job.location),
          const SizedBox(height: 5),
          _infoTile(
            Icons.calendar_today_outlined,
            'Date & Hours',
            '${job.requiredDate.day.toString().padLeft(2, '0')} '
                '${_months[job.requiredDate.month - 1].substring(0, 3)} '
                '${job.requiredDate.year} '
                '(7:30 AM - 4:30 PM)',
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAF5),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE7E0D4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Daily Rate',
                    style: TextStyle(color: Color(0xFF65766C), fontSize: 14),
                  ),
                ),
                Flexible(
                  child: Text(
                    'Rs. ${job.dailyRate.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _detailGreen,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE7E0D4)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFECE8DF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _detailGreen, size: 19),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF65766C),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: _detailInk,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerCard(BuildContext context, AcceptedWorker worker) {
    final rating = _workerRatings[worker.id];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _detailGreen, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8EBDD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: _detailGreen, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  worker.name,
                  style: const TextStyle(
                    color: _detailInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _workerButton(
                  label: 'View Profile',
                  icon: Icons.person_outline,
                  background: const Color(0xFFE8E9ED),
                  foreground: _detailInk,
                  onPressed: () async {
                    final updatedRating = await Navigator.push<int?>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerProfilePage(
                          workerId: worker.id,
                          fallbackName: worker.name,
                          jobId: job.id,
                          jobCategory: job.category,
                          currentJobRating: rating,
                          canRate:
                              _isCompleted || _awaitingWorkerAcknowledgement,
                        ),
                      ),
                    );
                    if (updatedRating != null && mounted) {
                      setState(() => _workerRatings[worker.id] = updatedRating);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _workerRatingButton(
                  rating: rating,
                  onPressed: _isCompleted || _awaitingWorkerAcknowledgement
                      ? () => _showRatingSheet(worker)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _workerButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _workerRatingButton({
    required int? rating,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _detailGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: rating == null
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, size: 20),
                  SizedBox(width: 5),
                  Text(
                    'Give Rating',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var value = 1; value <= 5; value++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Icon(
                        value <= rating ? Icons.star : Icons.star_border,
                        size: 17,
                        color: value <= rating
                            ? const Color(0xFFFFC247)
                            : const Color(0xFFB7D8C6),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showRatingSheet(AcceptedWorker worker) async {
    final rating = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(
        worker: _Worker(
          worker.name,
          Icons.person,
          '${job.category} · NG-${job.id.toString().padLeft(3, '0')}',
        ),
        initialRating: _workerRatings[worker.id],
      ),
    );
    if (rating == null || !mounted) return;

    try {
      await OwnerService.rateDayJobWorker(
        jobId: job.id,
        workerId: worker.id,
        rating: rating,
      );
      if (!mounted) return;
      setState(() => _workerRatings[worker.id] = rating);
      _showMessage(context, 'Rating saved for ${worker.name}.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(context, error.message);
    } catch (_) {
      if (mounted) _showMessage(context, 'Could not save this rating.');
    }
  }

  Widget _bottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: const BoxDecoration(
        color: _detailBackground,
        border: Border(top: BorderSide(color: Color(0xFFE4DED4))),
      ),
      child: Row(
        children: [
          _NavItem(
            Icons.dashboard_outlined,
            'Dashboard',
            onTap: () => openTab(context, AppTab.dashboard),
          ),
          const _NavItem(Icons.calendar_month, 'Calendar', active: true),
          _NavItem(
            Icons.chat_bubble_outline,
            'Chats',
            onTap: () =>
                openTab(context, AppTab.chats, chatScope: ChatScope.dayJobs),
          ),
          _NavItem(
            Icons.notifications_none,
            'Alerts',
            onTap: () => openTab(context, AppTab.alerts),
          ),
          _NavItem(
            Icons.person_outline,
            'Profile',
            onTap: () => openTab(context, AppTab.profile),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem(this.icon, this.label, {this.active = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? _detailGreen : const Color(0xFF65766C);
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

class _Worker {
  final String name;
  final IconData icon;
  final String subtitle;

  const _Worker(this.name, this.icon, this.subtitle);
}

class _RatingSheet extends StatefulWidget {
  final _Worker worker;
  final int? initialRating;

  const _RatingSheet({required this.worker, required this.initialRating});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 0;

  String get _ratingLabel {
    switch (_rating) {
      case 0:
        return 'Tap a star to rate';
      case 1:
        return 'Needs Improvement';
      case 2:
        return 'Below Average';
      case 3:
        return 'Good Performance';
      case 4:
        return 'Very Good Performance!';
      default:
        return 'Outstanding Performance!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(34)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD8EBDD),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.worker.icon,
                        color: _detailGreen,
                        size: 46,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: _detailGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.worker.name,
                        style: const TextStyle(
                          color: _detailInk,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.worker.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF65766C),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1EEE8),
                    fixedSize: const Size(54, 54),
                  ),
                  icon: const Icon(Icons.close, color: _detailInk, size: 28),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Rate ',
                  style: TextStyle(
                    color: _detailInk,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Performance',
                  style: TextStyle(
                    color: _detailInk,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int index = 1; index <= 5; index++)
                  IconButton(
                    onPressed: () => setState(() => _rating = index),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      index <= _rating ? Icons.star : Icons.star_border,
                      size: 46,
                      color: index <= _rating
                          ? const Color(0xFF9B5727)
                          : const Color(0xFFE2DDD4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDCC8),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFF5C2D12),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _rating == 0 ? _ratingLabel : '$_rating.0 · $_ratingLabel',
                    style: const TextStyle(
                      color: Color(0xFF5C2D12),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            SizedBox(
              width: double.infinity,
              height: 68,
              child: FilledButton.icon(
                onPressed: _rating == 0
                    ? null
                    : () => Navigator.pop(context, _rating),
                icon: const Icon(Icons.star, size: 28),
                label: Text(
                  widget.initialRating == null
                      ? 'Submit Rating'
                      : 'Update Rating',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _detailGreen,
                  disabledBackgroundColor: const Color(0xFFBCC8C1),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(34),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Skip for Now',
                style: TextStyle(color: Color(0xFF65766C), fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
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

import 'package:flutter/material.dart';
import 'accepted_workers_page.dart';

const Color _detailGreen = Color(0xFF2A704E);
const Color _detailBackground = Color(0xFFFCF9F3);
const Color _detailInk = Color(0xFF193126);

class JobDetailPage extends StatelessWidget {
  final DateTime date;

  const JobDetailPage({super.key, required this.date});

  static const List<_Worker> _workers = [
    _Worker('Kamal Bandara', Icons.person),
    _Worker('Sunil Shantha', Icons.person_outline),
    _Worker('Chaminda Silva', Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final isUpcoming = !selectedDate.isBefore(today);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 390,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _detailBackground,
          child: SafeArea(
            child: isUpcoming
                ? _upcomingJobLayout(context)
                : _pastJobLayout(context),
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
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
            children: [
              _status(),
              const SizedBox(height: 24),
              _jobSummary(),
              const SizedBox(height: 42),
              Row(
                children: [
                  const Text(
                    'All Workers',
                    style: TextStyle(
                      color: _detailInk,
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFA8EDC5),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: _detailGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              for (final worker in _workers) ...[
                _workerCard(context, worker),
                const SizedBox(height: 20),
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
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
            children: [
              _status(),
              const SizedBox(height: 24),
              _jobSummary(),
              const SizedBox(height: 26),
              _workerProgress(),
              const SizedBox(height: 26),
              SizedBox(
                height: 68,
                child: FilledButton(
                  onPressed: () => _showMessage(context, 'Job completed'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _detailGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34),
                    ),
                  ),
                  child: const Text(
                    'Complete Job',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 68,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AcceptedWorkersPage(),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 26),
                  label: const Text(
                    'View Accepted Workers',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
            ],
          ),
        ),
        _bottomNavigation(),
      ],
    );
  }

  Widget _workerProgress() {
    return Container(
      padding: const EdgeInsets.fromLTRB(34, 30, 34, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD5E3DB), width: 1.5),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 10,
              backgroundColor: Color(0xFFEDE7DC),
              color: _detailGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 Accepted',
                style: TextStyle(
                  color: _detailInk,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Target: 5 Workers',
                style: TextStyle(
                  color: _detailInk,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
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
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const CircleAvatar(
            radius: 27,
            backgroundColor: _detailGreen,
            child: Icon(Icons.person_outline, color: Colors.white, size: 29),
          ),
        ],
      ),
    );
  }

  Widget _status() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F1DF),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text(
          '●  NG-001 · OPEN',
          style: TextStyle(
            color: _detailGreen,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _jobSummary() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD5E3DB), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nut Gatherers Required',
            style: TextStyle(
              color: _detailInk,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Green Valley Estate',
            style: TextStyle(color: Color(0xFF65766C), fontSize: 18),
          ),
          const SizedBox(height: 28),
          _infoTile(
            Icons.location_on_outlined,
            'Location',
            'Wattegama Road, Kurunegala',
          ),
          const SizedBox(height: 16),
          _infoTile(
            Icons.calendar_today_outlined,
            'Date & Hours',
            '${date.day.toString().padLeft(2, '0')} '
                '${_months[date.month - 1].substring(0, 3)} ${date.year} '
                '(7:30 AM - 4:30 PM)',
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAF5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7E0D4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daily Rate',
                  style: TextStyle(color: Color(0xFF65766C), fontSize: 17),
                ),
                Text(
                  'Rs. 2,500',
                  style: TextStyle(
                    color: _detailGreen,
                    fontSize: 23,
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

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E0D4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFECE8DF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _detailGreen, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF65766C),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _detailInk,
                    fontSize: 16,
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

  Widget _workerCard(BuildContext context, _Worker worker) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _detailGreen, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8EBDD),
                  shape: BoxShape.circle,
                ),
                child: Icon(worker.icon, color: _detailGreen, size: 44),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  worker.name,
                  style: const TextStyle(
                    color: _detailInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _workerButton(
                  label: 'View Profile',
                  icon: Icons.person_outline,
                  background: const Color(0xFFE8E9ED),
                  foreground: _detailInk,
                  onPressed: () =>
                      _showMessage(context, '${worker.name} profile'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _workerButton(
                  label: 'Give Rating',
                  icon: Icons.star,
                  background: _detailGreen,
                  foreground: Colors.white,
                  onPressed: () => _showRatingSheet(context, worker),
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
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRatingSheet(BuildContext context, _Worker worker) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingSheet(
        worker: worker,
        onSubmitted: () =>
            _showMessage(context, 'Rating submitted for ${worker.name}'),
      ),
    );
  }

  Widget _bottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: _detailBackground,
        border: Border(top: BorderSide(color: Color(0xFFE4DED4))),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(Icons.grid_view_rounded, 'Dashboard', active: true),
          _NavItem(Icons.receipt_long_outlined, 'Orders'),
          _NavItem(Icons.notifications_none, 'Notifications'),
          _NavItem(Icons.person_outline, 'Profile'),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _NavItem(this.icon, this.label, {this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? _detailGreen : const Color(0xFF65766C);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 27),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _Worker {
  final String name;
  final IconData icon;

  const _Worker(this.name, this.icon);
}

class _RatingSheet extends StatefulWidget {
  final _Worker worker;
  final VoidCallback onSubmitted;

  const _RatingSheet({required this.worker, required this.onSubmitted});

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _rating = 5;

  String get _ratingLabel {
    switch (_rating) {
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
                      const Text(
                        'Nut Gatherer · NG-001',
                        style: TextStyle(
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
                      Icons.star,
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
                    '$_rating.0 · $_ratingLabel',
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
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSubmitted();
                },
                icon: const Icon(Icons.star, size: 28),
                label: const Text(
                  'Submit Rating',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

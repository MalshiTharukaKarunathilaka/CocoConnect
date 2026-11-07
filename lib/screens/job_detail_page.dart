import 'package:flutter/material.dart';

const Color _detailGreen = Color(0xFF245F48);
const Color _detailBackground = Color(0xFFFCF9F3);
const Color _detailInk = Color(0xFF193126);

class JobDetailPage extends StatelessWidget {
  final DateTime date;

  const JobDetailPage({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          width: 390,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _detailBackground,
          child: SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
                    children: [
                      _status(),
                      const SizedBox(height: 18),
                      _jobSummary(),
                      const SizedBox(height: 18),
                      _progress(),
                      const SizedBox(height: 24),
                      _button('View Accepted Workers', () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No accepted workers yet'),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                      _button('Complete Job', () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Job marked for completion'),
                          ),
                        );
                      }, trailing: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: const BoxDecoration(
        color: _detailBackground,
        border: Border(bottom: BorderSide(color: Color(0xFFE9E2D9))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 34, color: _detailInk),
          ),
          const SizedBox(width: 8),
          const Text(
            'Job Detail',
            style: TextStyle(
              color: _detailInk,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _status() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD8F1DF),
          borderRadius: BorderRadius.circular(24),
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
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
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
          const SizedBox(height: 6),
          const Text(
            'Green Valley Estate',
            style: TextStyle(color: Color(0xFF65766C), fontSize: 18),
          ),
          const SizedBox(height: 22),
          _infoTile(
            Icons.location_on_outlined,
            'Location',
            'Wattegama Road, Kurunegala',
          ),
          const SizedBox(height: 12),
          _infoTile(
            Icons.calendar_today_outlined,
            'Date & Hours',
            '${date.day} ${_months[date.month - 1]} ${date.year} (7:30 AM – 4:30 PM)',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                    fontSize: 17,
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

  Widget _progress() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD5E3DB), width: 1.5),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 10,
              backgroundColor: Color(0xFFECE5D8),
              valueColor: AlwaysStoppedAnimation(_detailGreen),
            ),
          ),
          const SizedBox(height: 22),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0 Accepted',
                style: TextStyle(
                  color: _detailInk,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Target: 5 Workers',
                style: TextStyle(
                  color: _detailInk,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(
    String label,
    VoidCallback onPressed, {
    bool trailing = false,
  }) {
    return SizedBox(
      height: 70,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _detailGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (trailing) ...[
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward, size: 28),
            ],
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

import 'package:flutter/material.dart';

const Color _rosterGreen = Color(0xFF246B45);
const Color _rosterBackground = Color(0xFFFCF9F3);
const Color _rosterInk = Color(0xFF17251F);

class AcceptedWorkersPage extends StatelessWidget {
  const AcceptedWorkersPage({super.key});

  static const List<_Worker> _workers = [
    _Worker('Kamal Bandara', Icons.person),
    _Worker('Sunil Shantha', Icons.person_outline),
    _Worker('Chaminda Silva', Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE7E5DF),
      body: Center(
        child: Container(
          width: 390,
          constraints: const BoxConstraints(maxWidth: 430),
          color: _rosterBackground,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                const Text(
                  'Nut Gatherer',
                  style: TextStyle(
                    color: _rosterInk,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Accepted Workers Roster',
                      style: TextStyle(color: _rosterInk, fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFB1F0C9),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '3',
                        style: TextStyle(
                          color: _rosterGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                for (final worker in _workers) ...[
                  _workerCard(context, worker),
                  const SizedBox(height: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _workerCard(BuildContext context, _Worker worker) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _rosterGreen, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: Color(0xFFD8EBDD),
                  shape: BoxShape.circle,
                ),
                child: Icon(worker.icon, color: _rosterGreen, size: 46),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  worker.name,
                  style: const TextStyle(
                    color: _rosterInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFB1F0C9),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'Accepted',
                  style: TextStyle(
                    color: _rosterGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFCFAF5),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFAD6C2D), width: 1.5),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Rate',
                        style: TextStyle(
                          color: Color(0xFF68766F),
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Rs. 2,500 / day',
                        style: TextStyle(
                          color: _rosterInk,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${worker.name} profile')),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8E5DE),
                    foregroundColor: _rosterInk,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('View Profile'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contact ${worker.name}')),
                  ),
                  icon: const Icon(Icons.send, color: Colors.white, size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: _rosterGreen,
                    fixedSize: const Size(54, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
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
}

class _Worker {
  final String name;
  final IconData icon;

  const _Worker(this.name, this.icon);
}

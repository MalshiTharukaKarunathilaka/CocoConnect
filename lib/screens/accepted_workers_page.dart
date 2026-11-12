import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/day_job_chat_service.dart';
import '../services/owner_service.dart';
import 'worker_chat_page.dart';

const Color _rosterGreen = Color(0xFF246B45);
const Color _rosterBackground = Color(0xFFFCF9F3);
const Color _rosterInk = Color(0xFF17251F);

class AcceptedWorkersPage extends StatelessWidget {
  final DayJob job;

  const AcceptedWorkersPage({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final workers = job.acceptedWorkers;

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
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 32,
                        color: _rosterInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        job.category,
                        style: const TextStyle(
                          color: _rosterInk,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Accepted Workers',
                        style: TextStyle(color: _rosterInk, fontSize: 22),
                      ),
                    ),
                    _countBadge(workers.length),
                  ],
                ),
                const SizedBox(height: 28),
                if (workers.isEmpty)
                  _emptyState()
                else
                  for (final worker in workers) ...[
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

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFB1F0C9),
        shape: BoxShape.circle,
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: _rosterGreen,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFD8E3DC)),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_outline, color: _rosterGreen, size: 54),
          SizedBox(height: 14),
          Text(
            'No accepted workers yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _rosterInk,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Workers will appear here after they accept this job.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF68766F), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _workerCard(BuildContext context, AcceptedWorker worker) {
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
                child: const Icon(
                  Icons.person,
                  color: _rosterGreen,
                  size: 46,
                ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Rate',
                        style: TextStyle(
                          color: Color(0xFF68766F),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rs. ${job.dailyRate.toStringAsFixed(0)} / day',
                        style: const TextStyle(
                          color: _rosterInk,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _openChat(context, worker),
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

  Future<void> _openChat(BuildContext context, AcceptedWorker worker) async {
    try {
      final chatId = await DayJobChatService.openChat(
        job.id,
        workerId: worker.id,
      );
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerChatPage(chatId: chatId),
        ),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }
}

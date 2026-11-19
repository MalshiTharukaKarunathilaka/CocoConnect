import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/day_job_chat_service.dart';
import '../services/owner_service.dart';
import '../widgets/owner_widgets.dart';
import '../widgets/role_navigation_page.dart';
import 'worker_chat_page.dart';

class AcceptedWorkersPage extends StatelessWidget {
  final DayJob job;

  const AcceptedWorkersPage({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final workers = job.acceptedWorkers;

    return RoleNavigationPage(
      chatScope: ChatScope.dayJobs,
      current: AppTab.jobs,
      child: OwnerPage(
        child: Column(
          children: [
            OwnerHeader(title: job.category),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Accepted Workers',
                        style: TextStyle(
                          color: kOwnerInk,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _countBadge(workers.length),
                  ],
                ),
                const SizedBox(height: 14),
                if (workers.isEmpty)
                  _emptyState()
                else
                  for (final worker in workers) ...[
                    _workerCard(context, worker),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _countBadge(int count) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kOwnerGreenSoft,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFBFDCC6)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: kOwnerGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return const OwnerCard(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.people_outline, color: kOwnerGreen, size: 42),
          SizedBox(height: 12),
          Text(
            'No accepted workers yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kOwnerInk,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Workers will appear here after they accept this job.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kOwnerMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _workerCard(BuildContext context, AcceptedWorker worker) {
    return OwnerCard(
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: kOwnerGreenSoft,
                child: Icon(Icons.person, color: kOwnerGreen, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  worker.name,
                  style: const TextStyle(
                    color: kOwnerInk,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const OwnerPill('Accepted', icon: Icons.check_circle),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: kOwnerPanel,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Rate',
                        style: TextStyle(color: kOwnerMuted, fontSize: 11.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Rs. ${job.dailyRate.toStringAsFixed(0)} / day',
                        style: const TextStyle(
                          color: kOwnerInk,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open chat',
                  onPressed: () => _openChat(context, worker),
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: kOwnerGreen,
                    fixedSize: const Size(44, 44),
                    shape: const CircleBorder(),
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
        MaterialPageRoute(builder: (_) => WorkerChatPage(chatId: chatId)),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

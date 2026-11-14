import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../state/jobs_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<JobsState>().myJobs;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ScreenTitle('Notifications'),
            const SizedBox(height: 16),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Text('No notifications yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.muted)),
              ),
            for (final m in list) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Job confirmed',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                    const SizedBox(height: 4),
                    Text(
                        '${m.job.title} · ${getEstate(m.job.estateId).name} on ${formatDMY(m.date)}',
                        style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ScreenTitle('Profile'),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(worker.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(worker.district,
                      style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Text('Rating ${worker.rating} (${worker.ratingCount} reviews)',
                      style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

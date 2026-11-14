import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../state/jobs_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'job_details_screen.dart';

class MyJobsScreen extends StatelessWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jobsList = context.watch<JobsState>().myJobs;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, size: 24),
                ),
                const SizedBox(width: 10),
                const ScreenTitle('My Jobs'),
              ],
            ),
            const SizedBox(height: 16),
            if (jobsList.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('You have not accepted any jobs yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.muted)),
              ),
            for (final m in jobsList) ...[
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      JobDetailsScreen(date: m.date, estateId: m.job.estateId),
                )),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m.job.title,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                          const AppPill('Confirmed'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${getEstate(m.job.estateId).name} · ${formatDMY(m.date)}',
                          style: const TextStyle(fontSize: 15, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text('Rs. ${money(m.job.rate)} / day',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ],
                  ),
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

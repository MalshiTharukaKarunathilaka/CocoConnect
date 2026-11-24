import 'package:flutter/material.dart';

import '../services/owner_service.dart';
import '../widgets/app_bottom_nav.dart';

class EstateOwnerJobsPage extends StatefulWidget {
  const EstateOwnerJobsPage({super.key});

  @override
  State<EstateOwnerJobsPage> createState() => _EstateOwnerJobsPageState();
}

class _EstateOwnerJobsPageState extends State<EstateOwnerJobsPage> {
  static const double _pageMaxWidth = 480;
  late Future<List<DayJob>> _jobs;

  @override
  void initState() {
    super.initState();
    _jobs = OwnerService.getDayJobs();
  }

  Future<void> _reload() async {
    final jobs = OwnerService.getDayJobs();
    setState(() => _jobs = jobs);
    await jobs;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
          child: AppBar(title: const Text('Estate jobs')),
        ),
      ),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
        child: SizedBox.expand(
          child: FutureBuilder<List<DayJob>>(
      future: _jobs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load estate jobs.'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final jobs = snapshot.data ?? const <DayJob>[];
        if (jobs.isEmpty) {
          return const Center(child: Text('No jobs posted for your estate yet.'));
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        child: Icon(Icons.work_outline, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    job.category,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  job.status.replaceAll('_', ' '),
                                  style: Theme.of(context).textTheme.labelSmall,
                                  textAlign: TextAlign.end,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${job.requiredDate.toLocal().toString().split(' ').first} '
                              '· ${job.confirmedWorkers}/${job.workersNeeded} workers',
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${job.location} · Rs. ${job.dailyRate.toStringAsFixed(0)}/day',
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
              },
            ),
          ),
        );
      },
          ),
        ),
      ),
    ),
    bottomNavigationBar: SizedBox(
      height: 72,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
          child: const AppBottomNav(
            current: AppTab.jobs,
            chatScope: ChatScope.dayJobs,
          ),
        ),
      ),
    ),
  );
}

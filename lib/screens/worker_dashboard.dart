import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/worker_service.dart';
import 'auth_gate.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  late Future<List<WorkerJob>> _jobs;

  @override
  void initState() {
    super.initState();
    _jobs = WorkerService.getAvailableJobs();
  }

  Future<void> _apply(WorkerJob job) async {
    try {
      await WorkerService.applyForJob(job.id);
      if (!mounted) return;
      setState(() {
        _jobs = WorkerService.getAvailableJobs();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Application sent')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Worker Jobs'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => logOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _jobs = WorkerService.getAvailableJobs();
          });
          await _jobs;
        },
        child: FutureBuilder<List<WorkerJob>>(
          future: _jobs,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 220),
                  Center(child: Text('Could not load jobs: ${snapshot.error}')),
                ],
              );
            }
            final jobs = snapshot.data ?? const <WorkerJob>[];
            if (jobs.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 220),
                  Center(child: Text('No available jobs right now.')),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Hello, ${user?.name ?? 'Worker'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                for (final job in jobs) _jobCard(job),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _jobCard(WorkerJob job) {
    final applied = job.applicationId != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.category,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Date: ${job.requiredDate.toLocal().toString().split(' ').first}'),
            Text('Location: ${job.location}'),
            Text('Daily rate: Rs. ${job.dailyRate.toStringAsFixed(0)}'),
            Text('Workers needed: ${job.workersNeeded}'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: applied ? null : () => _apply(job),
                child: Text(applied ? 'Application sent' : 'Apply for job'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

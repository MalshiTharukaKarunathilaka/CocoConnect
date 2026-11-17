import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../models.dart';
import '../state/jobs_state.dart';
import '../theme.dart';
import '../widgets/already_accepted_dialog.dart';
import '../widgets/job_card.dart';
import '../widgets/ui.dart';
import 'confirmation_screen.dart';
import 'negotiation_screen.dart';

class JobDetailsScreen extends StatelessWidget {
  final DateTime date;
  final String estateId;
  const JobDetailsScreen({super.key, required this.date, required this.estateId});

  void _accept(BuildContext context, Job job) {
    final state = context.read<JobsState>();
    final result = state.acceptJob(date, job.id);
    if (result.ok) {
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => ConfirmationScreen(jobId: job.id),
      ));
    } else if (result.failure == AcceptFailure.conflict && result.conflictJob != null) {
      final taken = result.conflictJob!;
      showAlreadyAcceptedDialog(context, taken, getEstate(taken.estateId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<JobsState>();
    final estate = getEstate(estateId);
    final list = jobsForEstate(estateId);

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
                const ScreenTitle('Job details'),
              ],
            ),
            const SizedBox(height: 14),
            AppCard(
              child: Row(
                children: [
                  InitialsBox(estate.initials, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(estate.name,
                            style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text('Owner: ${estate.owner}',
                            style: const TextStyle(fontSize: 14, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  for (final c in categoriesForEstate(estateId)) IconBubble(c.icon),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('${estate.district} · ${estate.distanceKm} km away',
                style: const TextStyle(fontSize: 15, color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available jobs',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
                AppPill('${list.length} jobs'),
              ],
            ),
            const SizedBox(height: 14),
            for (final job in list) ...[
              JobCard(
                job: job,
                accepted: state.acceptedCount(date, job),
                mine: state.isMine(date, job.id),
                onAccept: () => _accept(context, job),
                onDecline: () => state.declineJob(date, job.id),
                onNegotiate: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => NegotiationScreen(date: date, jobId: job.id),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            AppButton('Back to Dashboard',
                onPressed: () => context.read<AppNav>().goToDashboard()),
          ],
        ),
      ),
    );
  }
}

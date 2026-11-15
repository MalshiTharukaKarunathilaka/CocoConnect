import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';
import 'ui.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final int accepted;
  final bool mine;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onNegotiate;
  const JobCard({
    super.key,
    required this.job,
    required this.accepted,
    required this.mine,
    required this.onAccept,
    required this.onDecline,
    required this.onNegotiate,
  });

  @override
  Widget build(BuildContext context) {
    final places = job.capacity - accepted;
    final full = places <= 0;
    final pct = (accepted / job.capacity).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(job.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
              ),
              AppPill(
                mine ? 'Accepted' : (full ? 'Full' : 'Open'),
                bg: (full && !mine) ? AppColors.sand : AppColors.primarySoft,
                fg: (full && !mine) ? AppColors.muted : AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(job.description,
              style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: 'Rs.${money(job.rate)}',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary)),
            const TextSpan(
                text: '/day',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.muted)),
          ])),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$places places available',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              Text('$accepted of ${job.capacity} accepted',
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          if (mine)
            AppButton('Decline job', outline: true, onPressed: onDecline)
          else
            AppButton(full ? 'Job full' : 'Accept job', onPressed: full ? null : onAccept),
          const SizedBox(height: 12),
          AppButton('Negotiate', icon: Icons.send_outlined, onPressed: onNegotiate),
        ],
      ),
    );
  }
}

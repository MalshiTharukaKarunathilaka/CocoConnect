import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/mock_data.dart';
import '../state/jobs_state.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class ConfirmationScreen extends StatelessWidget {
  final String jobId;
  const ConfirmationScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context) {
    final job = getJob(jobId);

    // "Okay" takes the worker back to the dashboard.
    void goToDashboard() {
      final root = Navigator.of(context, rootNavigator: true);
      final nav = context.read<AppNav>();
      root.popUntil((r) => r.isFirst);
      nav.goToDashboard();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Job confirmation',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 50),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 124,
                        height: 124,
                        decoration: const BoxDecoration(
                            color: AppColors.primarySoft, shape: BoxShape.circle),
                        child: Center(
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: const BoxDecoration(
                                color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.check, size: 44, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text('Job accepted!',
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      const SizedBox(height: 14),
                      const Text("You're confirmed for this job.",
                          style:
                              TextStyle(fontSize: 18, height: 1.6, color: AppColors.muted)),
                      const Text('You can find it in My jobs anytime.',
                          style:
                              TextStyle(fontSize: 18, height: 1.6, color: AppColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(height: 44),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(job.title,
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                          ),
                          const AppPill('Confirmed'),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 26, color: AppColors.primary),
                          const SizedBox(width: 14),
                          Text(job.duration,
                              style: const TextStyle(fontSize: 20, color: AppColors.muted)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.payments_outlined,
                              size: 26, color: AppColors.primary),
                          const SizedBox(width: 14),
                          Text('Rs. ${money(job.rate)} / day',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text)),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Center(child: AppButton('Okay', width: 220, onPressed: goToDashboard)),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

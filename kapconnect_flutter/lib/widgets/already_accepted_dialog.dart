import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

/// Pop-up shown when the worker tries to accept a second job on the same day.
Future<void> showAlreadyAcceptedDialog(
    BuildContext context, Job acceptedJob, Estate estate) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColors.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 12),
              child: InkWell(
                onTap: () => Navigator.of(ctx).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('X',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration:
                const BoxDecoration(color: AppColors.warnSoft, shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, size: 40, color: AppColors.warn),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Text(
              'Already accepted another job',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: AppColors.primarySoft, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.work_outline, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Accepted for today',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const SizedBox(height: 2),
                      Text('${acceptedJob.title} · ${estate.name}',
                          style: const TextStyle(fontSize: 16, color: AppColors.text)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

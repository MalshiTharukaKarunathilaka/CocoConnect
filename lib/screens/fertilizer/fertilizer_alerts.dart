import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// Bell in the fertilizer header — opens estate alerts from suppliers.
class FertAlertBell extends StatelessWidget {
  const FertAlertBell({super.key});

  @override
  Widget build(BuildContext context) {
    final store = FertilizerStore.instance;
    return ValueListenableBuilder<int>(
      valueListenable: store.ownerAlertTick,
      builder: (context, _, __) {
        final unread = store.unreadOwnerAlerts;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => showFertOwnerAlerts(context),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread', style: const TextStyle(fontSize: 10)),
            child: Icon(
              unread > 0
                  ? Icons.notifications_active
                  : Icons.notifications_none,
              color: kOwnerGreen,
              size: 22,
            ),
          ),
        );
      },
    );
  }
}

Future<void> showFertOwnerAlerts(BuildContext context) async {
  final store = FertilizerStore.instance;
  store.markOwnerAlertsRead();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final alerts = store.ownerAlerts;
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFFCF8EF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Alerts when a supplier accepts, cancels, negotiates, or delivers your order.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ),
              Expanded(
                child: alerts.isEmpty
                    ? const Center(
                        child: Text(
                          'No alerts yet.',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _AlertTile(alerts[i]),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AlertTile extends StatelessWidget {
  const _AlertTile(this.alert);
  final FertOwnerAlert alert;

  Color get _accent {
    switch (alert.kind) {
      case 'accepted':
      case 'delivered':
        return AppColors.green;
      case 'cancelled':
        return AppColors.dangerText;
      case 'negotiating':
        return AppColors.warning;
      default:
        return AppColors.muted;
    }
  }

  IconData get _icon {
    switch (alert.kind) {
      case 'accepted':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'negotiating':
        return Icons.forum_outlined;
      case 'delivered':
        return Icons.local_shipping_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _accent.withValues(alpha: 0.12),
            child: Icon(_icon, size: 18, color: _accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alert.body,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  shortDate(alert.at),
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

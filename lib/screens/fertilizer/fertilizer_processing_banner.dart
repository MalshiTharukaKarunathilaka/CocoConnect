import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'fertilizer_data.dart';

/// Friendly label instead of raw "Pending Ack".
String fertStatusLabel(String status) {
  switch (status) {
    case 'Pending Ack':
    case 'Submitted':
    case 'Processing':
      return 'Pending';
    case 'Negotiating':
      return 'In talk';
    case 'Accepted':
      return 'Accepted';
    case 'Cancelled':
      return 'Cancelled';
    case 'Disputed':
      return 'Disputed';
    case 'Distributed':
      return 'Delivered';
    default:
      return status;
  }
}

Color fertStatusColor(String status) {
  switch (status) {
    case 'Pending Ack':
    case 'Negotiating':
      return AppColors.dangerText;
    case 'Accepted':
    case 'Distributed':
      return AppColors.green;
    case 'Cancelled':
    case 'Disputed':
      return AppColors.dangerText;
    default:
      return AppColors.muted;
  }
}

/// Small interactive strip: order placed and waiting on the supplier.
class FertProcessingBanner extends StatefulWidget {
  const FertProcessingBanner({super.key, this.onOpenOrders});

  final VoidCallback? onOpenOrders;

  @override
  State<FertProcessingBanner> createState() => _FertProcessingBannerState();
}

class _FertProcessingBannerState extends State<FertProcessingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = FertilizerStore.instance;
    return ValueListenableBuilder<int>(
      valueListenable: store.ownerAlertTick,
      builder: (context, _, __) {
        final pending = store
            .ownerOrders('Your Estate')
            .where(
              (o) =>
                  o.status == 'Pending Ack' || o.status == 'Negotiating',
            )
            .toList();
        if (pending.isEmpty) return const SizedBox.shrink();
        final o = pending.first;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onOpenOrders,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  FadeTransition(
                    opacity: Tween(begin: 0.45, end: 1.0).animate(_pulse),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_top,
                        size: 18,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order placed · processing',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${o.company} · ${o.id} · waiting for supplier',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tiny status chip next to the avatar on an order card.
class FertOrderStatusDot extends StatelessWidget {
  const FertOrderStatusDot({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final c = fertStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == 'Pending Ack'
                ? Icons.autorenew
                : (status == 'Accepted'
                    ? Icons.check_circle
                    : Icons.circle),
            size: 11,
            color: c,
          ),
          const SizedBox(width: 3),
          Text(
            fertStatusLabel(status),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

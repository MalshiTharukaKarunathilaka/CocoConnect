import '../../widgets/mobile_sheet.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owner_widgets.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';
import 'fertilizer_dispute_sheet.dart';
import 'fertilizer_order_edit_sheet.dart';
import 'fertilizer_processing_banner.dart';
import 'fertilizer_receipt_rating.dart';

/// Bell in the fertilizer header — land, supplier, or CDO alerts.
class FertAlertBell extends StatelessWidget {
  const FertAlertBell({
    super.key,
    this.forSupplier = false,
    this.forCdo = false,
    this.onOpenStock,
    this.onOpenOrders,
  });

  final bool forSupplier;
  final bool forCdo;
  final VoidCallback? onOpenStock;
  final VoidCallback? onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final store = FertilizerStore.instance;
    final tick = forCdo
        ? store.cdoAlertTick
        : forSupplier
        ? store.supplierAlertTick
        : store.ownerAlertTick;
    return ValueListenableBuilder<int>(
      valueListenable: tick,
      builder: (context, _, __) {
        final unread = forCdo
            ? store.unreadCdoAlerts
            : forSupplier
            ? store.unreadSupplierAlerts
            : store.unreadOwnerAlerts;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => showFertAlerts(
            context,
            forSupplier: forSupplier,
            forCdo: forCdo,
            onOpenStock: onOpenStock,
            onOpenOrders: onOpenOrders,
          ),
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

Future<void> showFertOwnerAlerts(BuildContext context) =>
    showFertAlerts(context, forSupplier: false);

Future<void> showFertAlerts(
  BuildContext context, {
  required bool forSupplier,
  bool forCdo = false,
  VoidCallback? onOpenStock,
  VoidCallback? onOpenOrders,
}) async {
  final store = FertilizerStore.instance;
  if (forCdo) {
    store.markCdoAlertsRead();
  } else if (forSupplier) {
    store.markSupplierAlertsRead();
  } else {
    store.markOwnerAlertsRead();
  }

  await showModalBottomSheet<void>(
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: mobileSheetBuilder((ctx) {
      // Why: supplier/CDO bells only list alerts that need quick attention.
      final alerts = forCdo
          ? store.importantCdoAlerts
          : forSupplier
          ? store.importantSupplierAlerts
          : store.ownerAlerts;
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          child: Material(
            color: const Color(0xFFFCF8EF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      forCdo
                          ? 'Land cancel / dispute and low-stock alerts. Tap Show to open the page.'
                          : forSupplier
                          ? 'New orders, disputes and low-stock alerts. Tap Show to open the page.'
                          : 'Supplier updates on your orders. Tap Show to open details.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => _AlertTile(
                              alerts[i],
                              forSupplier: forSupplier,
                              forCdo: forCdo,
                              onCloseSheet: () => Navigator.pop(ctx),
                              onOpenStock: onOpenStock,
                              onOpenOrders: onOpenOrders,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }),
  );
}

Future<void> _openOrderFromAlert(
  BuildContext context, {
  required FertOwnerAlert alert,
  required bool forSupplier,
}) async {
  if (alert.orderId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No linked order on this alert.')),
    );
    return;
  }
  FertOrder? order;
  for (final o in FertilizerStore.instance.orders) {
    if (o.id == alert.orderId) {
      order = o;
      break;
    }
  }
  if (order == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order ${alert.orderId} not found.')),
    );
    return;
  }
  final o = order;
  await showModalBottomSheet<void>(
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: mobileSheetBuilder((sheetContext) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Material(
            color: AppColors.cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            o.id,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                        FertOrderStatusDot(status: o.status),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Text(
                      '${o.company} · ${o.owner}',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    for (final l in o.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${l.item.name} · ${l.qty50} × 50 kg · ${rupees(l.lineTotal)}',
                        ),
                      ),
                    Text(
                      'Total ${rupees(o.price)} · ${shortDate(o.preferredDate)} · ${o.slot}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (o.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        o.message,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 14),
                    if (!forSupplier &&
                        (o.status == 'Pending Ack' ||
                            o.status == 'Negotiating'))
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          showModalBottomSheet<bool>(
                            useSafeArea: true,
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: mobileSheetBuilder(
                              (_) => FertilizerOrderEditSheet(order: o),
                            ),
                          );
                        },
                        child: const Text('Edit order'),
                      )
                    else if (o.awaitsOwnerConfirm ||
                        o.isCompleted ||
                        (forSupplier &&
                            (o.status == 'Accepted' || o.providerCanRate)))
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...fertDeliveryActions(
                            context: context,
                            onChanged: () {
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            },
                            order: o,
                            asOwner: !forSupplier,
                          ),
                          if (o.status == 'Accepted')
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.dangerText,
                                backgroundColor: AppColors.dangerSoft,
                              ),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                showModalBottomSheet<bool>(
                                  useSafeArea: true,
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: mobileSheetBuilder(
                                    (_) => FertilizerDisputeSheet(
                                      order: o,
                                      bySupplier: forSupplier,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Dispute'),
                            ),
                        ],
                      )
                    else
                      OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Close'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );
}

class _AlertTile extends StatelessWidget {
  const _AlertTile(
    this.alert, {
    required this.forSupplier,
    this.forCdo = false,
    required this.onCloseSheet,
    this.onOpenStock,
    this.onOpenOrders,
  });

  final FertOwnerAlert alert;
  final bool forSupplier;
  final bool forCdo;
  final VoidCallback onCloseSheet;
  final VoidCallback? onOpenStock;
  final VoidCallback? onOpenOrders;

  Color get _accent {
    switch (alert.kind) {
      case 'accepted':
      case 'delivered':
        return AppColors.green;
      case 'cancelled':
      case 'estate_dispute':
        return AppColors.dangerText;
      case 'new_order':
        return AppColors.green;
      case 'negotiating':
        return AppColors.warning;
      case 'low_stock':
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
      case 'estate_dispute':
        return Icons.cancel_outlined;
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'negotiating':
        return Icons.forum_outlined;
      case 'delivered':
        return Icons.local_shipping_outlined;
      case 'low_stock':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _show(BuildContext context) async {
    onCloseSheet();
    // Why: low-stock alerts open Stock; order alerts open Orders / Messages.
    if (alert.opensStock) {
      onOpenStock?.call();
      return;
    }
    if (alert.orderId.isNotEmpty) {
      if (forCdo) {
        // Why: CDO Show jumps into the matching Messages thread.
        FertilizerStore.instance.pendingOpenGovId = alert.orderId;
        onOpenOrders?.call();
        return;
      }
      onOpenOrders?.call();
      await _openOrderFromAlert(
        context,
        alert: alert,
        forSupplier: forSupplier,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nothing to open for this alert.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canShow = alert.opensStock || alert.orderId.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canShow ? () => _show(context) : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          shortDate(alert.at),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        if (canShow)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppColors.green,
                              backgroundColor: AppColors.greenSoft,
                            ),
                            onPressed: () => _show(context),
                            child: Text(
                              alert.opensStock ? 'Show stock' : 'Show',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

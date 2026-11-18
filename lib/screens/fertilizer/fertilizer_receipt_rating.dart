import '../../widgets/mobile_sheet.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_cancel_reasons.dart';
import 'fertilizer_data.dart';
import 'fertilizer_dispute_sheet.dart';

/// Owner confirms delivery → then mutual star ratings (mobile sheet).
Future<bool?> showFertConfirmReceipt(
  BuildContext context, {
  required String id,
  required String title,
  required String subtitle,
  required bool isGov,
}) {
  return showModalBottomSheet<bool>(
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: mobileSheetBuilder(
      (_) => _ConfirmReceiptSheet(
        id: id,
        title: title,
        subtitle: subtitle,
        isGov: isGov,
      ),
    ),
  );
}

Future<bool?> showFertRating(
  BuildContext context, {
  required String id,
  required String partnerName,
  required bool byOwner,
  required bool isGov,
}) {
  return showModalBottomSheet<bool>(
    useSafeArea: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: mobileSheetBuilder(
      (_) => _RatingSheet(
        id: id,
        partnerName: partnerName,
        byOwner: byOwner,
        isGov: isGov,
      ),
    ),
  );
}

class _ConfirmReceiptSheet extends StatelessWidget {
  const _ConfirmReceiptSheet({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.isGov,
  });

  final String id;
  final String title;
  final String subtitle;
  final bool isGov;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Material(
          color: AppColors.cream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D4F), Color(0xFF1B5E3A)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40256B45),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Did you receive the goods?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$title\n$subtitle',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    id,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        final store = FertilizerStore.instance;
                        if (isGov) {
                          store.confirmGovReceipt(id);
                        } else {
                          store.confirmOrderReceipt(id);
                        }
                        Navigator.pop(context, true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Delivery confirmed · you can rate each other now',
                            ),
                          ),
                        );
                      },
                      child: const Text('Yes, I received it'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Not yet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({
    required this.id,
    required this.partnerName,
    required this.byOwner,
    required this.isGov,
  });

  final String id;
  final String partnerName;
  final bool byOwner;
  final bool isGov;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final who = widget.byOwner ? 'supplier / CDO' : 'land';
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Material(
          color: AppColors.cream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Rate your experience',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'How was working with ${widget.partnerName}?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        IconButton(
                          onPressed: () => setState(() => _stars = i),
                          iconSize: 36,
                          icon: Icon(
                            i <= _stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: const Color(0xFFD9A441),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    _stars == 0
                        ? 'Tap a star'
                        : '$_stars star${_stars == 1 ? '' : 's'} for this $who',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _stars == 0
                          ? null
                          : () {
                              final store = FertilizerStore.instance;
                              if (widget.isGov) {
                                store.rateGovRequest(
                                  widget.id,
                                  stars: _stars,
                                  byOwner: widget.byOwner,
                                );
                              } else {
                                store.rateOrder(
                                  widget.id,
                                  stars: _stars,
                                  byOwner: widget.byOwner,
                                );
                              }
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Thanks · $_stars★ saved for ${widget.partnerName}',
                                  ),
                                ),
                              );
                            },
                      child: const Text('Submit rating'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Later'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact stars already saved on a completed order.
Widget fertRatingRow({int? fromOwner, int? fromProvider}) {
  if (fromOwner == null && fromProvider == null) {
    return const SizedBox.shrink();
  }
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (fromOwner != null)
          _chip('Land $fromOwner★', AppColors.gold, const Color(0xFFFFF6E0)),
        if (fromProvider != null)
          _chip('Provider $fromProvider★', AppColors.info, AppColors.infoSoft),
      ],
    ),
  );
}

Widget _chip(String text, Color fg, Color bg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg),
    ),
  );
}

/// Action buttons for My orders / provider cards.
List<Widget> fertDeliveryActions({
  required BuildContext context,
  required VoidCallback onChanged,
  FertOrder? order,
  FertGovRequest? gov,
  required bool asOwner,
}) {
  assert(order != null || gov != null);
  final isGov = gov != null;
  final id = isGov ? gov.id : order!.id;
  final status = isGov ? gov.status : order!.status;
  final awaits = isGov ? gov.awaitsOwnerConfirm : order!.awaitsOwnerConfirm;
  final completed = isGov ? gov.isCompleted : order!.isCompleted;
  final canOwnerRate = isGov ? gov.ownerCanRate : order!.ownerCanRate;
  final canProviderRate = isGov ? gov.providerCanRate : order!.providerCanRate;
  final partner = isGov
      ? (asOwner
            ? gov.cdo
            : (gov.estateName.isNotEmpty ? gov.estateName : gov.owner))
      : (asOwner ? order!.company : order!.owner);
  final title = isGov ? gov.fertilizer : order!.product;
  final subtitle = isGov
      ? '${gov.distributed > 0 ? gov.distributed : gov.requested} bags · ${shortDate(gov.date)}'
      : '${order!.qty50} bags · ${shortDate(order.preferredDate)}';

  final out = <Widget>[];

  if (asOwner && awaits) {
    // Why: owner can confirm OR dispute if bags are wrong / damaged / missing.
    out.add(
      ElevatedButton(
        onPressed: () async {
          final ok = await showFertConfirmReceipt(
            context,
            id: id,
            title: title,
            subtitle: subtitle,
            isGov: isGov,
          );
          if (ok == true) onChanged();
        },
        child: const Text('Confirm received'),
      ),
    );
    out.add(
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.dangerText,
          backgroundColor: AppColors.dangerSoft,
        ),
        onPressed: () async {
          if (isGov) {
            final note = await showFertCdoDisputeReasons(
              context,
              title: 'Dispute $id',
            );
            if (note == null) return;
            FertilizerStore.instance.disputeGovRequest(
              id,
              reason: note,
              byCdo: false,
            );
            onChanged();
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('$id disputed')));
            }
          } else {
            final ok = await showModalBottomSheet<bool>(
              useSafeArea: true,
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: mobileSheetBuilder(
                (_) => FertilizerDisputeSheet(order: order!),
              ),
            );
            if (ok == true) onChanged();
          }
        },
        child: const Text('Dispute'),
      ),
    );
  }

  if (asOwner && canOwnerRate) {
    out.add(
      OutlinedButton(
        onPressed: () async {
          final ok = await showFertRating(
            context,
            id: id,
            partnerName: partner,
            byOwner: true,
            isGov: isGov,
          );
          if (ok == true) onChanged();
        },
        child: const Text('Rate'),
      ),
    );
  }

  if (!asOwner &&
      (status == 'Accepted' ||
          status == 'Stock Confirmed' ||
          status == 'Receipt Confirmed')) {
    out.add(
      ElevatedButton(
        onPressed: () {
          final store = FertilizerStore.instance;
          if (isGov) {
            store.markGovDelivered(id);
          } else {
            store.markDelivered(id);
          }
          onChanged();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$id marked delivered · waiting for land confirm'),
            ),
          );
        },
        child: const Text('Mark delivered'),
      ),
    );
  }

  if (!asOwner && awaits) {
    out.add(
      const Text(
        'Waiting for land to confirm receipt',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }

  if (!asOwner && canProviderRate) {
    out.add(
      OutlinedButton(
        onPressed: () async {
          final ok = await showFertRating(
            context,
            id: id,
            partnerName: partner,
            byOwner: false,
            isGov: isGov,
          );
          if (ok == true) onChanged();
        },
        child: const Text('Rate land'),
      ),
    );
  }

  if (completed) {
    out.add(
      fertRatingRow(
        fromOwner: isGov ? gov.ratingFromOwner : order!.ratingFromOwner,
        fromProvider: isGov
            ? gov.ratingFromProvider
            : order!.ratingFromProvider,
      ),
    );
  }

  return out;
}

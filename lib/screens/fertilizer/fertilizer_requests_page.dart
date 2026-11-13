import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// My requests & messages — same idea as the HTML demo list.
class FertilizerRequestsPage extends StatelessWidget {
  const FertilizerRequestsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final store = FertilizerStore.instance;
    final private = store.ownerOrders('Your Estate');
    final gov = store.govRequests
        .where((r) => r.owner == 'Your Estate')
        .toList();

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        const Text(
          'ESTATE OWNER',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.green,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'My requests & messages',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Private supplier requests and government programme requests stay in one place.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        const Text(
          'Private supplier requests',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'These go to the shop you picked on the map.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        if (private.isEmpty)
          _empty('No private orders yet. Open the map and tap a pin.')
        else
          for (final o in private) _privateCard(o),
        const SizedBox(height: 22),
        const Text(
          'Government programme',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Reviewed by the CDO for your demo cultivation area.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        if (gov.isEmpty)
          _empty('No government requests yet.')
        else
          for (final r in gov) _govCard(r),
      ],
    );

    if (embedded) return ColoredBox(color: AppColors.cream, child: body);
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: const Text('My requests')),
      body: body,
    );
  }

  Widget _empty(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.callout),
          border: Border.all(color: AppColors.line),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
      );

  Widget _privateCard(FertOrder o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  o.product,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              StatusPill.forStatus(o.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${o.company} · ${o.qty50} bags · preferred ${shortDate(o.preferredDate)} · ${o.slot}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Text(
            rupees(o.price),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _govCard(FertGovRequest r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.fertilizer,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              StatusPill.forStatus(r.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${r.id} · ${r.requested} bags · ${r.cdo}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

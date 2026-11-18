import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_cancel_reasons.dart';
import 'fertilizer_data.dart';

/// CDO reads the land Annex 01 application.
/// Pending → Accept / Cancel. Accepted → Delivered / Dispute.
class FertilizerCdoRequestSheet extends StatelessWidget {
  const FertilizerCdoRequestSheet({super.key, required this.request});

  final FertGovRequest request;

  bool get _canDecide =>
      request.status == 'Pending Ack' || request.status == 'Submitted';

  bool get _canDeliverOrDispute =>
      request.status == 'Accepted' || request.status == 'Receipt Confirmed';

  @override
  Widget build(BuildContext context) {
    final r = request;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Material(
          color: AppColors.cream,
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.id,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                      StatusPill.forStatus(r.status),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _canDecide
                          ? 'Land application form · review, then accept or cancel'
                          : (_canDeliverOrDispute
                                ? 'Accepted application · mark delivered or dispute'
                                : 'Land application form'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _formCard(r),
                      const SizedBox(height: 12),
                      _docsCard(r),
                    ],
                  ),
                ),
                if (_canDecide)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.dangerText,
                              backgroundColor: AppColors.dangerSoft,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () async {
                              final note = await showFertCancelReasons(
                                context,
                                title: 'Cancel ${r.id}',
                                forCdo: true,
                              );
                              if (note == null) return;
                              FertilizerStore.instance.cancelGovRequest(
                                r.id,
                                note: note,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${r.id} cancelled')),
                              );
                            },
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              FertilizerStore.instance.acceptGovRequest(r.id);
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${r.id} accepted')),
                              );
                            },
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_canDeliverOrDispute)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              FertilizerStore.instance.markGovDelivered(r.id);
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${r.id} marked delivered'),
                                ),
                              );
                            },
                            child: const Text('Delivered'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.dangerText,
                              backgroundColor: AppColors.dangerSoft,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () async {
                              final note = await showFertCdoDisputeReasons(
                                context,
                                title: 'Dispute ${r.id}',
                              );
                              if (note == null) return;
                              FertilizerStore.instance.disputeGovRequest(
                                r.id,
                                reason: note,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${r.id} disputed')),
                              );
                            },
                            child: const Text('Dispute'),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottom),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard(FertGovRequest r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Coconut Cultivation Board',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Annex 01 · RH/AGRI/CCB/01',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Application for Obtaining Fertilizer',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
          ),
          const SizedBox(height: 12),
          _row('Request', r.fertilizer),
          _row('Bags requested', '${r.requested} × 50 kg'),
          _row('Outlet', r.outlet.isEmpty ? r.cdo : r.outlet),
          if (r.preferred.isNotEmpty) _row('Preferred slot', r.preferred),
          _row('Submitted', shortDate(r.date)),
          const Divider(height: 22),
          const Text(
            '1 · Beneficiary',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _row('Full name', _orDash(r.beneficiaryName, r.owner)),
          _row('Address', _orDash(r.address)),
          _row('Phone', _orDash(r.phone)),
          _row('NIC number', _orDash(r.nicNumber)),
          const SizedBox(height: 10),
          const Text(
            '2 · Coconut land',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _row('Land', _orDash(r.estateName, r.owner)),
          _row('Land address', _orDash(r.landAddress)),
          _row('Deed number', _orDash(r.deedNumber)),
          _row('District', r.district),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Acres', r.acres > 0 ? _num(r.acres) : '—'),
              _chip('Roods', '${r.roods}'),
              _chip('Perches', '${r.perches}'),
              _chip('Trees', '${r.coconutTrees}'),
              _chip('Saplings', '${r.coconutSaplings}'),
              _chip('Nuts / year', '${r.annualHarvestNuts}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _docsCard(FertGovRequest r) {
    final hasNic = r.nicCopy.isNotEmpty;
    final hasTitle = r.landTitleCopy.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3 · Uploaded documents',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (!hasNic && !hasTitle)
            const Text(
              'No file names stored on this sample request.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5),
            )
          else ...[
            if (hasNic) _docTile('NIC copy', r.nicCopy),
            if (hasTitle) ...[
              if (hasNic) const SizedBox(height: 8),
              _docTile('Land title / deed', r.landTitleCopy),
            ],
          ],
        ],
      ),
    );
  }

  Widget _docTile(String label, String fileName) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: AppColors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  fileName,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1EA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _orDash(String value, [String fallback = '']) {
    if (value.trim().isNotEmpty) return value.trim();
    if (fallback.trim().isNotEmpty) return fallback.trim();
    return '—';
  }

  String _num(double v) => v % 1 == 0 ? '${v.toInt()}' : '$v';
}

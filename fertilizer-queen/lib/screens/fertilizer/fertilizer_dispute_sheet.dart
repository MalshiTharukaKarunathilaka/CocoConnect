import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../buyer/buyer_format.dart';
import 'fertilizer_data.dart';

/// Estate files a dispute on an accepted order (goes to Complaints / disputes).
class FertilizerDisputeSheet extends StatefulWidget {
  const FertilizerDisputeSheet({
    super.key,
    required this.order,
    this.bySupplier = false,
  });

  final FertOrder order;
  /// Supplier can also dispute (estate no-show, payment issue, etc.).
  final bool bySupplier;

  @override
  State<FertilizerDisputeSheet> createState() => _FertilizerDisputeSheetState();
}

class _FertilizerDisputeSheetState extends State<FertilizerDisputeSheet> {
  late String _reason;
  final _desc = TextEditingController();

  List<String> get _reasons => widget.bySupplier
      ? const [
          'Estate cancelled after accept',
          'Estate unreachable / no-show',
          'Payment dispute',
          'Wrong address / location',
          'Buyer changed quantity late',
          'Other commercial issue',
        ]
      : const [
          'Wrong quantity delivered',
          'Wrong product / brand',
          'Poor quality fertilizer',
          'Late or no delivery',
          'Damaged bags',
          'Billing / price mismatch',
        ];

  @override
  void initState() {
    super.initState();
    _reason = _reasons.first;
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  void _submit() {
    if (_desc.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the dispute')),
      );
      return;
    }
    final o = widget.order;
    final store = FertilizerStore.instance;
    final who = widget.bySupplier ? 'Supplier' : 'Estate';
    store.addComplaint(
      FertComplaint(
        id: 'DP-${300 + store.complaints.length + 1}',
        category: 'Dispute · $who · $_reason',
        product: o.product,
        status: 'Submitted',
        date: DateTime.now(),
        description: '${o.id} · ${o.company}\n${_desc.text.trim()}',
        owner: 'Your Estate',
        district: 'Kurunegala',
      ),
    );
    if (widget.bySupplier) {
      store.notifyOwner(
        title: 'Supplier dispute on ${o.id}',
        body: '$_reason · ${o.company}',
        kind: 'cancelled',
        orderId: o.id,
      );
      store.notifySupplier(
        title: 'Dispute filed for ${o.id}',
        body: _reason,
        kind: 'info',
        orderId: o.id,
      );
    } else {
      store.notifyOwner(
        title: 'Dispute filed for ${o.id}',
        body: '$_reason · ${o.company}',
        kind: 'info',
        orderId: o.id,
      );
      store.notifySupplier(
        title: 'Estate dispute on ${o.id}',
        body: '$_reason · ${o.owner}',
        kind: 'cancelled',
        orderId: o.id,
      );
    }
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.bySupplier
              ? 'Dispute sent · estate will see this'
              : 'Dispute sent · see Complaints',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: Material(
            color: AppColors.cream,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'File a dispute',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dangerText,
                      ),
                    ),
                    Text(
                      '${o.id} · ${o.company} · ${rupees(o.price)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Reason',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _reason,
                      isExpanded: true,
                      items: [
                        for (final r in _reasons)
                          DropdownMenuItem(value: r, child: Text(r)),
                      ],
                      onChanged: (v) =>
                          setState(() => _reason = v ?? _reason),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _desc,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'What went wrong?',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.dangerText,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _submit,
                      child: const Text('Submit dispute'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

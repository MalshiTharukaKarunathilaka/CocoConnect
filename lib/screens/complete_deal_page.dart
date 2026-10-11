import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/activity_service.dart';
import '../services/api_client.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';
import 'buyer/coconut_type.dart';

/// Opens the Complete Deal form for an order. Returns true when the deal
/// was completed so the caller can refresh.
Future<bool> openCompleteDeal(BuildContext context, int orderId) async {
  final bool? done = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (context) => CompleteDealPage(orderId: orderId)),
  );
  return done == true;
}

/// The estate owner records what was actually delivered. A final price
/// different from the agreed one is flagged for admin approval; the agreed
/// price stays protected until then.
class CompleteDealPage extends StatefulWidget {
  final int orderId;

  const CompleteDealPage({super.key, required this.orderId});

  @override
  State<CompleteDealPage> createState() => _CompleteDealPageState();
}

class _CompleteDealPageState extends State<CompleteDealPage> {
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _noteController = TextEditingController();

  late Future<OrderItem> _deal = _find();
  bool _saving = false;
  bool _flagged = false;
  String? _quantityError;
  String? _priceError;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<OrderItem> _find() async {
    final OrderItem? deal = await ActivityService.findOrder(widget.orderId);
    if (deal == null) throw const ApiException('This deal was not found');
    return deal;
  }

  double? get _price => double.tryParse(_priceController.text.trim());

  /// Final price minus the agreed one; null until a price is typed.
  double? _difference(OrderItem deal) {
    final double? price = _price;
    if (price == null || price <= 0) return null;
    final double diff = price - deal.pricePerUnit;
    return diff.abs() < 0.001 ? 0 : diff;
  }

  String _signed(double diff) =>
      '${diff > 0 ? '+' : '-'}${rupees(diff.abs())}/nut';

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: error ? kOwnerRed : kOwnerGreen,
        ),
      );
  }

  Future<void> _submit(OrderItem deal) async {
    final int? quantity = int.tryParse(_quantityController.text.trim());
    final double? price = _price;

    setState(() {
      _quantityError = quantity == null || quantity <= 0
          ? 'Enter the actual number of nuts'
          : null;
      _priceError = price == null || price <= 0
          ? 'Enter the final price per coconut'
          : null;
    });
    if (_quantityError != null || _priceError != null) return;

    final double diff = _difference(deal) ?? 0;
    if (diff != 0 && !_flagged) {
      _snack(
        'The price differs from the agreed ${rupees(deal.pricePerUnit)}. '
        'Tap Request to flag it for admin approval first.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ActivityService.completeDeal(
        deal.id,
        deliveredQuantity: quantity!,
        finalPricePerUnit: price!,
        requestPriceReview: diff != 0,
        disputeNote: _noteController.text.trim(),
      );
      if (!mounted) return;
      _snack(
        diff == 0
            ? 'Deal completed: ${withCommas(quantity)} nuts, total '
                  '${rupees(quantity * price)}'
            : 'Deal completed. ${rupees(price)}/nut sent for admin approval; '
                  '${rupees(deal.pricePerUnit)}/nut applies until then.',
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) _snack(error.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      child: FutureBuilder<OrderItem>(
        future: _deal,
        builder: (context, snapshot) {
          final OrderItem? deal = snapshot.data;
          return Column(
            children: [
              _Header(reference: deal?.reference),
              Expanded(child: _body(snapshot)),
            ],
          );
        },
      ),
    );
  }

  Widget _body(AsyncSnapshot<OrderItem> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator(color: kOwnerGreen));
    }
    if (snapshot.hasError) {
      final Object error = snapshot.error!;
      return OwnerMessage(
        icon: Icons.cloud_off_outlined,
        text: error is ApiException ? error.message : 'Could not load',
        onRetry: () {
          setState(() {
            _deal = _find();
          });
        },
      );
    }
    final OrderItem deal = snapshot.data!;
    if (deal.isCompleted) {
      return const OwnerMessage(
        icon: Icons.verified_outlined,
        text: 'This deal is already completed.',
      );
    }

    final double? diff = _difference(deal);
    final bool differs = diff != null && diff != 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _AgreementCard(deal: deal),
        const SizedBox(height: 14),
        OwnerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ACTUAL FULFILLMENT',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.bold,
                  color: kOwnerGreen,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Enter actual quantities and final settled rates',
                style: TextStyle(fontSize: 12.5, color: kOwnerMuted),
              ),
              const SizedBox(height: 16),
              _label('Actual Deal Quantity(nuts)'),
              const SizedBox(height: 8),
              _Field(
                controller: _quantityController,
                hint: 'e.g. ${deal.quantity}',
                error: _quantityError,
                enabled: !_saving,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _label('Final Price per Coconut (Rs.)')),
                  Text(
                    'Agreed: ${rupees(deal.pricePerUnit)}',
                    style: const TextStyle(fontSize: 12, color: kOwnerMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _Field(
                controller: _priceController,
                hint: deal.pricePerUnit.toStringAsFixed(0),
                prefix: 'Rs. ',
                error: _priceError,
                enabled: !_saving,
                warn: differs,
                chip: differs ? _signed(diff) : null,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                onChanged: (_) => setState(() {
                  _flagged = false;
                }),
              ),
              if (differs) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, size: 15, color: kOwnerRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Entered price differs from agreed '
                        '${rupees(deal.pricePerUnit)} (${_signed(diff)} '
                        'adjustment)',
                        style: const TextStyle(fontSize: 12, color: kOwnerRed),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (differs) ...[
          const SizedBox(height: 14),
          _DisputePanel(
            agreed: deal.pricePerUnit,
            requested: _price!,
            diff: diff,
            flagged: _flagged,
            busy: _saving,
            noteController: _noteController,
            onRequest: () => setState(() => _flagged = !_flagged),
          ),
        ],
        const SizedBox(height: 20),
        OwnerPrimaryButton(
          label: _saving ? 'Completing...' : 'Complete Deal',
          onPressed: _saving || (differs && !_flagged)
              ? null
              : () => _submit(deal),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: kOwnerMuted,
              side: const BorderSide(color: Color(0xFFCFCFCF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel & Return to Deals'),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text.rich(
    TextSpan(
      text: text,
      children: const [
        TextSpan(
          text: ' *',
          style: TextStyle(color: kOwnerRed),
        ),
      ],
    ),
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.bold,
      color: kOwnerInk,
    ),
  );
}

class _Header extends StatelessWidget {
  final String? reference;

  const _Header({required this.reference});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEDE7DA))),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: kOwnerBorder)),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: kOwnerInk, size: 20),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete Deal',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kOwnerInk,
                  ),
                ),
                if (reference != null)
                  Text(
                    'Deal #$reference',
                    style: const TextStyle(fontSize: 12, color: kOwnerMuted),
                  ),
              ],
            ),
          ),
          const OwnerPill('Estate Owner'),
        ],
      ),
    );
  }
}

class _AgreementCard extends StatelessWidget {
  final OrderItem deal;

  const _AgreementCard({required this.deal});

  @override
  Widget build(BuildContext context) {
    final int? days = deal.daysUntilDue;
    final String when = switch (days) {
      null => '',
      0 => ' (Today)',
      1 => ' (Tomorrow)',
      < 0 => ' (Overdue)',
      _ => '',
    };

    Widget column(String label, String value, {String? unit}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: kOwnerMuted),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: kOwnerMuted,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: kOwnerGreen,
            ),
          ),
        ],
      ),
    );

    return OwnerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'ORIGINAL AGREEMENT',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.bold,
                    color: kOwnerGreen,
                  ),
                ),
              ),
              OwnerPill('Confirmed', icon: Icons.check_circle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            deal.counterpartName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: kOwnerInk,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Icon(Icons.circle, size: 7, color: kOwnerGreen),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${CoconutType.fromCode(deal.productType).label}'
                  '${deal.dueDate == null ? '' : ' · Due: ${shortDate(deal.dueDate)}$when'}',
                  style: const TextStyle(fontSize: 13, color: kOwnerMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: kOwnerPanel,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                column(
                  'Agreed Quantity',
                  withCommas(deal.quantity),
                  unit: ' nuts',
                ),
                column('Agreed Price', rupees(deal.pricePerUnit), unit: '/nut'),
                column('Original Total', rupees(deal.totalValue)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final String? error;
  final String? chip;
  final bool warn;
  final bool enabled;
  final TextInputType keyboard;
  final List<TextInputFormatter> formatters;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.keyboard,
    required this.formatters,
    this.prefix,
    this.error,
    this.chip,
    this.warn = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color border = warn ? kOwnerRed : kOwnerBorder;
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      inputFormatters: formatters,
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: warn ? kOwnerRed : kOwnerInk,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        prefixStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: warn ? kOwnerRed : kOwnerInk,
        ),
        errorText: error,
        filled: true,
        fillColor: warn ? const Color(0xFFFDF0F0) : const Color(0xFFF5F4F1),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        suffixIcon: chip == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBDADA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    chip!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: kOwnerRed,
                    ),
                  ),
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minHeight: 0, minWidth: 0),
        border: outline(border),
        enabledBorder: outline(border, warn ? 1.6 : 1),
        focusedBorder: outline(warn ? kOwnerRed : kOwnerGreen, 1.6),
        disabledBorder: outline(border),
      ),
    );
  }
}

class _DisputePanel extends StatelessWidget {
  final double agreed;
  final double requested;
  final double diff;
  final bool flagged;
  final bool busy;
  final TextEditingController noteController;
  final VoidCallback onRequest;

  const _DisputePanel({
    required this.agreed,
    required this.requested,
    required this.diff,
    required this.flagged,
    required this.busy,
    required this.noteController,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final String change = diff > 0 ? 'increased' : 'reduced';
    final String signed = '${diff > 0 ? '+' : '-'}${rupees(diff.abs())}/nut';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF2B8B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFBDADA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: kOwnerRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Text(
                            'Price Dispute — Pending Admin Approval',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: kOwnerRed,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: flagged
                                ? kOwnerGreenSoft
                                : const Color(0xFFFBDADA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            flagged ? 'REQUESTED' : 'ACTION REQUIRED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: flagged ? kOwnerGreen : kOwnerRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Price $change from ${rupees(agreed)} to '
                      '${rupees(requested)} ($signed).',
                      style: const TextStyle(fontSize: 13, color: kOwnerInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF5CFCF)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flag Dispute & Request Admin Approval',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: kOwnerInk,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Admin will review buyer grading notes & gate '
                            'adjustments',
                            style: TextStyle(fontSize: 12, color: kOwnerMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: busy ? null : onRequest,
                      icon: Icon(flagged ? Icons.check : Icons.gavel, size: 16),
                      label: Text(flagged ? 'Requested' : 'Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: flagged
                            ? kOwnerGreenSoft
                            : kOwnerGreen,
                        foregroundColor: flagged ? kOwnerGreen : Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                if (flagged) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    enabled: !busy,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Reason for the admin (optional)',
                      hintText: 'e.g. Buyer graded the lot as premium',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Submitted price will be reviewed by CocoConnect Admin. The '
            'original rate of ${rupees(agreed)}/nut remains protected until '
            'Admin approves the revised price.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: kOwnerMuted,
            ),
          ),
        ],
      ),
    );
  }
}

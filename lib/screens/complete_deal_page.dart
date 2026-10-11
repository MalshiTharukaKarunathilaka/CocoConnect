import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/owner_service.dart';
import '../widgets/owner_widgets.dart';
import 'buyer/buyer_format.dart';

/// Opens the Complete Deal form for an order. Returns true when the deal
/// was completed so the caller can refresh.
Future<bool> openCompleteDeal(BuildContext context, int orderId) async {
  final bool? done = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (context) => CompleteDealPage(orderId: orderId)),
  );
  return done == true;
}

/// The estate owner records what was actually delivered against what was
/// agreed, which closes the deal.
class CompleteDealPage extends StatefulWidget {
  final int orderId;

  const CompleteDealPage({super.key, required this.orderId});

  @override
  State<CompleteDealPage> createState() => _CompleteDealPageState();
}

class _CompleteDealPageState extends State<CompleteDealPage> {
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  late Future<Deal> _deal = _find();
  bool _saving = false;
  String? _quantityError;
  String? _priceError;

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<Deal> _find() async {
    final List<Deal> deals = await OwnerService.getDeals();
    for (final Deal deal in deals) {
      if (deal.id == widget.orderId) return deal;
    }
    throw const ApiException('This deal was not found');
  }

  Future<void> _submit(Deal deal) async {
    final int? quantity = int.tryParse(_quantityController.text.trim());
    final double? price = double.tryParse(_priceController.text.trim());

    setState(() {
      _quantityError = quantity == null || quantity <= 0
          ? 'Enter the number of nuts delivered'
          : null;
      _priceError = price == null || price <= 0
          ? 'Enter the final price per nut'
          : null;
    });
    if (_quantityError != null || _priceError != null) return;

    setState(() => _saving = true);
    try {
      await OwnerService.completeDeal(
        deal.id,
        deliveredQuantity: quantity!,
        finalPricePerUnit: price!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deal completed: ${withCommas(quantity)} nuts, total '
            '${rupees(quantity * price)}',
          ),
          backgroundColor: kOwnerGreen,
        ),
      );
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: kOwnerRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OwnerPage(
      child: Column(
        children: [
          const OwnerHeader(title: 'Complete Deal'),
          Expanded(
            child: FutureBuilder<Deal>(
              future: _deal,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: kOwnerGreen),
                  );
                }
                if (snapshot.hasError) {
                  final Object error = snapshot.error!;
                  return OwnerMessage(
                    icon: Icons.cloud_off_outlined,
                    text: error is ApiException
                        ? error.message
                        : 'Could not load',
                    onRetry: () {
                      setState(() {
                        _deal = _find();
                      });
                    },
                  );
                }
                return _buildForm(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(Deal deal) {
    if (deal.isCompleted) {
      return const OwnerMessage(
        icon: Icons.verified_outlined,
        text: 'This deal is already completed.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Text(
          '#${deal.reference}  ·  ${deal.buyerName}',
          style: const TextStyle(fontSize: 12.5, color: kOwnerMuted),
        ),
        const SizedBox(height: 10),
        _sectionTitle('Original Agreement'),
        const SizedBox(height: 10),
        OwnerCard(
          child: Column(
            children: [
              _agreementRow(
                'Agreed Quantity',
                '${withCommas(deal.quantity)} nuts',
              ),
              const Divider(height: 22, color: kOwnerBorder),
              _agreementRow(
                'Agreed Price',
                '${rupees(deal.pricePerUnit)} / nut',
              ),
              const Divider(height: 22, color: kOwnerBorder),
              _agreementRow(
                'Total Agreed',
                rupees(deal.totalValue),
                strong: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _sectionTitle('Actual Fulfillment'),
        const SizedBox(height: 4),
        const Text(
          'Enter what was actually delivered and paid.',
          style: TextStyle(fontSize: 12.5, color: kOwnerMuted),
        ),
        const SizedBox(height: 14),
        _field(
          label: 'Actual Quantity Delivered',
          controller: _quantityController,
          hint: 'e.g. ${deal.quantity}',
          suffix: 'nuts',
          error: _quantityError,
          formatters: [FilteringTextInputFormatter.digitsOnly],
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 16),
        _field(
          label: 'Final Price per Nut',
          controller: _priceController,
          hint: 'Agreed: ${rupees(deal.pricePerUnit)}',
          prefix: 'Rs. ',
          error: _priceError,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          keyboard: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 28),
        OwnerPrimaryButton(
          label: _saving ? 'Completing...' : 'Complete Deal',
          onPressed: _saving ? null : () => _submit(deal),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: kOwnerInk,
              side: const BorderSide(color: Color(0xFFBDBDBD)),
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

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: kOwnerInk,
    ),
  );

  Widget _agreementRow(String label, String value, {bool strong = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13.5, color: kOwnerMuted),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 17 : 14.5,
            fontWeight: FontWeight.bold,
            color: strong ? kOwnerGreen : kOwnerInk,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required List<TextInputFormatter> formatters,
    required TextInputType keyboard,
    String? prefix,
    String? suffix,
    String? error,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: kOwnerRed),
              ),
            ],
          ),
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: kOwnerInk,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: formatters,
          enabled: !_saving,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            suffixText: suffix,
            errorText: error,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: border(kOwnerBorder),
            enabledBorder: border(kOwnerBorder),
            focusedBorder: border(kOwnerGreen),
          ),
        ),
      ],
    );
  }
}

import '../theme/app_theme.dart';
import '../widgets/role_navigation_page.dart';
import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/owner_service.dart';
import 'chat/chat_page.dart';

class SellRequestPage extends StatefulWidget {
  final int buyerId;
  final String buyerName;
  final String location;
  final int requestedQuantity;
  final String requiredDate;
  final String productType;
  final double buyerBiddingPrice;
  final double sellerOfferPricePerUnit;

  const SellRequestPage({
    super.key,
    required this.buyerId,
    required this.buyerName,
    required this.location,
    required this.requestedQuantity,
    required this.requiredDate,
    required this.productType,
    required this.buyerBiddingPrice,
    required this.sellerOfferPricePerUnit,
  });

  @override
  State<SellRequestPage> createState() => _SellRequestPageState();
}

class _SellRequestPageState extends State<SellRequestPage> {
  late final TextEditingController quantityController;
  late final TextEditingController offerPriceController;
  String? paymentMethod;

  @override
  void initState() {
    super.initState();

    quantityController = TextEditingController(
      text: widget.requestedQuantity.toString(),
    );

    offerPriceController = TextEditingController(
      text: widget.sellerOfferPricePerUnit.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    offerPriceController.dispose();
    super.dispose();
  }

  bool sending = false;

  bool get usesUnits => widget.productType.toUpperCase() == 'COCONUT_HUSK';
  String get quantityPlural => usesUnits ? 'units' : 'nuts';
  String get priceUnit => usesUnits ? 'unit' : 'nut';

  /// Saves the offer; the buyer sees it under My Activity > Requests.
  Future<void> sendOffer() async {
    final int? quantity = int.tryParse(
      quantityController.text.replaceAll(',', '').trim(),
    );
    final double? price = double.tryParse(
      offerPriceController.text
          .replaceAll('Rs.', '')
          .replaceAll('Rs', '')
          .replaceAll(',', '')
          .trim(),
    );
    if (quantity == null || quantity <= 0 || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter a quantity and a price per $priceUnit')),
      );
      return;
    }
    if (paymentMethod == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a payment method')));
      return;
    }

    setState(() => sending = true);
    try {
      final int? chatId = await OwnerService.sendOffer(
        buyerRequestId: widget.buyerId,
        quantity: quantity,
        pricePerUnit: price,
        paymentMethod: paymentMethod!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offer sent to ${widget.buyerName}'),
          backgroundColor: const Color(0xFF1F6B3D),
        ),
      );
      if (chatId == null) {
        Navigator.pop(context);
        return;
      }
      // The offer starts a chat with the buyer - continue there.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(chatId: chatId)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  String get productName {
    return switch (widget.productType.toUpperCase()) {
      'RAW_COCONUT' => 'Raw Coconuts(with husks)',
      'DEHUSKED_COCONUT' => 'Dehusked Coconut',
      'COCONUT_HUSK' => 'Only Husks',
      _ => widget.productType,
    };
  }

  double get totalValue {
    return widget.requestedQuantity * widget.sellerOfferPricePerUnit;
  }

  @override
  Widget build(BuildContext context) {
    return RoleNavigationPage(
      current: AppTab.dashboard,
      child: Scaffold(
        backgroundColor: const Color(0xFFEFEFEF),
        body: Center(
          child: Container(
            width: 390,
            height: double.infinity,
            color: const Color(0xFFFCF8EF),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1B5E20),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: const Text(
                          'Send Sell Request',
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Buyer details card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                'https://images.unsplash.com/photo-1580984969071-a8da5656c2fb?auto=format&fit=crop&w=300&q=80',
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 62,
                                    height: 62,
                                    color: const Color(0xFFE8F5E9),
                                    child: const Icon(
                                      Icons.image,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.buyerName,
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontSize: 23,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Requesting for\n$productName',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF3A3A3A),
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: Color(0xFFB26A2C),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          widget.location,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFB26A2C),
                                            height: 1.2,
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

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: RequestInfoItem(
                                title: 'QUANTITY',
                                value:
                                    '${widget.requestedQuantity} $quantityPlural',
                              ),
                            ),
                            Expanded(
                              child: RequestInfoItem(
                                title: 'REQUIRED DATE',
                                value: widget.requiredDate,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: RequestInfoItem(
                                title: 'BUYER PRICE',
                                value:
                                    'Rs. ${widget.buyerBiddingPrice.toStringAsFixed(2)}',
                              ),
                            ),
                            Expanded(
                              child: RequestInfoItem(
                                title: 'BUYER ID',
                                value: widget.buyerId.toString(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  const Text(
                    'TRANSACTION DETAILS',
                    style: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 13,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Color(0xFF6B6B6B),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Automatically filled from the buyer request',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B6B6B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  TextFormField(
                    controller: quantityController,
                    readOnly: true,
                    style: const TextStyle(
                      color: Color(0xFF3F3F3F),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Quantity Requested (${usesUnits ? 'Units' : 'Nuts'})',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      filled: true,
                      fillColor: AppColors.autoFilledBackground,
                      suffixIcon: const Icon(
                        Icons.lock,
                        size: 17,
                        color: Color(0xFF77736C),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFAAA69E)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  TextFormField(
                    controller: offerPriceController,
                    readOnly: true,
                    style: const TextStyle(
                      color: Color(0xFF3F3F3F),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Offer Price per ${usesUnits ? 'Unit' : 'Nut'} (LKR)',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixText: 'Rs. ',
                      filled: true,
                      fillColor: AppColors.autoFilledBackground,
                      suffixIcon: const Icon(
                        Icons.lock,
                        size: 17,
                        color: Color(0xFF77736C),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFAAA69E)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: paymentMethod,
                    hint: const Text('Select Payment Method'),
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      prefixIcon: const Icon(
                        Icons.payments_outlined,
                        color: Color(0xFF1F6B3D),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(9),
                        borderSide: const BorderSide(color: Color(0xFFAAA69E)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                      DropdownMenuItem(
                        value: 'Direct Bank Transfer',
                        child: Text('Direct Bank Transfer'),
                      ),
                      DropdownMenuItem(value: 'Any', child: Text('Any')),
                    ],
                    onChanged: sending
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => paymentMethod = value);
                            }
                          },
                  ),

                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimated Total',
                          style: TextStyle(
                            color: Color(0xFF263238),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Rs. ${totalValue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 34),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: sending ? null : sendOffer,
                      icon: const Icon(Icons.send),
                      label: Text(
                        sending ? 'Sending...' : 'Send Request',
                        style: TextStyle(fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F6B3D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                    ),
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

class RequestInfoItem extends StatelessWidget {
  final String title;
  final String value;

  const RequestInfoItem({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF777777),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF263238),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

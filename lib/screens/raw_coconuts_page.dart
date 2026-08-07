import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';
import 'sell_request_page.dart';

class RawCoconutsPage extends StatefulWidget {
  const RawCoconutsPage({super.key});

  @override
  State<RawCoconutsPage> createState() => _RawCoconutsPageState();
}

class _RawCoconutsPageState extends State<RawCoconutsPage> {
  final TextEditingController quantityController =
  TextEditingController(text: '1200');

  final TextEditingController dateController =
  TextEditingController(text: 'mm/dd/yyyy');

  final TextEditingController priceController =
  TextEditingController(text: 'Rs. 130.00');

  bool showSummary = false;

  Future<void> pickAvailableDate() async {
    final DateTime today = DateTime.now();
    final DateTime todayOnly = DateTime(today.year, today.month, today.day);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: todayOnly,
      firstDate: todayOnly,
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        dateController.text =
        '${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.year}';
      });
    }
  }

  void showSellSummary() {
    if (quantityController.text.trim().isEmpty ||
        dateController.text == 'mm/dd/yyyy' ||
        priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all sell details'),
        ),
      );
      return;
    }

    setState(() {
      showSummary = true;
    });
  }

  @override
  void dispose() {
    quantityController.dispose();
    dateController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          height: double.infinity,
          color: const Color(0xFFFCF8EF),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ABC Estate Owner',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1B5E20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: const Icon(
                              Icons.arrow_back,
                              size: 20,
                              color: Color(0xFF2E7D32),
                            ),
                          ),

                          const Text(
                            'KapConnect',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const Row(
                            children: [
                              Text(
                                'EN',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ' | SI | TA',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF5F6F5E),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    children: [
                      const Text(
                        'Raw Coconuts',
                        style: TextStyle(
                          fontSize: 24,
                          color: Color(0xFFD8D8D8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Manage your raw coconuts. Sell and View interested buyers.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // This line changes form to summary after clicking Sell
                      showSummary
                          ? buildSellSummaryCard()
                          : buildSellFormCard(),

                      const SizedBox(height: 22),

                      // Interested buyers heading
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Interested Buyers',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF263238),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 13,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Filter',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      const Row(
                        children: [
                          FilterChipButton(
                            text: 'Best Price',
                            isActive: true,
                          ),
                          SizedBox(width: 8),
                          FilterChipButton(
                            text: 'Earliest Pickup Date',
                            isActive: false,
                          ),
                          SizedBox(width: 8),
                          FilterChipButton(
                            text: 'Nearest Location',
                            isActive: false,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      InterestedBuyerCard(
                        iconLetter: 'A',
                        buyerName: 'Mudalali A',
                        trustScore: '4.8/5',
                        price: 'Rs. 136',
                        quantity: '1,200 nuts',
                        pickupDate: '18 Jul 2026',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SellRequestPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 12),

                      const InterestedBuyerCard(
                        iconLetter: 'P',
                        buyerName: 'Perera Purchasers',
                        trustScore: '4.0/5',
                        price: 'Rs. 121',
                        quantity: '800 units',
                        pickupDate: '02 Aug 2026',
                      ),

                      const SizedBox(height: 20),

                      const InterestedBuyerCard(
                        iconLetter: 'S',
                        buyerName: 'Super Market A',
                        trustScore: '3.4/5',
                        price: 'Rs. 118',
                        quantity: '1500 units',
                        pickupDate: '02 Feb 2027',
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                const CustomBottomNavigation(currentIndex: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildSellFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 18,
                color: Color(0xFF2E7D32),
              ),
              SizedBox(width: 8),
              Text(
                'Sell Raw Coconuts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const FormLabel(text: 'NUMBER OF UNITS'),
          CustomInputField(
            controller: quantityController,
            icon: null,
          ),

          const SizedBox(height: 12),

          const FormLabel(text: 'AVAILABLE DATE'),
          CustomInputField(
            controller: dateController,
            icon: Icons.calendar_month,
            readOnly: true,
            onTap: pickAvailableDate,
          ),

          const SizedBox(height: 12),

          const FormLabel(text: 'OFFER PRICE PER UNIT'),
          CustomInputField(
            controller: priceController,
            icon: null,
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: showSellSummary,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: const Text(
                'Sell',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSellSummaryCard() {
    final String quantity = quantityController.text.trim();
    final String date = dateController.text.trim();
    final String price = priceController.text.trim();

    final double quantityValue =
        double.tryParse(quantity.replaceAll(',', '').trim()) ?? 0;

    final double priceValue = double.tryParse(
      price
          .replaceAll('Rs.', '')
          .replaceAll('Rs', '')
          .replaceAll(',', '')
          .trim(),
    ) ??
        0;

    final double total = quantityValue * priceValue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 18,
                color: Color(0xFF2E7D32),
              ),
              SizedBox(width: 8),
              Text(
                'Sell  Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'READY TO POST',
              style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Raw Coconut Sell Offer',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF777777),
            ),
          ),

          const SizedBox(height: 16),

          const SummaryRow(
            title: 'Seller',
            value: 'ABC Estate Owner',
          ),

          const Divider(height: 24),

          SummaryRow(
            title: 'Quantity',
            value: '$quantity nuts',
          ),

          const Divider(height: 24),

          SummaryRow(
            title: 'Available Date',
            value: date,
          ),

          const Divider(height: 24),

          SummaryRow(
            title: 'Offer Price Per Unit',
            value: price,
          ),

          const Divider(height: 24),

          SummaryRow(
            title: 'Estimated Total',
            value: 'Rs. ${total.toStringAsFixed(2)}',
          ),

          const SizedBox(height: 16),

          const Text(
            'Buyers can view this sell offer after you confirm it. Payment will be handled outside the system.',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF777777),
              height: 1.4,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      showSummary = false;
                    });
                  },
                  child: const Text('Edit'),
                ),
              ),

              const SizedBox(width: 10),



            ],
          ),
        ],
      ),
    );
  }
}

class FormLabel extends StatelessWidget {
  final String text;

  const FormLabel({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        color: Color(0xFF777777),
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class CustomInputField extends StatelessWidget {
  final TextEditingController controller;
  final IconData? icon;
  final bool readOnly;
  final VoidCallback? onTap;

  const CustomInputField({
    super.key,
    required this.controller,
    required this.icon,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        suffixIcon: icon == null
            ? null
            : IconButton(
          icon: Icon(
            icon,
            size: 18,
            color: const Color(0xFF777777),
          ),
          onPressed: onTap,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(
            color: Color(0xFF2E7D32),
          ),
        ),
      ),
    );
  }
}

class FilterChipButton extends StatelessWidget {
  final String text;
  final bool isActive;

  const FilterChipButton({
    super.key,
    required this.text,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF2E7D32) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive ? const Color(0xFF2E7D32) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: isActive ? Colors.white : const Color(0xFF777777),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class InterestedBuyerCard extends StatelessWidget {
  final String iconLetter;
  final String buyerName;
  final String trustScore;
  final String price;
  final String quantity;
  final String pickupDate;
  final VoidCallback? onTap;

  const InterestedBuyerCard({
    super.key,
    required this.iconLetter,
    required this.buyerName,
    required this.trustScore,
    required this.price,
    required this.quantity,
    required this.pickupDate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: const Color(0xFFE7E7E7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Text(
                    iconLetter,
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF263238),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'TRUST SCORE: $trustScore',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    price,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BuyerInfoItem(
                  title: 'QUANTITY',
                  value: quantity,
                ),
                BuyerInfoItem(
                  title: 'REQUIRED DATE',
                  value: pickupDate,
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color(0xFF9E9E9E),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class BuyerInfoItem extends StatelessWidget {
  final String title;
  final String value;

  const BuyerInfoItem({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 8,
              color: Color(0xFF9E9E9E),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF263238),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String title;
  final String value;

  const SummaryRow({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF777777),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1B5E20),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
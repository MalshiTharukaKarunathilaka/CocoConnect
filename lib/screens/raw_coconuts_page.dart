import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';
import 'sell_request_page.dart';
import '../services/api_client.dart';
import '../services/owner_service.dart';
import 'buyer/buyer_format.dart';
import '../widgets/owner_widgets.dart';
import '../widgets/nearby_filter.dart';
import '../widgets/buyer_filter_sheet.dart';

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

  // Open raw-coconut buyer requests, reloaded after sending an offer.
  late Future<List<OpenBuyerRequest>> buyersFuture = loadBuyers();

  // Interested Buyers filters: distance from the estate and sort order.
  int? buyerRadiusKm;
  String buyerSort = 'price';

  // Show only buyers whose request fits the harvest entered above.
  bool matchHarvest = true;

  DateTime? get harvestDate {
    final parts = dateController.text.trim().split('/');
    if (parts.length != 3) return null;
    final int? month = int.tryParse(parts[0]);
    final int? day = int.tryParse(parts[1]);
    final int? year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  int? get harvestQuantity =>
      int.tryParse(quantityController.text.replaceAll(',', '').trim());

  bool get matching => matchHarvest && harvestDate != null;

  Future<List<OpenBuyerRequest>> loadBuyers() => OwnerService.getBuyerRequests(
        productType: 'RAW_COCONUT',
        radiusKm: buyerRadiusKm,
        sort: buyerSort,
        availableDate: matching ? harvestDate : null,
        maxQuantity: matching ? harvestQuantity : null,
      );

  Future<void> openBuyerFilter() async {
    final BuyerFilter? picked = await showBuyerFilterSheet(context, (
      sort: buyerSort,
      radiusKm: buyerRadiusKm,
      matchHarvest: matchHarvest,
    ));
    if (picked == null) return;
    buyerSort = picked.sort;
    buyerRadiusKm = picked.radiusKm;
    matchHarvest = picked.matchHarvest;
    reloadBuyers();
  }

  Widget buildHarvestMatchNote() {
    final DateTime date = harvestDate!;
    final DateTime from = date.subtract(const Duration(days: 7));
    final int? quantity = harvestQuantity;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC5DFCB)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 15, color: Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Matching your harvest: buyers needing '
              '${quantity == null ? '' : 'up to ${withCommas(quantity)} nuts '}'
              'between ${shortDate(from)} and ${shortDate(date)}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF263238)),
            ),
          ),
          TextButton(
            onPressed: () {
              matchHarvest = false;
              reloadBuyers();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Show all'),
          ),
        ],
      ),
    );
  }

  void reloadBuyers() {
    setState(() {
      buyersFuture = loadBuyers();
    });
  }

  void sortBuyers(String sort) {
    buyerSort = sort;
    reloadBuyers();
  }

  // Shown in the header and as the seller on the summary.
  String estateName = '';

  @override
  void initState() {
    super.initState();
    loadEstateName();
  }

  Future<void> loadEstateName() async {
    try {
      final Estate estate = await OwnerService.getEstate();
      if (mounted) setState(() => estateName = estate.estateName);
    } on ApiException {
      // Leave the header blank if the estate can't be loaded.
    }
  }

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
      // Show the buyers this harvest fits.
      matchHarvest = true;
      reloadBuyers();
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

    matchHarvest = true;
    reloadBuyers();

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
  
  String convertDateToDatabaseFormat(String dateText) {
  final parts = dateText.split('/');

  if (parts.length != 3) {
    return dateText;
  }

  final month = parts[0].padLeft(2, '0');
  final day = parts[1].padLeft(2, '0');
  final year = parts[2];

  return '$year-$month-$day';
}

Future<void> saveListingToDatabase() async {
  try {
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
    final int quantity = int.parse(
      quantityController.text.replaceAll(',', '').trim(),
    );

    final double price = double.parse(
      priceController.text
          .replaceAll('Rs.', '')
          .replaceAll('Rs', '')
          .replaceAll(',', '')
          .trim(),
    );

    final String availableDate =
        convertDateToDatabaseFormat(dateController.text.trim());

    // Saved under the logged-in owner's estate.
    await OwnerService.createListing(
      productType: 'RAW_COCONUT',
      quantity: quantity,
      availableDate: availableDate,
      pricePerUnit: price,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sell listing saved successfully'),
      ),
    );

    setState(() {
      showSummary = true;
      //quantityController.clear();
      //dateController.text = 'mm/dd/yyyy';
      //priceController.text = 'Rs. 130.00';
    });
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sell listing saved successfully'),
      ),
    );
  }
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
                      Text(
                        estateName,
                        style: const TextStyle(
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
                            'CocoConnect',
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

                      // Latest deal and today's average price
                      const MarketPulse(),

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

                          GestureDetector(
                            onTap: openBuyerFilter,
                            child: Container(
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
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      NearbyFilter(
                        radiusKm: buyerRadiusKm,
                        onRadiusChanged: (km) {
                          buyerRadiusKm = km;
                          reloadBuyers();
                        },
                        onLocationChanged: reloadBuyers,
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          FilterChipButton(
                            text: 'Best Price',
                            isActive: buyerSort == 'price',
                            onTap: () => sortBuyers('price'),
                          ),
                          const SizedBox(width: 8),
                          FilterChipButton(
                            text: 'Earliest Pickup Date',
                            isActive: buyerSort == 'date',
                            onTap: () => sortBuyers('date'),
                          ),
                          const SizedBox(width: 8),
                          FilterChipButton(
                            text: 'Nearest Location',
                            isActive: buyerSort == 'nearest',
                            onTap: () => sortBuyers('nearest'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
if (matching) buildHarvestMatchNote(),
FutureBuilder<List<OpenBuyerRequest>>(
  future: buyersFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      final Object error = snapshot.error!;
      return Text(
        error is ApiException ? error.message : 'Failed to load buyers',
        style: const TextStyle(color: Colors.red),
      );
    }

    final buyers = snapshot.data ?? [];

    if (buyers.isEmpty) {
      return Text(
        matching
            ? 'No buyer requests fit this harvest yet. Tap Show all to see '
                  'every request.'
            : buyerRadiusKm == null
            ? 'No buyers are requesting raw coconuts right now'
            : 'No buyers within $buyerRadiusKm km right now. Try a wider '
                  'distance.',
      );
    }

    return Column(
      children: buyers.map((buyer) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InterestedBuyerCard(
            iconLetter:
                buyer.buyerName.isNotEmpty ? buyer.buyerName[0] : '?',
            buyerName: buyer.buyerName,
            trustScore: buyer.trustScore == null
                ? 'NEW'
                : '${buyer.trustScore}/5',
            price: buyer.offerSent
                ? 'Offered ${rupees(buyer.myOfferPrice!)}'
                : rupees(buyer.bidPerUnit),
            quantity: '${withCommas(buyer.quantity)} nuts',
            pickupDate: shortDate(buyer.requiredDate),
            distance: distanceLabel(buyer.distanceKm),
            onTap: () async {
              if (buyer.offerSent) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'You already offered ${rupees(buyer.myOfferPrice!)} '
                      'per nut to ${buyer.buyerName}',
                    ),
                  ),
                );
                return;
              }

              final double sellerOfferPrice = double.tryParse(
                    priceController.text
                        .replaceAll('Rs.', '')
                        .replaceAll('Rs', '')
                        .replaceAll(',', '')
                        .trim(),
                  ) ??
                  0;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SellRequestPage(
                    buyerId: buyer.id,
                    buyerName: buyer.buyerName,
                    location: buyer.location ?? '',
                    requestedQuantity: buyer.quantity,
                    requiredDate: buyer.requiredDate == null
                        ? ''
                        : buyer.requiredDate!.toIso8601String().substring(0, 10),
                    productType: buyer.productType,
                    buyerBiddingPrice: buyer.bidPerUnit,
                    sellerOfferPricePerUnit: sellerOfferPrice > 0
                        ? sellerOfferPrice
                        : buyer.bidPerUnit,
                  ),
                ),
              );
              if (!mounted) return;
              setState(() {
                buyersFuture = loadBuyers();
              });
            },
          ),
        );
      }).toList(),
    );
  },
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
              onPressed: saveListingToDatabase,
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
              'POSTED',
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

          SummaryRow(
            title: 'Seller',
            value: estateName,
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
            'Buyers can now see this listing in the marketplace. Payment will be handled outside the system.',
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
                // The listing is saved; start a fresh one instead of editing.
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      showSummary = false;
                    });
                  },
                  child: const Text('Post Another Listing'),
                ),
              ),

             
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
  final VoidCallback? onTap;

  const FilterChipButton({
    super.key,
    required this.text,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
  final String? distance;

  const InterestedBuyerCard({
    super.key,
    required this.iconLetter,
    required this.buyerName,
    required this.trustScore,
    required this.price,
    required this.quantity,
    required this.pickupDate,
    this.onTap,
    this.distance,
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
                      if (distance != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          distance!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF555555),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
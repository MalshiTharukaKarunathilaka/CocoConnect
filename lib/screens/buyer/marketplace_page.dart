import 'package:flutter/material.dart';
import '../../widgets/buyer_widgets.dart';
import 'estate_owner_request_page.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final _nutsController = TextEditingController();
  final _dateController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void dispose() {
    _nutsController.dispose();
    _dateController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      _dateController.text =
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.year}';
    }
  }

  void _submitRequest() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request submitted to nearby estate owners'),
        backgroundColor: kBuyerGreen,
      ),
    );
  }

  void _openRequest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EstateOwnerRequestPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      bottomNavigation: BuyerBottomNavigation(
        currentIndex: 1,
        onTabSelected: (index) {
          if (index == 0) {
            // Categories is the root of this flow - unwind back to it
            // rather than stacking another copy on top.
            Navigator.popUntil(context, (route) => route.isFirst);
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile screen not built yet')),
            );
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.menu, size: 22, color: Color(0xFF3A3A3A)),
                    SizedBox(width: 12),
                    Text(
                      'CocoConnect',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kBuyerGreen,
                      ),
                    ),
                  ],
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      size: 22,
                      color: Color(0xFF3A3A3A),
                    ),
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD32F2F),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 22),

            const Text(
              'Marketplace',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Connect with local estate owners and secure your raw '
              'coconut supply with transparent pricing.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: kBuyerGrey,
              ),
            ),

            const SizedBox(height: 20),

            BuyerCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kBuyerGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Request Raw Coconuts',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const BuyerFieldLabel(text: 'Number of Nuts Required'),
                  const SizedBox(height: 7),
                  BuyerInputField(
                    controller: _nutsController,
                    hint: '1200',
                    keyboardType: TextInputType.number,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 12, right: 6),
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: kBuyerGrey,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const BuyerFieldLabel(text: 'Required Date'),
                  const SizedBox(height: 7),
                  BuyerInputField(
                    controller: _dateController,
                    hint: 'mm/dd/yyyy',
                    readOnly: true,
                    onTap: _pickDate,
                    suffix: IconButton(
                      icon: const Icon(
                        Icons.calendar_month_outlined,
                        size: 18,
                        color: kBuyerGrey,
                      ),
                      onPressed: _pickDate,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const BuyerFieldLabel(text: 'Bidding Price (Rs. per nut)'),
                  const SizedBox(height: 7),
                  BuyerInputField(
                    controller: _priceController,
                    hint: '110',
                    keyboardType: TextInputType.number,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 4),
                      child: Text(
                        'Rs.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  BuyerPrimaryButton(
                    label: 'Submit Request',
                    trailingIcon: Icons.arrow_forward,
                    color: kBuyerGreenDark,
                    onPressed: _submitRequest,
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Your request will be visible to estate owners within '
                    'your region.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: kBuyerGrey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            const Text(
              'Nearby Estate Owner Listings',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: kBuyerGreen,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Within 3km of your location',
                      style: TextStyle(fontSize: 12, color: kBuyerGrey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kBuyerBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.tune, size: 14, color: Color(0xFF3A3A3A)),
                      SizedBox(width: 6),
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            EstateListingCard(
              initial: 'F',
              initialBackground: const Color(0xFFDDEEE0),
              estateName: 'ABC Estates',
              ownerName: 'ABC Estate Owner',
              price: 'Rs. 130',
              trustScore: '4.8/5',
              quantity: '1,200 nuts',
              availableDate: '18 Jul 2024',
              onTap: _openRequest,
            ),

            const SizedBox(height: 16),

            EstateListingCard(
              initial: 'P',
              initialBackground: const Color(0xFFDCE6F5),
              estateName: 'Perera Plantations',
              ownerName: 'Perera Group',
              price: 'Rs. 140',
              trustScore: '4.8/5',
              quantity: '600 nuts',
              availableDate: '20 Jul 2024',
              onTap: _openRequest,
            ),
          ],
        ),
      ),
    );
  }
}

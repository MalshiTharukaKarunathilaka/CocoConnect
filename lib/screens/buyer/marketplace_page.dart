import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/buyer_widgets.dart';
import 'coconut_type.dart';
import 'estate_owner_request_page.dart';

class _Listing {
  final String initial;
  final Color initialBackground;
  final String estateName;
  final String ownerName;

  /// Added to the coconut type's base price per nut.
  final int priceOffset;
  final double trustScore;
  final int quantity;
  final String availableDate;

  const _Listing({
    required this.initial,
    required this.initialBackground,
    required this.estateName,
    required this.ownerName,
    required this.priceOffset,
    required this.trustScore,
    required this.quantity,
    required this.availableDate,
  });
}

const List<_Listing> _listings = [
  _Listing(
    initial: 'A',
    initialBackground: Color(0xFFDDEEE0),
    estateName: 'ABC Estates',
    ownerName: 'ABC Estate Owner',
    priceOffset: 0,
    trustScore: 4.8,
    quantity: 1200,
    availableDate: '18 Jul 2026',
  ),
  _Listing(
    initial: 'P',
    initialBackground: Color(0xFFDCE6F5),
    estateName: 'Perera Plantations',
    ownerName: 'Perera Group',
    priceOffset: 10,
    trustScore: 4.6,
    quantity: 600,
    availableDate: '20 Jul 2026',
  ),
];

enum _SortOrder {
  nearest('Nearest first'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  trust('Highest trust score');

  final String label;
  const _SortOrder(this.label);
}

/// 1200 -> "1,200"
String _withCommas(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

class MarketplacePage extends StatefulWidget {
  /// Which coconut form this marketplace is for. All three types share
  /// this screen; only the copy and prices differ.
  final CoconutType type;

  const MarketplacePage({super.key, this.type = CoconutType.raw});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final _nutsController = TextEditingController();
  final _dateController = TextEditingController();
  final _priceController = TextEditingController();

  _SortOrder _sortOrder = _SortOrder.nearest;

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

  void _showSnack(String text, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  void _submitRequest() {
    final int? nuts = int.tryParse(_nutsController.text);
    final int? price = int.tryParse(_priceController.text);

    String? error;
    if (nuts == null || nuts <= 0) {
      error = 'Enter the number of nuts you need';
    } else if (_dateController.text.isEmpty) {
      error = 'Pick the date you need them by';
    } else if (price == null || price <= 0) {
      error = 'Enter your bidding price per nut';
    }

    if (error != null) {
      _showSnack(error, color: const Color(0xFFC62828));
      return;
    }

    FocusScope.of(context).unfocus();
    _showSnack(
      'Request for ${_withCommas(nuts!)} nuts at Rs. $price each '
      'sent to nearby estate owners',
      color: kBuyerGreen,
    );
    _nutsController.clear();
    _dateController.clear();
    _priceController.clear();
  }

  List<_Listing> get _sortedListings {
    final List<_Listing> list = [..._listings];
    switch (_sortOrder) {
      case _SortOrder.nearest:
        break;
      case _SortOrder.priceLow:
        list.sort((a, b) => a.priceOffset.compareTo(b.priceOffset));
      case _SortOrder.priceHigh:
        list.sort((a, b) => b.priceOffset.compareTo(a.priceOffset));
      case _SortOrder.trust:
        list.sort((a, b) => b.trustScore.compareTo(a.trustScore));
    }
    return list;
  }

  Future<void> _openFilter() async {
    final _SortOrder? picked = await showModalBottomSheet<_SortOrder>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sort listings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            for (final order in _SortOrder.values)
              ListTile(
                title: Text(order.label),
                trailing: order == _sortOrder
                    ? const Icon(Icons.check, color: kBuyerGreen)
                    : null,
                onTap: () => Navigator.pop(context, order),
              ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _sortOrder = picked);
  }

  void _openRequest(_Listing listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EstateOwnerRequestPage(
          type: widget.type,
          estateName: listing.estateName,
          ownerName: listing.ownerName,
          pricePerNut: widget.type.pricePerNut + listing.priceOffset,
          quantity: listing.quantity,
        ),
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
            _showSnack('Profile screen not built yet');
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
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: Color(0xFF3A3A3A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'CocoConnect',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: kBuyerGreen,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showSnack('No new notifications'),
                  child: Stack(
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

            Text(
              'Connect with local estate owners and secure your '
              '${widget.type.singular.toLowerCase()} supply with '
              'transparent pricing.',
              style: const TextStyle(
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
                      Expanded(
                        child: Text(
                          'Request ${widget.type.label}',
                          style: const TextStyle(
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
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
                    hint: '${widget.type.pricePerNut - 20}',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitRequest(),
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
                GestureDetector(
                  onTap: _openFilter,
                  child: Container(
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
                      children: [
                        const Icon(
                          Icons.tune,
                          size: 14,
                          color: Color(0xFF3A3A3A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sortOrder == _SortOrder.nearest
                              ? 'Filter'
                              : _sortOrder.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3A3A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            for (final listing in _sortedListings) ...[
              EstateListingCard(
                initial: listing.initial,
                initialBackground: listing.initialBackground,
                estateName: listing.estateName,
                ownerName: listing.ownerName,
                price: 'Rs. ${widget.type.pricePerNut + listing.priceOffset}',
                trustScore: '${listing.trustScore}/5',
                quantity: '${_withCommas(listing.quantity)} nuts',
                availableDate: listing.availableDate,
                onTap: () => _openRequest(listing),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/buyer_service.dart';
import '../../widgets/buyer_widgets.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/nearby_filter.dart';
import 'buyer_format.dart';
import 'coconut_type.dart';
import 'estate_owner_request_page.dart';

const List<Color> _avatarColors = [
  Color(0xFFDDEEE0),
  Color(0xFFDCE6F5),
  Color(0xFFF5E6DC),
  Color(0xFFEDE3F5),
];

/// The request a buyer just submitted; listings are matched against it.
class _RequestMatch {
  final int quantity;
  final DateTime requiredDate;
  final int price;

  const _RequestMatch(this.quantity, this.requiredDate, this.price);

  /// Listings available up to a week after the required date still match.
  DateTime get latestDate => requiredDate.add(const Duration(days: 7));
}

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

  ListingSort _sort = ListingSort.newest;
  int? _radiusKm;
  _RequestMatch? _match;
  late Future<List<Listing>> _listings = _loadListings();
  DateTime? _requiredDate;
  bool _submitting = false;

  Future<List<Listing>> _loadListings() {
    final AppUser? me = AuthService.currentUser;
    final _RequestMatch? match = _match;
    return BuyerService.getListings(
      productType: widget.type.code,
      // Matches are always cheapest first.
      sort: match == null ? _sort : ListingSort.priceLow,
      latitude: me?.latitude,
      longitude: me?.longitude,
      radiusKm: _radiusKm,
      minQuantity: match?.quantity,
      requiredDate: match?.requiredDate,
    );
  }

  void _reloadListings() {
    setState(() {
      _listings = _loadListings();
    });
  }

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
      _requiredDate = picked;
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

  Future<void> _submitRequest() async {
    if (_submitting) return;

    final int? nuts = int.tryParse(_nutsController.text);
    final int? price = int.tryParse(_priceController.text);

    String? error;
    if (nuts == null || nuts <= 0) {
      error = 'Enter the number of nuts you need';
    } else if (_requiredDate == null) {
      error = 'Pick the date you need them by';
    } else if (price == null || price <= 0) {
      error = 'Enter your bidding price per nut';
    }

    if (error != null) {
      _showSnack(error, color: const Color(0xFFC62828));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      await BuyerService.createRequest(
        productType: widget.type.code,
        quantity: nuts!,
        requiredDate: _requiredDate!,
        pricePerUnit: price!.toDouble(),
      );
      if (!mounted) return;
      _showSnack(
        'Request sent to estate owners. Matching listings are shown below.',
        color: kBuyerGreen,
      );
      _match = _RequestMatch(nuts, _requiredDate!, price);
      _reloadListings();
      _nutsController.clear();
      _dateController.clear();
      _priceController.clear();
      _requiredDate = null;
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnack(error.message, color: const Color(0xFFC62828));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openFilter() async {
    if (_match != null) {
      _showSnack('Matching listings are sorted cheapest first');
      return;
    }
    final ListingSort? picked = await showModalBottomSheet<ListingSort>(
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
            for (final sort in ListingSort.values)
              ListTile(
                title: Text(sort.label),
                trailing: sort == _sort
                    ? const Icon(Icons.check, color: kBuyerGreen)
                    : null,
                onTap: () => Navigator.pop(context, sort),
              ),
          ],
        ),
      ),
    );
    if (picked != null && picked != _sort) {
      _sort = picked;
      _reloadListings();
    }
  }

  void _openRequest(Listing listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EstateOwnerRequestPage(type: widget.type, listing: listing),
      ),
    );
  }

  Widget _buildListings() {
    return FutureBuilder<List<Listing>>(
      future: _listings,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(color: kBuyerGreen)),
          );
        }

        if (snapshot.hasError) {
          final Object error = snapshot.error!;
          return _ListingsMessage(
            icon: Icons.cloud_off_outlined,
            text: error is ApiException
                ? error.message
                : 'Could not load listings',
            onRetry: _reloadListings,
          );
        }

        final List<Listing> listings = snapshot.data!;
        final _RequestMatch? match = _match;
        if (listings.isEmpty) {
          final String where = _radiusKm == null ? '' : ' within $_radiusKm km';
          return _ListingsMessage(
            icon: Icons.inventory_2_outlined,
            text: match != null
                ? 'No listings$where match your request yet. Estate owners '
                      'can still send you offers - check Orders.'
                : _radiusKm != null
                ? 'No ${widget.type.label.toLowerCase()} listed$where. '
                      'Try a wider distance.'
                : 'No ${widget.type.label.toLowerCase()} listed yet. '
                      'Submit a request above and estate owners can respond.',
            onRetry: _reloadListings,
          );
        }

        return Column(
          children: [
            for (int i = 0; i < listings.length; i++) ...[
              EstateListingCard(
                initial: listings[i].estateName.isEmpty
                    ? '?'
                    : listings[i].estateName[0].toUpperCase(),
                initialBackground: _avatarColors[i % _avatarColors.length],
                estateName: listings[i].estateName,
                ownerName: listings[i].ownerName,
                price: rupees(listings[i].pricePerUnit),
                trustScore: listings[i].trustScore == null
                    ? 'New'
                    : '${listings[i].trustScore}/5',
                quantity: '${withCommas(listings[i].quantity)} nuts',
                availableDate: shortDate(listings[i].availableDate),
                distance: distanceLabel(listings[i].distanceKm),
                note: match == null ? null : _bidNote(listings[i], match),
                noteGood:
                    match == null || listings[i].pricePerUnit <= match.price,
                onTap: () => _openRequest(listings[i]),
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }

  /// "Within your bid" / "Rs. 5 above your bid".
  String _bidNote(Listing listing, _RequestMatch match) {
    final double over = listing.pricePerUnit - match.price;
    if (over <= 0) return 'Within your bid of Rs. ${match.price}';
    return '${rupees(over)} above your bid';
  }

  Widget _buildMatchBanner(_RequestMatch match) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F3EA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC5DFCB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: kBuyerGreen),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Matches for your request',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: kBuyerGreen,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _match = null;
                  _reloadListings();
                },
                style: TextButton.styleFrom(
                  foregroundColor: kBuyerGreen,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Show all'),
              ),
            ],
          ),
          Text(
            '${withCommas(match.quantity)} nuts or more  ·  available '
            '${shortDate(match.requiredDate)} to '
            '${shortDate(match.latestDate)}  ·  cheapest first',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF3A3A3A),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      bottomNavigation: const AppBottomNav(current: AppTab.dashboard),
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
                const Text(
                  'EN | SI | TA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kBuyerGrey,
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
                    label: _submitting ? 'Sending...' : 'Submit Request',
                    trailingIcon: Icons.arrow_forward,
                    color: kBuyerGreenDark,
                    onPressed: _submitting ? null : _submitRequest,
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

            Text(
              _match == null ? 'Estate Owner Listings' : 'Matching Listings',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),

            const SizedBox(height: 8),

            NearbyFilter(
              radiusKm: _radiusKm,
              accent: kBuyerGreen,
              onRadiusChanged: (km) {
                _radiusKm = km;
                _reloadListings();
              },
              onLocationChanged: _reloadListings,
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: kBuyerGreen,
                      ),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Open listings from estate owners',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: kBuyerGrey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                          _sort == ListingSort.newest
                              ? 'Filter'
                              : _sort.shortLabel,
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

            if (_match != null) _buildMatchBanner(_match!),

            _buildListings(),
          ],
        ),
      ),
    );
  }
}

class _ListingsMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onRetry;

  const _ListingsMessage({
    required this.icon,
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return BuyerCard(
      child: Column(
        children: [
          Icon(icon, size: 32, color: kBuyerGrey),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: kBuyerGrey,
            ),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
            style: TextButton.styleFrom(foregroundColor: kBuyerGreen),
          ),
        ],
      ),
    );
  }
}

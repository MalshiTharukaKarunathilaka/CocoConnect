import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../services/buyer_service.dart';
import '../../widgets/buyer_widgets.dart';
import 'buyer_format.dart';
import '../chat/chat_page.dart';
import 'coconut_type.dart';

class EstateOwnerRequestPage extends StatefulWidget {
  final CoconutType type;
  final Listing listing;

  const EstateOwnerRequestPage({
    super.key,
    required this.type,
    required this.listing,
  });

  @override
  State<EstateOwnerRequestPage> createState() => _EstateOwnerRequestPageState();
}

class _EstateOwnerRequestPageState extends State<EstateOwnerRequestPage> {
  bool _opening = false;

  Future<void> _negotiate() async {
    if (_opening) return;
    setState(() => _opening = true);

    try {
      final int negotiationId = await BuyerService.startNegotiation(
        widget.listing.id,
      );
      if (!mounted) return;
      await openChat(context, negotiationId);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFC62828),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Listing listing = widget.listing;
    final CoconutType type = widget.type;

    return BuyerScaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 22,
                    color: kBuyerGreen,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Estate Owner Request',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kBuyerGreen,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----- Estate identity -----
                  BuyerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Placeholder - no image assets configured in
                            // pubspec.yaml yet.
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8D6E4A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                type.icon,
                                size: 30,
                                color: const Color(0xFFE8DCC8),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listing.estateName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: kBuyerGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    listing.ownerName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF5A5A5A),
                                    ),
                                  ),
                                  if (listing.location != null) ...[
                                    const SizedBox(height: 7),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: kBuyerBrown,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            listing.location!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: kBuyerBrown,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1, color: kBuyerBorder),
                        ),

                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 15,
                              color: Color(0xFFE0A526),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              listing.trustScore == null
                                  ? 'Trust Score: not rated yet'
                                  : 'Trust Score: ${listing.trustScore}/5',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3A3A3A),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ----- Order request -----
                  BuyerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            BuyerSectionTitle(
                              text:
                                  'Order Request for '
                                  '${type.singular.toLowerCase()}s',
                            ),
                            const BuyerPill(
                              text: 'OPEN',
                              background: Color(0xFFDDEEE0),
                              foreground: kBuyerGreen,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: BuyerInfoPair(
                                label: 'QUANTITY',
                                value: '${withCommas(listing.quantity)} nuts',
                              ),
                            ),
                            Expanded(
                              child: BuyerInfoPair(
                                label: 'AVAILABLE FROM',
                                value: shortDate(listing.availableDate),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: BuyerInfoPair(
                                label: 'OFFER PRICE',
                                value: '${rupees(listing.pricePerUnit)} / nut',
                              ),
                            ),
                            Expanded(
                              child: BuyerInfoPair(
                                label: 'ESTIMATED TOTAL',
                                value: rupees(
                                  listing.pricePerUnit * listing.quantity,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (listing.createdAt != null) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1, color: kBuyerBorder),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule,
                                size: 14,
                                color: kBuyerGrey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Posted ${shortDate(listing.createdAt!.toLocal())}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: kBuyerGrey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ----- Produce details -----
                  BuyerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BuyerSectionTitle(text: 'Coconut Details'),
                        const SizedBox(height: 8),
                        BuyerDetailRow(label: 'Type', value: type.singular),
                        BuyerDetailRow(label: 'Husk', value: type.husk),
                        if (listing.location != null)
                          BuyerDetailRow(
                            label: 'Pickup location',
                            value: listing.location!,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: BuyerPrimaryButton(
              label: _opening ? 'Opening...' : 'Negotiate',
              trailingIcon: Icons.send,
              onPressed: _opening ? null : _negotiate,
            ),
          ),
        ],
      ),
    );
  }
}

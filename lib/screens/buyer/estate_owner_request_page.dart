import 'package:flutter/material.dart';
import '../../widgets/buyer_widgets.dart';
import 'buyer_negotiation_page.dart';
import 'coconut_type.dart';

class EstateOwnerRequestPage extends StatelessWidget {
  final CoconutType type;
  final String estateName;
  final String ownerName;
  final int pricePerNut;
  final int quantity;

  const EstateOwnerRequestPage({
    super.key,
    this.type = CoconutType.raw,
    this.estateName = 'ABC Estate',
    this.ownerName = 'ABC Estate Owner',
    this.pricePerNut = 130,
    this.quantity = 1200,
  });

  /// 1200 -> "1,200"
  String get _formattedQuantity => quantity.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      );

  String get _estimatedTotal => (quantity * pricePerNut)
      .toString()
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
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
                                    estateName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: kBuyerGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ownerName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF5A5A5A),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: kBuyerBrown,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Kurunegala',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: kBuyerBrown,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        '3.2 km away',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: kBuyerGrey,
                                        ),
                                      ),
                                    ],
                                  ),
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
                            const Text(
                              'Trust Score: 4.8/5',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3A3A3A),
                              ),
                            ),
                            const Spacer(),
                            const BuyerPill(
                              text: 'VERIFIED OWNER',
                              background: Color(0xFFDDEEE0),
                              foreground: kBuyerGreen,
                              icon: Icons.check_circle_outline,
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
                              text: 'Order Request for '
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
                                value: '$_formattedQuantity nuts',
                              ),
                            ),
                            const Expanded(
                              child: BuyerInfoPair(
                                label: 'REQUIRED DATE',
                                value: '18 Jul 2026',
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
                                value: 'Rs. $pricePerNut / nut',
                              ),
                            ),
                            Expanded(
                              child: BuyerInfoPair(
                                label: 'ESTIMATED TOTAL',
                                value: 'Rs. $_estimatedTotal',
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Divider(height: 1, color: kBuyerBorder),
                        ),

                        Row(
                          children: const [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: kBuyerGrey,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Posted 2 days ago  ·  Closes in 5 days',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: kBuyerGrey,
                              ),
                            ),
                          ],
                        ),
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
                        const BuyerDetailRow(
                          label: 'Grade',
                          value: 'Grade A',
                        ),
                        BuyerDetailRow(label: 'Husk', value: type.husk),
                        const BuyerDetailRow(
                          label: 'Average nut size',
                          value: 'Large (400 - 500 g)',
                        ),
                        const BuyerDetailRow(
                          label: 'Harvest window',
                          value: 'Jul 2026',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ----- Logistics -----
                  BuyerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        BuyerSectionTitle(text: 'Pickup & Payment'),
                        SizedBox(height: 8),
                        BuyerDetailRow(
                          label: 'Pickup location',
                          value: 'Estate gate, Kurunegala',
                        ),
                        BuyerDetailRow(
                          label: 'Transport',
                          value: 'Arranged by buyer',
                        ),
                        BuyerDetailRow(
                          label: 'Payment method',
                          value: 'Bank transfer',
                        ),
                        BuyerDetailRow(
                          label: 'Payment terms',
                          value: 'On collection',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ----- Owner's note -----
                  BuyerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        BuyerSectionTitle(text: 'Note from the owner'),
                        SizedBox(height: 8),
                        Text(
                          'Harvest is from a 12-acre block with regular '
                          'fertilizing. Nuts can be collected in two loads '
                          'if that suits your transport.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Color(0xFF5A5A5A),
                          ),
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
              label: 'Negotiate',
              trailingIcon: Icons.send,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuyerNegotiationPage(
                      type: type,
                      estateName: estateName,
                      ownerName: ownerName,
                      pricePerNut: pricePerNut,
                      quantity: quantity,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

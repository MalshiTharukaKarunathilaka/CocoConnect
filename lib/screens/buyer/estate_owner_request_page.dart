import 'package:flutter/material.dart';
import '../../widgets/buyer_widgets.dart';
import 'buyer_negotiation_page.dart';

class EstateOwnerRequestPage extends StatelessWidget {
  const EstateOwnerRequestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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

            const SizedBox(height: 26),

            BuyerCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Placeholder - no image assets are configured in
                      // pubspec.yaml yet.
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8D6E4A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.park,
                          size: 30,
                          color: Color(0xFFE8DCC8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ABC Estate',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: kBuyerGreen,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'ABC Estate  Owner',
                              style: TextStyle(
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
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Order Request for Raw coconuts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3A3A3A),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: const [
                      Expanded(
                        child: BuyerInfoPair(
                          label: 'QUANTITY',
                          value: '1,200 nuts',
                        ),
                      ),
                      Expanded(
                        child: BuyerInfoPair(
                          label: 'REQUIRED DATE',
                          value: '18 Jul 2026',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            BuyerPrimaryButton(
              label: 'Negotiate',
              trailingIcon: Icons.send,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BuyerNegotiationPage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

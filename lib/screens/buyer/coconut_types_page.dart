import 'package:flutter/material.dart';
import '../../widgets/buyer_widgets.dart';
import '../../widgets/header_actions.dart';
import 'coconut_type.dart';
import 'marketplace_page.dart';
import 'my_activity_page.dart';
import 'buyer_profile_page.dart';

/// Sits between Buying Categories and the marketplace - the buyer picks
/// which form of coconut they want before seeing listings.
class CoconutTypesPage extends StatelessWidget {
  const CoconutTypesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      bottomNavigation: BuyerBottomNavigation(
        currentIndex: 0,
        onTabSelected: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
          } else if (index == 1) {
            openMyActivity(context);
          } else if (index == 2) {
            openBuyerProfile(context);
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                  'CocoConnect',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kBuyerGreen,
                  ),
                ),
                const Spacer(),
                const HeaderActions(color: kBuyerGreen),
                const SizedBox(width: 4),
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

            const SizedBox(height: 24),

            Text.rich(
              TextSpan(
                text: 'Coconut',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: kBuyerBrown,
                ),
                children: [
                  TextSpan(
                    text: '  Categories',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      color: kBuyerBrown.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'Select the form you want to buy',
              style: TextStyle(fontSize: 12, color: kBuyerGrey),
            ),

            const SizedBox(height: 18),

            for (final type in CoconutType.all) ...[
              BuyerCard(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarketplacePage(type: type),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F1EC),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(type.icon, size: 23, color: type.iconColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            type.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: kBuyerGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    BuyerPill(
                      text: 'Rs. ${type.pricePerNut}',
                      background: const Color(0xFFDDEEE0),
                      foreground: kBuyerGreen,
                      fontSize: 12,
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: Color(0xFFAAAAAA),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            const Text(
              'Prices shown are the current average offer per nut across '
              'nearby estates.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

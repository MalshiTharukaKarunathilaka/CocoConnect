import '../../widgets/language_selector.dart';
import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/buyer_widgets.dart';
import '../../widgets/reusable_widgets.dart';
import 'buyer_format.dart';
import 'coconut_type.dart';
import 'marketplace_page.dart';

/// Photos for each coconut form, shared look with the land owner's
/// Coconuts screen.
const Map<String, String> _photos = {
  'RAW_COCONUT': 'assets/images/raw_coconuts_green.jpg',
  'DEHUSKED_COCONUT': 'assets/images/dehusked_coconuts.jpg',
  'COCONUT_HUSK': 'assets/images/coconut_husks_per_nut.png',
};

/// Sits between Buying Categories and the marketplace - the buyer picks
/// which form of coconut they want before seeing listings.
class CoconutTypesPage extends StatelessWidget {
  const CoconutTypesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      bottomNavigation: const AppBottomNav(
        current: AppTab.dashboard,
        chatScope: ChatScope.coconut,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'KapConnect',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const LanguageSelector(),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choose Coconut Category',
                    style: TextStyle(
                      fontSize: 17,
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select the type of coconut product that you are looking to '
                    'source from our verified suppliers.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF777777),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final CoconutType type in CoconutType.all) ...[
                    Expanded(
                      child: CoconutProductCard(
                        title: type.label,
                        imageUrl: '',
                        imageAsset: _photos[type.code],
                        unitLabel: rupees(type.pricePerNut),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MarketplacePage(type: type),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    'Prices shown are the typical offer per nut across nearby '
                    'estates.',
                    style: TextStyle(
                      fontSize: 11,
                      color: kBuyerGrey,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

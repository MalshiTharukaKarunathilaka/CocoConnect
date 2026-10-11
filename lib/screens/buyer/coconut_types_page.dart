import 'package:flutter/material.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/buyer_widgets.dart';
import '../../widgets/owner_widgets.dart';
import 'buyer_format.dart';
import 'coconut_type.dart';
import 'marketplace_page.dart';

/// Photos for each coconut form, shared look with the estate owner's
/// Coconuts screen.
const Map<String, String> _photos = {
  'RAW_COCONUT':
      'https://commons.wikimedia.org/wiki/Special:FilePath/Coconut_green.JPG?width=800',
  'HUSKED_COCONUT':
      'https://images.pexels.com/photos/21273623/pexels-photo-21273623.jpeg?auto=compress&cs=tinysrgb&w=800',
  'DEHUSKED_COCONUT':
      'https://images.pexels.com/photos/7543134/pexels-photo-7543134.jpeg?auto=compress&cs=tinysrgb&w=800',
};

/// Sits between Buying Categories and the marketplace - the buyer picks
/// which form of coconut they want before seeing listings.
class CoconutTypesPage extends StatelessWidget {
  const CoconutTypesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      bottomNavigation: const AppBottomNav(current: AppTab.dashboard),
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
                  'CocoConnect',
                  style: TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Text(
                  'EN | SI | TA',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
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
                  CategoryImageCard(
                    title: type.label,
                    imageUrl: _photos[type.code] ?? '',
                    trailing: rupees(type.pricePerNut),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarketplacePage(type: type),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../widgets/buyer_widgets.dart';
import 'marketplace_page.dart';

class BuyerCategoriesPage extends StatelessWidget {
  const BuyerCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      bottomNavigation: BuyerBottomNavigation(
        currentIndex: 0,
        onTabSelected: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MarketplacePage(),
              ),
            );
          } else if (index == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile screen not built yet')),
            );
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'CocoConnect',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: kBuyerGreen,
                  ),
                ),
                Text(
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
                text: 'Buying',
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
              'List products',
              style: TextStyle(fontSize: 12, color: kBuyerGrey),
            ),

            const SizedBox(height: 18),

            BuyerCategoryCard(
              title: 'Coconuts',
              subtitle: 'List harvest',
              icon: Icons.park,
              iconColor: kBuyerGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MarketplacePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            const BuyerCategoryCard(
              title: 'Vegetables',
              subtitle: 'Fresh produce',
              icon: Icons.eco,
              iconColor: kBuyerBrown,
            ),

            const SizedBox(height: 14),

            const BuyerCategoryCard(
              title: 'Livestock',
              subtitle: 'Animal products',
              icon: Icons.pets,
              iconColor: Color(0xFF4A4A4A),
            ),

            const SizedBox(height: 14),

            const BuyerCategoryCard(
              title: 'Other Goods',
              subtitle: 'Farm goods',
              icon: Icons.inventory_2,
              iconColor: Color(0xFF4A4A4A),
            ),
          ],
        ),
      ),
    );
  }
}

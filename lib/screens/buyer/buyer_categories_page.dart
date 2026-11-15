import '../../widgets/dashboard_category_icon.dart';
import '../../widgets/language_selector.dart';
import 'package:flutter/material.dart';
import '../../widgets/buyer_widgets.dart';
import '../../widgets/app_bottom_nav.dart';
import 'coconut_types_page.dart';

class BuyerCategoriesPage extends StatelessWidget {
  const BuyerCategoriesPage({super.key});

  void _comingSoon(BuildContext context, String category) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$category marketplace coming soon')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      bottomNavigation: const AppBottomNav(current: AppTab.dashboard),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'KapConnect',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: kBuyerGreen,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                LanguageSelector(),
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
              'Browse products',
              style: TextStyle(fontSize: 12, color: kBuyerGrey),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const gap = 10.0;
                  final height = ((constraints.maxHeight - gap * 3 - 8) / 4)
                      .floorToDouble();
                  final cards = <Widget>[
                    BuyerCategoryCard(
                      title: 'Coconuts',
                      iconWidget: const DashboardCategoryIcon('\u{1F334}'),
                      subtitle: 'Browse harvest',
                      icon: Icons.park,
                      iconColor: kBuyerGreen,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CoconutTypesPage(),
                          ),
                        );
                      },
                    ),

                    BuyerCategoryCard(
                      title: 'Spices',
                      subtitle: 'Aromatic crops',
                      icon: Icons.grass,
                      iconColor: kBuyerBrown,
                      onTap: () => _comingSoon(context, 'Spices'),
                    ),

                    BuyerCategoryCard(
                      title: 'Livestock',
                      iconWidget: const DashboardCategoryIcon('\u{1F36F}'),
                      subtitle: 'Animal products',
                      icon: Icons.pets,
                      iconColor: const Color(0xFF4A4A4A),
                      onTap: () => _comingSoon(context, 'Livestock'),
                    ),

                    BuyerCategoryCard(
                      title: 'Vegetables',
                      subtitle: 'Fresh produce',
                      icon: Icons.spa,
                      iconWidget: const DashboardCategoryIcon('\u{1F33D}'),
                      iconColor: kBuyerBrown,
                      onTap: () => _comingSoon(context, 'Vegetables'),
                    ),

                    BuyerCategoryCard(
                      title: 'Fruits',
                      subtitle: 'Seasonal harvest',
                      icon: Icons.apple,
                      iconWidget: const DashboardCategoryIcon('\u{1F34D}'),
                      iconColor: kBuyerGreen,
                      onTap: () => _comingSoon(context, 'Fruits'),
                    ),

                    BuyerCategoryCard(
                      title: 'Other Goods',
                      subtitle: 'Farm goods',
                      icon: Icons.inventory_2,
                      iconColor: const Color(0xFF4A4A4A),
                      onTap: () => _comingSoon(context, 'Other Goods'),
                    ),
                  ];
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: cards.length,
                    separatorBuilder: (_, index) => const SizedBox(height: gap),
                    itemBuilder: (_, index) =>
                        SizedBox(height: height, child: cards[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

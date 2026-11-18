import 'package:flutter/material.dart';
import '../widgets/language_selector.dart';
import '../widgets/reusable_widgets.dart';

class Subcategory {
  final String name;
  final String? unit;
  final String? imageAsset;

  const Subcategory(this.name, [this.unit, this.imageAsset]);
}

const dashboardSubcategories = <String, List<Subcategory>>{
  'Spices': [
    Subcategory('Pepper', 'kg', 'assets/images/Garbled-Black-Pepper.webp'),
    Subcategory('Cinnamon', 'kg', 'assets/images/cinnamon.webp'),
    Subcategory('Ginger', 'kg', 'assets/images/Ginger.jpeg'),
  ],
  'Livestock': [
    Subcategory('Honey', 'kg', 'assets/images/Honey.jpg'),
    Subcategory('Eggs', 'egg', 'assets/images/eggs.jpg'),
    Subcategory('Milk', 'litre', 'assets/images/milk.webp'),
  ],
  'Vegetables': [
    Subcategory('Pea nuts', 'kg', 'assets/images/peanuts.jpg'),
    Subcategory('Lemon', 'kg', 'assets/images/lemon.png'),
    Subcategory('Corn', 'kg', 'assets/images/corn.jpg'),
  ],
  'Fruits': [
    Subcategory('Passion fruit', 'kg', 'assets/images/pasion.jpg'),
    Subcategory('Pineapple', 'kg', 'assets/images/pine apple.jpg'),
    Subcategory('Dragon fruit', 'kg', 'assets/images/Dragon fruit.webp'),
  ],
  'Other Goods': [
    Subcategory('Firewood', 'cubic meter', 'assets/images/firewood.png'),
    Subcategory('Coconut Timber', 'tree', 'assets/images/coconut timber.jpg'),
    Subcategory('Petioles', 'petiole', 'assets/images/petioles.png'),
  ],
  'Skilled Jobs': [
    Subcategory('Land Manager', null, 'assets/images/Land Manager.png'),
    Subcategory('Pole Picker', null, 'assets/images/Coconut pole Picker.webp'),
    Subcategory('Climb Picker', null, 'assets/images/coconut climb picker.png'),
  ],
  'Equipment': [
    Subcategory('Solar Pumps', null, 'assets/images/solar pumps.webp'),
    Subcategory(
      'Electric Brush Cutter',
      null,
      'assets/images/electric brush cutter.png',
    ),
    Subcategory('Chain saw', null, 'assets/images/chain saw.jpg'),
  ],
  'Irrigation': [
    Subcategory('Deep well', null, 'assets/images/deep well.png'),
    Subcategory('Agro well', null, 'assets/images/agro well.png'),
  ],
  'Miscellaneous': [
    Subcategory('Labour Advisory'),
    Subcategory('Tax Advisory'),
    Subcategory('Management Advisory'),
  ],
};

class SubcategoryPage extends StatelessWidget {
  final String category;
  final IconData icon;

  const SubcategoryPage({
    super.key,
    required this.category,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final items = dashboardSubcategories[category]!;
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          color: const Color(0xFFFCF8EF),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const LanguageSelector(),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '$category Categories',
                          style: const TextStyle(
                            fontSize: 17,
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final item in items)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Container(
                                      color: const Color(0xFFE8F5E9),
                                      child: item.imageAsset != null
                                          ? Image.asset(
                                              item.imageAsset!,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, error, stackTrace) =>
                                                      Icon(
                                                        icon,
                                                        size: 42,
                                                        color: const Color(
                                                          0xFF2E7D32,
                                                        ),
                                                      ),
                                            )
                                          : Icon(
                                              icon,
                                              size: 42,
                                              color: const Color(0xFF2E7D32),
                                            ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              item.name,
                                              style: const TextStyle(
                                                color: Color(0xFF1B5E20),
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (item.unit != null) ...[
                                          const SizedBox(width: 12),
                                          Text(
                                            '1 unit = 1 ${item.unit}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              color: Color(0xFF64705F),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const CustomBottomNavigation(currentIndex: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

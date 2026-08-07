import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';

class BuyingCategoriesPage extends StatelessWidget {
  const BuyingCategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          height: double.infinity,
          color: const Color(0xFFFCF8EF),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'KapConnect',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'EN   |   SI   |   TA',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    children: const [
                      Row(
                        children: [
                          Text(
                            'Buying',
                            style: TextStyle(
                              color: Color(0xFFB26A2C),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Categories',
                            style: TextStyle(
                              color: Color(0xFFD6BFA1),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 4),

                      Text(
                        'List products',
                        style: TextStyle(
                          color: Color(0xFF777777),
                          fontSize: 12,
                        ),
                      ),

                      SizedBox(height: 28),

                      BuyingCategoryCard(
                        title: 'Coconuts',
                        subtitle: 'List harvest',
                        icon: Icons.park,
                        iconColor: Color(0xFF3B8F65),
                        circleColor: Color(0xFFE8F5E9),
                      ),

                      SizedBox(height: 18),

                      BuyingCategoryCard(
                        title: 'Vegetables',
                        subtitle: 'Fresh produce',
                        icon: Icons.eco,
                        iconColor: Color(0xFFB26A2C),
                        circleColor: Color(0xFFF7EEE6),
                      ),

                      SizedBox(height: 18),

                      BuyingCategoryCard(
                        title: 'Livestock',
                        subtitle: 'Animal products',
                        icon: Icons.pets,
                        iconColor: Color(0xFF607D8B),
                        circleColor: Color(0xFFEAF1F8),
                      ),

                      SizedBox(height: 18),

                      BuyingCategoryCard(
                        title: 'Other Goods',
                        subtitle: 'Farm goods',
                        icon: Icons.inventory_2_outlined,
                        iconColor: Color(0xFF607D8B),
                        circleColor: Color(0xFFEAF1F8),
                      ),

                      SizedBox(height: 20),
                    ],
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

class BuyingCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color circleColor;
  final VoidCallback? onTap;

  const BuyingCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.circleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 122,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: circleColor,
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF8A8A8A),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
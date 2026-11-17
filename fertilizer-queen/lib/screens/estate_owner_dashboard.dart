import '../widgets/dashboard_category_icon.dart';
import '../widgets/language_selector.dart';
import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';
import 'coconuts_page.dart';
import 'estate_owner_calendar_page.dart';
import 'fertilizer/fertilizer_hub.dart';
import 'machinery_map_page.dart';

class EstateOwnerDashboard extends StatelessWidget {
  const EstateOwnerDashboard({super.key});

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
                const SizedBox(height: 10),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: const [
                              Icon(
                                Icons.arrow_back,
                                size: 20,
                                color: Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 5),
                              Text(
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

                const SizedBox(height: 16),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estate owner dashboard',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A4A4A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Container(
                          width: double.infinity,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),

                        const SizedBox(height: 14),

                        const Row(
                          children: [
                            Expanded(
                              child: DashboardHeading(
                                title: 'Selling\nCategories',
                                centered: true,
                                subtitle: 'List products',
                                color: Color(0xFFB26A2C),
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: DashboardHeading(
                                title: 'Provider\nServices',
                                centered: true,
                                subtitle: 'Essential resources',
                                color: Color(0xFF3B8F65),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Expanded(child: _categoryGrid(context)),
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

  Widget _categoryGrid(BuildContext context) {
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    final selling = <Widget>[
      DashboardCategoryCard(
        title: 'Coconuts',
        subtitle: 'List harvest',
        iconWidget: const DashboardCategoryIcon('\u{1F334}'),
        icon: Icons.park,
        iconColor: const Color(0xFF3B8F65),
        onTap: () => open(const CoconutsPage()),
      ),
      const DashboardCategoryCard(
        title: 'Spices',
        subtitle: 'Aromatic crops',
        icon: Icons.grass,
        iconColor: Color(0xFFB26A2C),
      ),
      const DashboardCategoryCard(
        title: 'Livestock',
        subtitle: 'Animal products',
        iconWidget: DashboardCategoryIcon('\u{1F36F}'),
        icon: Icons.pets,
        iconColor: Color(0xFF777777),
      ),
      const DashboardCategoryCard(
        title: 'Vegetables',
        subtitle: 'Fresh produce',
        iconWidget: DashboardCategoryIcon('\u{1F33D}'),
        icon: Icons.spa,
        iconColor: Color(0xFFB26A2C),
      ),
      const DashboardCategoryCard(
        title: 'Fruits',
        subtitle: 'Seasonal harvest',
        iconWidget: DashboardCategoryIcon('\u{1F34D}'),
        icon: Icons.apple,
        iconColor: Color(0xFF3B8F65),
      ),
      const DashboardCategoryCard(
        title: 'Other Goods',
        subtitle: 'Farm goods',
        icon: Icons.inventory_2,
        iconColor: Color(0xFF777777),
      ),
    ];
    final services = <Widget>[
      DashboardCategoryCard(
        title: 'Fertilizer',
        subtitle: 'Quality nutrients',
        iconWidget: const FertilizerBagIcon(),
        icon: Icons.eco,
        iconColor: const Color(0xFF3B8F65),
        onTap: () => open(const FertilizerHub()),
      ),
      DashboardCategoryCard(
        title: 'Machinery',
        subtitle: 'Rent or buy',
        icon: Icons.agriculture,
        iconColor: const Color(0xFFB26A2C),
        onTap: () => open(const MachineryMapPage()),
      ),
      DashboardCategoryCard(
        title: 'Day Jobs',
        subtitle: 'Hire workers',
        icon: Icons.groups,
        iconColor: const Color(0xFF777777),
        onTap: () => open(const EstateOwnerCalendarPage()),
      ),
      const DashboardCategoryCard(
        title: 'Skilled Jobs',
        subtitle: 'Expert assistance',
        icon: Icons.engineering,
        iconColor: Color(0xFFB26A2C),
      ),
      const DashboardCategoryCard(
        title: 'Equipment',
        subtitle: 'Tools and supplies',
        icon: Icons.handyman,
        iconColor: Color(0xFF777777),
      ),
      const DashboardCategoryCard(
        title: 'Irrigation',
        subtitle: 'Water solutions',
        icon: Icons.water_drop,
        iconColor: Color(0xFF3B8F65),
      ),
      const DashboardCategoryCard(
        title: 'Miscellaneous',
        subtitle: 'Other services',
        icon: Icons.category,
        iconColor: Color(0xFF777777),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve three row gaps and a little room for the bottom shadows.
        // Card contents scale down when the available viewport is short.
        final cardHeight = ((constraints.maxHeight - 30 - 8) / 4)
            .floorToDouble();
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: cardHeight,
          ),
          itemCount: services.length * 2,
          itemBuilder: (context, index) {
            final column = index.isEven ? selling : services;
            final row = index ~/ 2;
            return row < column.length ? column[row] : const SizedBox.shrink();
          },
        );
      },
    );
  }
}

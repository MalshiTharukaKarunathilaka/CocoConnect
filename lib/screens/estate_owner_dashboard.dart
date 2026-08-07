import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';
import 'coconuts_page.dart';

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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Row(
                        children: [
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
                      Text(
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

                const SizedBox(height: 22),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    children: [
                      const Text(
                        'Estate owner dashboard',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4A4A4A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Container(
                        width: 54,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),

                      const SizedBox(height: 28),

                      Row(
                        children: const [
                          Expanded(
                            child: DashboardHeading(
                              title: 'Selling\nCategories',
                              subtitle: 'List products',
                              color: Color(0xFFB26A2C),
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            child: DashboardHeading(
                              title: 'Provider\nServices',
                              subtitle: 'Essential resources',
                              color: Color(0xFF3B8F65),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.08,
                        children: [
                          DashboardCategoryCard(
                            title: 'Coconuts',
                            subtitle: 'List harvest',
                            icon: Icons.park,
                            iconColor: const Color(0xFF3B8F65),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CoconutsPage(),
                                ),
                              );
                            },
                          ),
                          const DashboardCategoryCard(
                            title: 'Fertilizer',
                            subtitle: 'Quality nutrients',
                            icon: Icons.eco,
                            iconColor: Color(0xFF3B8F65),
                          ),
                          const DashboardCategoryCard(
                            title: 'Vegetables',
                            subtitle: 'Fresh produce',
                            icon: Icons.spa,
                            iconColor: Color(0xFFB26A2C),
                          ),
                          const DashboardCategoryCard(
                            title: 'Machinery',
                            subtitle: 'Rent or buy',
                            icon: Icons.agriculture,
                            iconColor: Color(0xFFB26A2C),
                          ),
                          const DashboardCategoryCard(
                            title: 'Livestock',
                            subtitle: 'Animal products',
                            icon: Icons.pets,
                            iconColor: Color(0xFF777777),
                          ),
                          const DashboardCategoryCard(
                            title: 'Labour',
                            subtitle: 'Hire workers',
                            icon: Icons.groups,
                            iconColor: Color(0xFF777777),
                          ),
                          const DashboardCategoryCard(
                            title: 'Other Goods',
                            subtitle: 'Farm goods',
                            icon: Icons.inventory_2,
                            iconColor: Color(0xFF777777),
                          ),
                          const DashboardCategoryCard(
                            title: 'Miscellaneous',
                            subtitle: 'Other services',
                            icon: Icons.category,
                            iconColor: Color(0xFF777777),
                          ),
                        ],
                      ),
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
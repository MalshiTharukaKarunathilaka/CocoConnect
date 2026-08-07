import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';
import 'raw_coconuts_page.dart';

class CoconutsPage extends StatelessWidget {
  const CoconutsPage({super.key});

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
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
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
                    padding: const EdgeInsets.symmetric(horizontal: 18),
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
                        'Select the type of coconut product that you are looking to source from our verified suppliers.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 20),

                      CoconutProductCard(
                        title: 'Raw Coconuts',
                        imageUrl:
                        'https://commons.wikimedia.org/wiki/Special:FilePath/Coconut_green.JPG?width=800',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RawCoconutsPage(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 18),

                      const CoconutProductCard(
                        title: 'DeHusked Coconut',
                        imageUrl:
                        'https://images.pexels.com/photos/7543134/pexels-photo-7543134.jpeg?auto=compress&cs=tinysrgb&w=800',
                      ),

                      const SizedBox(height: 18),

                      const CoconutProductCard(
                        title: 'Coconut Husks',
                        imageUrl:
                        'https://images.pexels.com/photos/27596374/pexels-photo-27596374.jpeg?auto=compress&cs=tinysrgb&w=800',
                      ),

                      const SizedBox(height: 20),
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
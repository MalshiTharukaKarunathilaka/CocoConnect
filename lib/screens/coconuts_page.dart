import '../widgets/language_selector.dart';
import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/app_bottom_nav.dart';
import 'raw_coconuts_page.dart';
import 'coconut_husks_page.dart';

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

                const SizedBox(height: 20),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
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
                          'Select the type of coconut product that you are looking to source from our verified suppliers.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF777777),
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Expanded(
                          child: CoconutProductCard(
                            title: 'Raw Coconuts(with husks)',
                            unitLabel: '1 unit = 1 nut',
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
                        ),

                        const SizedBox(height: 10),

                        const Expanded(
                          child: CoconutProductCard(
                            title: 'Dehusked Coconuts',
                            unitLabel: '1 unit = 1 kg',
                            imageUrl:
                                'https://images.pexels.com/photos/7543134/pexels-photo-7543134.jpeg?auto=compress&cs=tinysrgb&w=800',
                          ),
                        ),

                        const SizedBox(height: 10),

                        Expanded(
                          child: CoconutProductCard(
                            title: 'Only Husks',
                            unitLabel: '1 unit = 1 nut',
                            imageUrl: '',
                            imageAsset:
                                'assets/images/coconut_husks_per_nut.png',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CoconutHusksPage(),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                const CustomBottomNavigation(
                  currentIndex: 0,
                  chatScope: ChatScope.coconut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

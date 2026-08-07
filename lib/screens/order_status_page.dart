import 'package:flutter/material.dart';
import '../widgets/reusable_widgets.dart';

class OrderStatusPage extends StatelessWidget {
  const OrderStatusPage({super.key});

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFCF8EF),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFE8E2D6),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1B5E20),
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 14),

                      const Expanded(
                        child: Text(
                          'My Sell Requests',
                          style: TextStyle(
                            color: Color(0xFF1B5E20),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFE8F5E9),
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                    children: [
                      // Tabs
                      Row(
                        children: const [
                          RequestStatusTab(
                            title: 'Pending',
                            isActive: false,
                          ),
                          SizedBox(width: 8),
                          RequestStatusTab(
                            title: 'Accepted',
                            isActive: true,
                          ),
                          SizedBox(width: 8),
                          RequestStatusTab(
                            title: 'Completed',
                            isActive: false,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Request card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE4E4E4),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(12),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Request ID and status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'REQUEST #CR-4921',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Color(0xFF2E7D32),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Accepted',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            const Text(
                              'Raw Coconut',
                              style: TextStyle(
                                fontSize: 22,
                                color: Color(0xFF222222),
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            const Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 15,
                                  color: Color(0xFF5A5A5A),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Mudalali A',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF5A5A5A),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Quantity and price box
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1EEE8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    child: OrderInfoItem(
                                      title: 'Quantity',
                                      mainValue: '1,200',
                                      smallValue: 'nuts',
                                    ),
                                  ),

                                  SizedBox(
                                    height: 48,
                                    child: VerticalDivider(
                                      color: Color(0xFFD6D0C6),
                                      thickness: 1,
                                    ),
                                  ),

                                  Expanded(
                                    child: OrderInfoItem(
                                      title: 'Price',
                                      mainValue: 'Rs. 125',
                                      smallValue: '/nut',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Divider(
                              color: Color(0xFFE8E2D6),
                            ),

                            const SizedBox(height: 14),

                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Value',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: Color(0xFF222222),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Rs. 150,000',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: Color(0xFFB26A2C),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Order completed'),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1F6B3D),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Complete Order',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Payment info box
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F2EC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE1DBCF),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF2E7D32),
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Waiting for the Payment to complete the order. Transaction verification usually takes 2-4 hours.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF5A5A5A),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const CustomBottomNavigation(currentIndex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RequestStatusTab extends StatelessWidget {
  final String title;
  final bool isActive;

  const RequestStatusTab({
    super.key,
    required this.title,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1F6B3D) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive ? const Color(0xFF1F6B3D) : const Color(0xFF9E9E9E),
          ),
          boxShadow: isActive
              ? [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            color: isActive ? Colors.white : const Color(0xFF333333),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class OrderInfoItem extends StatelessWidget {
  final String title;
  final String mainValue;
  final String smallValue;

  const OrderInfoItem({
    super.key,
    required this.title,
    required this.mainValue,
    required this.smallValue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF5A5A5A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: mainValue,
                style: const TextStyle(
                  fontSize: 22,
                  color: Color(0xFF1F6B3D),
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' $smallValue',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1F6B3D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'negotiation_page.dart';

class SellRequestPage extends StatelessWidget {
  const SellRequestPage({super.key});

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
              children: [
                Row(
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
                    const Text(
                      'Send Sell Request',
                      style: TextStyle(
                        color: Color(0xFF1B5E20),
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Buyer details card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              'https://images.unsplash.com/photo-1580984969071-a8da5656c2fb?auto=format&fit=crop&w=300&q=80',
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 62,
                                  height: 62,
                                  color: const Color(0xFFE8F5E9),
                                  child: const Icon(
                                    Icons.image,
                                    color: Color(0xFF2E7D32),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(width: 14),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mudalali A',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 23,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Requesting for Raw\nCoconut',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF3A3A3A),
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 16,
                                      color: Color(0xFFB26A2C),
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Green Valley Estate,\nKurunegala',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFB26A2C),
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Row(
                        children: [
                          Expanded(
                            child: RequestInfoItem(
                              title: 'QUANTITY',
                              value: '1,200 nuts',
                            ),
                          ),
                          Expanded(
                            child: RequestInfoItem(
                              title: 'REQUIRED DATE',
                              value: '18 Jul 2026',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                const Text(
                  'TRANSACTION DETAILS',
                  style: TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 13,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 22),

                TextFormField(
                  initialValue: '1200',
                  decoration: InputDecoration(
                    labelText: 'Quantity Requested (Nuts)',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  initialValue: '130',
                  decoration: InputDecoration(
                    labelText: 'Offer Price per Nut (LKR)',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),

                const SizedBox(height: 34),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NegotiationPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text(
                      'Send Request',
                      style: TextStyle(fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F6B3D),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RequestInfoItem extends StatelessWidget {
  final String title;
  final String value;

  const RequestInfoItem({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF777777),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF263238),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
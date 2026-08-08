import 'package:flutter/material.dart';
import '../../widgets/buyer_widgets.dart';

class BuyerNegotiationPage extends StatelessWidget {
  const BuyerNegotiationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BuyerScaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 22,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'ABC Estate',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ABC Estate Owner',
                        style: TextStyle(fontSize: 11, color: kBuyerGrey),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Seller',
                  style: TextStyle(fontSize: 12, color: kBuyerGrey),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: BuyerPill(
                      text: 'ORDER ESTABLISHED',
                      background: Color(0xFFDDEEE0),
                      foreground: kBuyerGreen,
                      icon: Icons.circle,
                    ),
                  ),

                  const SizedBox(height: 16),

                  BuyerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Offer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Row(
                              children: const [
                                Text(
                                  'Raw  Coconut',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3A3A3A),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: kBuyerGrey,
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          '1200 nuts',
                          style: TextStyle(fontSize: 12, color: kBuyerGrey),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Rs. 130.00',
                                  style: TextStyle(
                                    fontSize: 25,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'per nut',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: kBuyerGrey,
                                  ),
                                ),
                              ],
                            ),
                            const BuyerPill(
                              text: 'PENDING ORDER',
                              background: Color(0xFFF0EDE6),
                              foreground: Color(0xFF5A5A5A),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Center(
                    child: BuyerPill(
                      text: 'Negotiation Started - Today',
                      background: Color(0xFFF0EDE6),
                      foreground: Color(0xFF5A5A5A),
                      fontSize: 11,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Align(
                    alignment: Alignment.centerRight,
                    child: NegotiationBubble(
                      message:
                          "Hello, I'm interested in the 1200 nuts. "
                          'Can you do Rs.110?',
                      time: '10:42AM',
                      isMine: true,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: NegotiationBubble(
                      message:
                          'Thanks for reaching out. The quality is premium '
                          'this season. Best I can do is Rs. 125.',
                      time: '10:45 AM',
                      isMine: false,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: 250,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kBuyerGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'NEW OFFER RECEIVED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Color(0x55FFFFFF)),
                        ),
                        const Text(
                          'Rs. 120.00',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    '10:50 AM',
                    style: TextStyle(fontSize: 10, color: kBuyerGrey),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBuyerBorder)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: BuyerOutlinedButton(
                        label: 'Reject',
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBuyerGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Accept Deal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                BuyerOutlinedButton(
                  label: 'Complete Transaction',
                  leadingIcon: Icons.check_circle_outline,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

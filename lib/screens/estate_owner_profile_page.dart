import 'package:flutter/material.dart';

class EstateOwnerProfilePage extends StatelessWidget {
  const EstateOwnerProfilePage({super.key});

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
                // Header
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
                          size: 21,
                        ),
                      ),

                      const Expanded(
                        child: Text(
                          'KapConnect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF2E7D32),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const Text(
                        'EN | SI | TA',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Scrollable content - prevents overflow
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: Column(
                        children: [
                          // Profile circle
                          Stack(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3F8B5F),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(18),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'ABC',
                                  style: TextStyle(
                                    color: Color(0xFFD5F5D8),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              Positioned(
                                right: 0,
                                bottom: 1,
                                child: Container(
                                  width: 23,
                                  height: 23,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F6B3D),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          const Text(
                            'ABC Estate',
                            style: TextStyle(
                              color: Color(0xFF222222),
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 2),

                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                color: Color(0xFF1F6B3D),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified Estate Owner',
                                style: TextStyle(
                                  color: Color(0xFF1F6B3D),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1F6B3D),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              child: const Text(
                                'Edit Profile',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 7),

                          // Stats
                          const Row(
                            children: [
                              Expanded(
                                child: ProfileStatCard(
                                  number: '142',
                                  label: 'Total\nHarvests',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ProfileStatCard(
                                  number: '3',
                                  label: 'Active\nListings',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: ProfileStatCard(
                                  number: '89',
                                  label: 'Completed\nOrders',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Trust score
                          Container(
                            height: 62,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE4E4E4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(8),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                CircleAvatar(
                                  radius: 19,
                                  backgroundColor: Color(0xFFFFB175),
                                  child: Icon(
                                    Icons.star,
                                    color: Color(0xFF6B3B1C),
                                    size: 21,
                                  ),
                                ),

                                SizedBox(width: 13),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Trust Score',
                                        style: TextStyle(
                                          fontSize: 17,
                                          color: Color(0xFF222222),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        'Based on 50+ reviews',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF555555),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '4.8',
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: Color(0xFFB26A2C),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '/ 5.0',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Estate details - no Expanded here
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFE4E4E4),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(8),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Estate Details',
                                  style: TextStyle(
                                    color: Color(0xFF222222),
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                SizedBox(height: 4),

                                Divider(height: 8),

                                SizedBox(height: 3),

                                EstateDetailItem(
                                  icon: Icons.location_on_outlined,
                                  title: 'Location',
                                  value: 'Kurunegala, Sri Lanka',
                                ),

                                SizedBox(height: 6),

                                EstateDetailItem(
                                  icon: Icons.terrain_outlined,
                                  title: 'Total Land Area',
                                  value: '25 Acres',
                                ),

                                SizedBox(height: 6),

                                EstateDetailItem(
                                  icon: Icons.eco_outlined,
                                  title: 'Primary Crop',
                                  value: 'Coconut',
                                ),

                                SizedBox(height: 6),

                                EstateDetailItem(
                                  icon: Icons.calendar_month_outlined,
                                  title: 'Year Established',
                                  value: '2015',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                        ],
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

class ProfileStatCard extends StatelessWidget {
  final String number;
  final String label;

  const ProfileStatCard({
    super.key,
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFE4E4E4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 20,
                color: Color(0xFF222222),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF4A4A4A),
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EstateDetailItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const EstateDetailItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: const Color(0xFF7A837A),
          size: 17,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF4A4A4A),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
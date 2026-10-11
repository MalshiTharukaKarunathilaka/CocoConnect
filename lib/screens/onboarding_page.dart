import 'package:flutter/material.dart';
import 'login_page.dart';

const Color _green = Color(0xFF256B45);
const Color _cream = Color(0xFFF3F8EC);
const Color _brown = Color(0xFFB26A2C);

/// Welcome screen shown before Login when nobody is signed in.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: Container(
          width: 390,
          height: double.infinity,
          color: _green,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double top = constraints.maxHeight * 0.62;
              return Stack(
                children: [
                  // Cream area with a wavy bottom edge.
                  ClipPath(
                    clipper: _WaveClipper(),
                    child: Container(
                      height: top,
                      color: _cream,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.only(top: 40, bottom: 40),
                      child: const _Illustration(),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    right: 28,
                    top: top + 10,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          const Text(
                            'WELCOME TO COCOCONNECT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sell your harvest and buy coconuts directly '
                            'between estates and buyers, at live market '
                            'prices.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              color: Colors.white.withAlpha(215),
                            ),
                          ),
                          const Spacer(),
                          Material(
                            color: _cream,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _continue(context),
                              child: const SizedBox(
                                width: 64,
                                height: 64,
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: _green,
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final double h = size.height;
    final double w = size.width;
    return Path()
      ..lineTo(0, h - 70)
      ..quadraticBezierTo(w * 0.22, h - 10, w * 0.5, h - 40)
      ..quadraticBezierTo(w * 0.8, h - 72, w, h - 22)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A coconut palm with buyer / delivery / price badges around it.
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _green.withAlpha(28),
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(Icons.park, size: 96, color: _green),
          ),
          const Positioned(
            left: 4,
            top: 34,
            child: _Badge(icon: Icons.storefront, color: _brown),
          ),
          const Positioned(
            right: 0,
            top: 60,
            child: _Badge(icon: Icons.handshake_outlined, color: _green),
          ),
          const Positioned(
            left: 22,
            bottom: 28,
            child: _Badge(icon: Icons.local_shipping_outlined, color: _green),
          ),
          const Positioned(
            right: 18,
            bottom: 14,
            child: _Badge(icon: Icons.trending_up, color: _brown),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Badge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }
}

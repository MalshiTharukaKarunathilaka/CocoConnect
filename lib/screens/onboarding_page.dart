import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';

/// A deeper shade of the brand green for the title and the bottom wave.
final Color _deepGreen = Color.lerp(AppColors.green, Colors.black, 0.28)!;
const Color _background = Color(0xFFFAFAF7);

/// First screen: the KapConnect logo. It moves on to the welcome screen by
/// itself after a few seconds, or straight away when tapped.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), _next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, _, _) => const WelcomePage(),
        transitionsBuilder: (context, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
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
          color: _background,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            child: Stack(
              children: [
                const Positioned(left: -150, top: -190, child: _BlurredLeaf()),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, child) => Opacity(
                      opacity: t,
                      child: Transform.scale(
                        scale: 0.92 + 0.08 * t,
                        child: child,
                      ),
                    ),
                    child: const _Logo(),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 64,
                  child: Text(
                    'Tap anywhere to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF7A8A7E)),
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

/// Second screen: the palm, the welcome text and the button to Login.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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
          color: _background,
          child: LayoutBuilder(
            builder: (context, box) {
              final double h = box.maxHeight;
              final double waveHeight = (h * 0.2).clamp(130.0, 190.0);
              return Stack(
                children: [
                  // A palm leaf out of focus in the corner.
                  const Positioned(
                    left: -150,
                    top: -190,
                    child: _BlurredLeaf(),
                  ),

                  // Palm and welcome text.
                  Positioned.fill(
                    bottom: waveHeight - 10,
                    child: SafeArea(
                      bottom: false,
                      child: const Column(
                        children: [
                          SizedBox(height: 36),
                          Expanded(child: _Palm()),
                          _WelcomeText(),
                          SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // Two green waves with the button on top.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: waveHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(painter: _WavePainter()),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: waveHeight * 0.38,
                          child: Center(
                            child: _GoButton(onTap: () => _continue(context)),
                          ),
                        ),
                      ],
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

/// The KapConnect logo (the same one as the admin dashboard).
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/kapconnect_logo.png',
      width: 250,
      semanticLabel: 'KapConnect',
      filterQuality: FilterQuality.high,
    );
  }
}

/// The coconut palm. Its trunk is cut off at the bottom of the picture, so it
/// fades out into the background.
class _Palm extends StatelessWidget {
  const _Palm();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // The picture is square: size it first so the fade sits on its own
        // bottom edge.
        final double size = math.min(box.maxWidth - 36, box.maxHeight);
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0, 0.86, 1],
              ).createShader(rect),
              child: Image.asset(
                'assets/images/coconut_palm.png',
                fit: BoxFit.contain,
                semanticLabel: 'A coconut palm',
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.park, size: 140, color: AppColors.green),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The same palm, rotated, large and blurred, peeking in from the corner.
class _BlurredLeaf extends StatelessWidget {
  const _BlurredLeaf();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: 0.4,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: Transform.rotate(
              angle: -0.35,
              child: Image.asset(
                'assets/images/coconut_palm.png',
                width: 340,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Text(
            'Welcome to',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _deepGreen,
            ),
          ),
          Text(
            'KapConnect',
            style: TextStyle(
              fontSize: 46,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              color: _deepGreen,
            ),
          ),
          SizedBox(
            width: 150,
            height: 12,
            child: CustomPaint(painter: _SwooshPainter()),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sell your harvest and buy coconuts directly between estates '
            'and buyers, at live market prices.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The light green stroke under the name.
class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height * 0.85)
        ..quadraticBezierTo(
          size.width * 0.5,
          size.height * -0.15,
          size.width,
          size.height * 0.2,
        ),
      Paint()
        ..color = AppColors.greenMid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A light green wave behind a deep green one.
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Path back = Path()
      ..moveTo(0, h * 0.18)
      ..cubicTo(w * 0.3, h * 0.46, w * 0.62, -h * 0.02, w, h * 0.06)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      back,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppColors.greenLight, AppColors.greenMid],
        ).createShader(Offset.zero & size),
    );

    final Path front = Path()
      ..moveTo(0, h * 0.3)
      ..cubicTo(w * 0.3, h * 0.5, w * 0.62, h * 0.08, w, h * 0.15)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      front,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.green, _deepGreen],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The round "go" button with a soft green ring around it.
class _GoButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GoButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Continue to login',
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(
            color: AppColors.greenMid.withValues(alpha: 0.55),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Material(
          color: AppColors.cream,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: const SizedBox(
              width: 66,
              height: 66,
              child: Icon(
                Icons.arrow_forward,
                color: AppColors.green,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

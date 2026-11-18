import 'package:flutter/material.dart';
import '../theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: cardShadow,
      ),
      child: child,
    );
  }
}

class AppPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const AppPill(
    this.label, {
    super.key,
    this.bg = AppColors.primarySoft,
    this.fg = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool outline;
  final IconData? icon;
  final double? width;
  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.outline = false,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final fg = outline ? AppColors.primary : Colors.white;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
        if (icon != null) ...[
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: fg),
        ],
      ],
    );
    return SizedBox(
      height: 52,
      width: width ?? double.infinity,
      child: outline
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                shape: const StadiumBorder(),
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withAlpha(110),
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: child,
            ),
    );
  }
}

class ScreenTitle extends StatelessWidget {
  final String text;
  const ScreenTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text));
}

class InitialsBox extends StatelessWidget {
  final String initials;
  final double size;
  const InitialsBox(this.initials, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(initials,
          style: TextStyle(
              fontSize: size * 0.36, fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }
}

class IconBubble extends StatelessWidget {
  final IconData icon;
  const IconBubble(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(left: 6),
      decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: AppColors.primary),
    );
  }
}

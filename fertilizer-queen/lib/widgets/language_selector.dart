import 'package:flutter/material.dart';

/// Shared header language labels, written in each language's own script.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'EN',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: ' | ', style: TextStyle(color: Color(0xFF9A958D))),
          TextSpan(text: 'සිං'),
          TextSpan(text: ' | ', style: TextStyle(color: Color(0xFF9A958D))),
          TextSpan(text: 'த'),
        ],
      ),
      semanticsLabel: 'English, සිංහල, தமிழ்',
      style: TextStyle(
        fontFamily: 'Arial',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xFF55534F),
        height: 1.4,
      ),
      maxLines: 1,
      softWrap: false,
    );
  }
}

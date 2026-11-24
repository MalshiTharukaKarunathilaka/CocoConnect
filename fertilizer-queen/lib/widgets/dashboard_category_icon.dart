import 'package:flutter/material.dart';

/// Small, recognizable illustrations for the estate dashboard categories.
class DashboardCategoryIcon extends StatelessWidget {
  final String symbol;

  const DashboardCategoryIcon(this.symbol, {super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(symbol, style: const TextStyle(fontSize: 27, height: 1)),
  );
}

class FertilizerBagIcon extends StatelessWidget {
  const FertilizerBagIcon({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 30,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shopping_bag, size: 32, color: Color(0xFFB68A51)),
          Positioned(
            top: 13,
            child: Icon(Icons.eco, size: 15, color: Color(0xFFFFF8E7)),
          ),
        ],
      ),
    ),
  );
}

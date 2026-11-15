import 'package:flutter/material.dart';

import 'raw_coconuts_page.dart';

/// Estate-owner coconut husk flow. It intentionally shares the proven raw
/// coconut marketplace flow while storing husks under their own product type.
class CoconutHusksPage extends StatelessWidget {
  const CoconutHusksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RawCoconutsPage(
      productType: 'COCONUT_HUSK',
      title: 'Coconut Husks',
      singularTitle: 'Coconut Husk',
      description:
          'Manage your coconut husks. Sell and view interested buyers.',
      initialPricePerNut: 0,
    );
  }
}

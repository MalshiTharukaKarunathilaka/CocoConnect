import 'package:flutter/material.dart';

import 'raw_coconuts_page.dart';

/// Estate-owner listing flow for dehusked coconuts.
class DehuskedCoconutsPage extends StatelessWidget {
  const DehuskedCoconutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RawCoconutsPage(
      productType: 'DEHUSKED_COCONUT',
      title: 'Dehusked Coconuts',
      singularTitle: 'Dehusked Coconut',
      description:
          'Manage your dehusked coconuts. Sell and view interested buyers.',
      initialPricePerNut: 0,
    );
  }
}

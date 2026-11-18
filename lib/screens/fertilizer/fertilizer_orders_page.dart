import 'package:flutter/material.dart';
import '../../widgets/role_navigation_page.dart';
import 'live_fertilizer_orders_page.dart';

class FertilizerOrdersPage extends StatelessWidget {
  const FertilizerOrdersPage({super.key});
  @override
  Widget build(BuildContext context) => const RoleNavigationPage(
    current: AppTab.orders,
    child: LiveFertilizerOrdersPage(),
  );
}

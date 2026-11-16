import 'package:flutter/material.dart';
import 'app_bottom_nav.dart';
export 'app_bottom_nav.dart' show AppTab;

/// Adds the signed-in buyer/owner navigation to screens with their own Scaffold.
class RoleNavigationPage extends StatelessWidget {
  final Widget child;
  final AppTab current;
  const RoleNavigationPage({
    super.key,
    required this.child,
    this.current = AppTab.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    if (!supportsMainNavigation) return child;
    return Scaffold(
      backgroundColor: const Color(0xFFEFEFEF),
      body: Center(
        child: SizedBox(
          width: 390,
          child: Column(
            children: [
              Expanded(
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .removeViewInsets(removeBottom: true)
                      .removePadding(removeBottom: true),
                  child: child,
                ),
              ),
              Material(
                color: Color(0xFFF8F4EB),
                child: SafeArea(
                  top: false,
                  child: AppBottomNav(current: current),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

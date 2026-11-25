import 'package:flutter/material.dart';
import 'app_bottom_nav.dart';
import '../services/auth_service.dart';
export 'app_bottom_nav.dart' show AppTab, ChatScope;

class MobileViewportFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color gutterColor;

  const MobileViewportFrame({
    super.key,
    required this.child,
    this.maxWidth = 430,
    this.gutterColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: gutterColor,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}

/// Adds the signed-in buyer/owner navigation to screens with their own Scaffold.
class RoleNavigationPage extends StatelessWidget {
  final Widget child;
  final AppTab current;
  final ChatScope chatScope;
  final bool showBottomNavigation;
  const RoleNavigationPage({
    super.key,
    required this.child,
    this.current = AppTab.dashboard,
    this.chatScope = ChatScope.all,
    this.showBottomNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!supportsMainNavigation) {
      return AuthService.currentUser?.role == 'WORKER'
          ? MobileViewportFrame(child: child)
          : child;
    }
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
              if (showBottomNavigation)
                Material(
                  color: Color(0xFFF8F4EB),
                  child: SafeArea(
                    top: false,
                    child: AppBottomNav(current: current, chatScope: chatScope),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

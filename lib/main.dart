import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'screens/estate_owner_profile_page.dart';
import 'screens/orders/orders_page.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KapConnectApp());
}

/// Prevents a text field on the previous page from keeping the software
/// keyboard open after navigation to a page that has no inputs.
class KeyboardDismissNavigatorObserver extends NavigatorObserver {
  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();

    // A popped route can restore its old focus after the navigation callback,
    // so dismiss once more after the destination page has been drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissKeyboard();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

class KapConnectApp extends StatelessWidget {
  const KapConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KapConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      navigatorObservers: [KeyboardDismissNavigatorObserver()],

      // First screen
      // Restores a saved login, otherwise shows Login; then sends each
      // account type to its own home screen.
      home: const AuthGate(),

      // App routes
      routes: {
        '/profile': (context) => const EstateOwnerProfilePage(),
        '/owner-activity': (context) => const OrdersPage(initialTab: 1),
      },
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'screens/auth_gate.dart';
import 'screens/fertilizer/fertilizer_role_gate.dart';
import 'theme/app_theme.dart';

/// Fertilizer combo: role logins → shared store (orders sync across roles).
void main() {
  fertilizerComboMode = true;
  runApp(const ComboApp());
}

/// Why: on Flutter web, mouse/trackpad must be allowed or sheets/tabs feel “dead”.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class ComboApp extends StatelessWidget {
  const ComboApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KapConnect Fertilizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      scrollBehavior: const _AppScrollBehavior(),
      // Why: keep web pointer routing stable across desktop browsers.
      builder: (context, child) {
        if (!kIsWeb) return child ?? const SizedBox.shrink();
        return ScrollConfiguration(
          behavior: const _AppScrollBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const FertilizerRoleGate(),
    );
  }
}

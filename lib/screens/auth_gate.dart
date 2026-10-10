import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';
import 'buyer/buyer_categories_page.dart';
import 'estate_owner_dashboard.dart';
import 'login_page.dart';

/// First screen: reopens a saved login, otherwise shows Login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<AppUser?> _session = AuthService.restoreSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kAuthGreen)),
          );
        }

        final AppUser? user = snapshot.data;
        final Widget? home = user == null ? null : homeFor(user);
        return home ?? const LoginPage();
      },
    );
  }
}

/// Home screen for each account type, or null if that part of the app
/// isn't built yet.
Widget? homeFor(AppUser user) {
  switch (user.role) {
    case 'BUYER':
      return const BuyerCategoriesPage();
    case 'ESTATE_OWNER':
      return const EstateOwnerDashboard();
    default:
      return null;
  }
}

/// Sends a freshly logged-in user to their home screen.
void openHomeFor(BuildContext context, AppUser user) {
  final Widget? home = homeFor(user);
  if (home != null) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => home),
      (route) => false,
    );
    return;
  }

  // Estate Manager and Service Provider screens aren't built yet.
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Logged in as ${user.name}. Screens for this account type are not '
        'in this build yet.',
      ),
    ),
  );
}

/// Logs out and returns to the Login screen.
Future<void> logOut(BuildContext context) async {
  await AuthService.logout();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => const LoginPage()),
    (route) => false,
  );
}

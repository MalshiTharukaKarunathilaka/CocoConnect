import 'package:flutter/material.dart';
import '../services/api_client.dart';
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

/// Profile tab: who is logged in, with a Log out button. Stands in until a
/// full profile screen is built.
void showAccountSheet(BuildContext context) {
  final AppUser? user = AuthService.currentUser;

  showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user?.name ?? 'Not logged in',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (user != null) ...[
              const SizedBox(height: 4),
              Text(
                '${user.phone}  ·  Buyer',
                style: const TextStyle(fontSize: 13, color: kAuthGrey),
              ),
            ],
            if (user?.location != null) ...[
              const SizedBox(height: 2),
              Text(
                user!.location!,
                style: const TextStyle(fontSize: 13, color: kAuthGrey),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
                onPressed: user == null
                    ? null
                    : () {
                        Navigator.pop(sheetContext);
                        showDialog<void>(
                          context: context,
                          builder: (context) => _EditProfileDialog(user: user),
                        );
                      },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
                onPressed: () {
                  Navigator.pop(sheetContext);
                  logOut(context);
                },
              ),
            ),
          ],
        ),
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

class _EditProfileDialog extends StatefulWidget {
  final AppUser user;

  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _locationController = TextEditingController(
    text: widget.user.location ?? '',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService.updateProfile(
        name: name,
        location: _locationController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: kAuthGreen,
        ),
      );
      Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Location',
              hintText: 'e.g. Colombo',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Phone ${widget.user.phone} is your login and can\'t be changed.',
            style: const TextStyle(fontSize: 12, color: kAuthGrey),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 12.5),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

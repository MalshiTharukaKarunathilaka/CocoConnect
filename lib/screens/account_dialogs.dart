import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/owner_service.dart';
import 'auth_gate.dart';

const Color _green = Color(0xFF2E7D32);
const Color _grey = Color(0xFF777777);
const Color _red = Color(0xFFC62828);

/// "ESTATE_OWNER" -> "Estate Owner"
String roleLabel(String role) =>
    const {
      'BUYER': 'Buyer',
      'ESTATE_OWNER': 'Estate Owner',
      'ESTATE_MANAGER': 'Estate Manager',
      'SERVICE_PROVIDER': 'Service Provider',
    }[role] ??
    role;

/// Up to two initials: "Green Hills Estate" -> "GH".
String initialsOf(String name) {
  final List<String> words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

/// Asks before logging out, then returns to the Login screen.
Future<void> confirmLogOut(BuildContext context) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'You will need your phone number and password to '
        'log in again.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: _red),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) await logOut(context);
}

void _saved(BuildContext context, String text) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text), backgroundColor: _green));
}

Widget _errorText(String? error) => error == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(error, style: const TextStyle(color: _red, fontSize: 12.5)),
      );

/// Name and location of the logged-in account. Pops `true` when saved.
class EditProfileDialog extends StatefulWidget {
  final AppUser user;

  const EditProfileDialog({super.key, required this.user});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
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
      _saved(context, 'Profile updated');
      Navigator.pop(context, true);
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
      content: SingleChildScrollView(
        child: Column(
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
              style: const TextStyle(fontSize: 12, color: _grey),
            ),
            _errorText(_error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
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

/// Estate details buyers see on listings and offers. Pops `true` when saved.
class EditEstateDialog extends StatefulWidget {
  final Estate estate;

  const EditEstateDialog({super.key, required this.estate});

  @override
  State<EditEstateDialog> createState() => _EditEstateDialogState();
}

class _EditEstateDialogState extends State<EditEstateDialog> {
  late final _nameController = TextEditingController(
    text: widget.estate.estateName,
  );
  late final _locationController = TextEditingController(
    text: widget.estate.location ?? '',
  );
  late final _areaController = TextEditingController(
    text: widget.estate.totalLandArea ?? '',
  );
  late final _cropController = TextEditingController(
    text: widget.estate.primaryCrop ?? '',
  );
  late final _yearController = TextEditingController(
    text: widget.estate.yearEstablished?.toString() ?? '',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _cropController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Estate name is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await OwnerService.updateEstate(
        estateName: name,
        location: _locationController.text.trim(),
        totalLandArea: _areaController.text.trim(),
        primaryCrop: _cropController.text.trim(),
        yearEstablished: _yearController.text.trim(),
      );
      if (!mounted) return;
      _saved(context, 'Estate updated');
      Navigator.pop(context, true);
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
      title: const Text('Edit Estate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Estate name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _locationController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location',
                hintText: 'e.g. Kurunegala',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _areaController,
              decoration: const InputDecoration(
                labelText: 'Total land area',
                hintText: 'e.g. 25 acres',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _cropController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Primary crop',
                hintText: 'e.g. Coconut',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'Year established',
                hintText: 'e.g. 2015',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Buyers see your estate name and location on listings and '
              'offers.',
              style: TextStyle(fontSize: 12, color: _grey),
            ),
            _errorText(_error),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
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

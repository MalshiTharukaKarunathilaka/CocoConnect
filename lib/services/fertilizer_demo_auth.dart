import 'auth_service.dart';

/// Demo fertilizer accounts that work even if the API is offline.
/// Why: Kurunegala-focused demo — Estate / Supplier / CDO with one shared store.
class FertDemoAccount {
  const FertDemoAccount({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.role,
    required this.roleLabel,
    required this.blurb,
    this.location = 'Kurunegala',
    this.latitude = 7.4863,
    this.longitude = 80.3647,
  });

  final int id;
  final String name;
  final String phone;
  final String password;
  final String role; // API role code
  final String roleLabel;
  final String blurb;
  final String location;
  final double latitude;
  final double longitude;
}

class FertilizerDemoAuth {
  FertilizerDemoAuth._();

  static const passwordHint = 'demo123';

  static const accounts = <FertDemoAccount>[
    FertDemoAccount(
      id: 901,
      name: 'Nimal Rathnayake',
      phone: '0711000001',
      password: passwordHint,
      role: 'ESTATE_OWNER',
      roleLabel: 'Estate Owner',
      blurb: 'Kurunegala map & orders',
      location: 'Kurunegala',
      latitude: 7.4863,
      longitude: 80.3647,
    ),
    FertDemoAccount(
      id: 902,
      name: 'Nadeesha Perera',
      phone: '0771112233',
      password: passwordHint,
      role: 'FERTILIZER_SUPPLIER',
      roleLabel: 'Supplier Agent',
      blurb: 'Nadeesha Stores · Kurunegala',
      location: 'Kurunegala',
      latitude: 7.4980,
      longitude: 80.3560,
    ),
    FertDemoAccount(
      id: 903,
      name: 'Sunil Bandara',
      phone: '0772223344',
      password: passwordHint,
      role: 'CDO',
      roleLabel: 'CDO',
      blurb: 'Kurunegala · Mawathagama',
      location: 'Kurunegala',
      latitude: 7.5400,
      longitude: 80.4000,
    ),
  ];

  static FertDemoAccount? byRole(String role) {
    for (final a in accounts) {
      if (a.role == role) return a;
    }
    return null;
  }

  static AppUser? tryLogin({
    required String phone,
    required String password,
    String? expectedRole,
  }) {
    final normalised = AuthService.normalisePhone(phone);
    for (final a in accounts) {
      if (AuthService.normalisePhone(a.phone) != normalised) continue;
      if (a.password != password) return null;
      if (expectedRole != null && a.role != expectedRole) return null;
      return AppUser(
        id: a.id,
        name: a.name,
        phone: normalised,
        role: a.role,
        location: a.location,
        latitude: a.latitude,
        longitude: a.longitude,
      );
    }
    return null;
  }
}

import 'auth_service.dart';

/// Demo fertilizer accounts that work even if the API is offline.
/// Why: you can log in as owner / supplier / CDO with the same password and
/// share one in-memory FertilizerStore so orders sync across roles.
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
      name: 'Demo Estate Owner',
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
      id: 911,
      name: 'Nushrath Silva',
      phone: '0712000011',
      password: passwordHint,
      role: 'ESTATE_OWNER',
      roleLabel: 'Estate Owner',
      blurb: 'Colombo Palm Estate',
      location: 'Colombo',
      latitude: 6.9271,
      longitude: 79.8612,
    ),
    FertDemoAccount(
      id: 912,
      name: 'Kamal Fernando',
      phone: '0712000022',
      password: passwordHint,
      role: 'ESTATE_OWNER',
      roleLabel: 'Estate Owner',
      blurb: 'Puttalam Coast Estate',
      location: 'Puttalam',
      latitude: 8.0362,
      longitude: 79.8283,
    ),
    FertDemoAccount(
      id: 902,
      name: 'Nadeesha Perera',
      phone: '0771112233',
      password: passwordHint,
      role: 'FERTILIZER_SUPPLIER',
      roleLabel: 'Supplier Agent',
      blurb: 'Shop calendar',
      latitude: 7.4980,
      longitude: 80.3560,
    ),
    FertDemoAccount(
      id: 903,
      name: 'CDO Mawathagama',
      phone: '0372223344',
      password: passwordHint,
      role: 'CDO',
      roleLabel: 'CDO',
      blurb: 'Stock & distribution',
      latitude: 7.5400,
      longitude: 80.4000,
    ),
    FertDemoAccount(
      id: 931,
      name: 'CDO Colombo',
      phone: '0772300001',
      password: passwordHint,
      role: 'CDO',
      roleLabel: 'CDO',
      blurb: 'Colombo district',
      location: 'Colombo',
      latitude: 6.9300,
      longitude: 79.8650,
    ),
    FertDemoAccount(
      id: 932,
      name: 'CDO Puttalam',
      phone: '0772300002',
      password: passwordHint,
      role: 'CDO',
      roleLabel: 'CDO',
      blurb: 'Puttalam district',
      location: 'Puttalam',
      latitude: 8.0350,
      longitude: 79.8300,
    ),
    FertDemoAccount(
      id: 904,
      name: 'Regional Manager',
      phone: '0702000001',
      password: passwordHint,
      role: 'REGIONAL_MANAGER',
      roleLabel: 'Regional Manager',
      blurb: 'Regional monitoring',
    ),
    FertDemoAccount(
      id: 905,
      name: 'Board Chairman',
      phone: '0703000001',
      password: passwordHint,
      role: 'CHAIRMAN',
      roleLabel: 'Chairman',
      blurb: 'Board overview',
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

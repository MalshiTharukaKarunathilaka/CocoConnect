import 'api_client.dart';

class AppUser {
  final int id;
  final String name;
  final String phone;
  final String role;
  final String? location;

  /// Picked on the map at sign-up; null for older accounts.
  final double? latitude;
  final double? longitude;

  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.location,
    this.latitude,
    this.longitude,
  });

  bool get isBuyer => role == 'BUYER';

  bool get hasCoordinates => latitude != null && longitude != null;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String,
    phone: json['phone'] as String,
    role: json['role'] as String,
    location: json['location'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );
}

class AuthService {
  AuthService._();

  static AppUser? currentUser;

  /// "77 123 4567", "0771234567" or "+94 77..." -> "0771234567", so the
  /// same person always maps to the same account.
  static String normalisePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final local = digits.length > 9
        ? digits.substring(digits.length - 9)
        : digits;
    return '0$local';
  }

  static Future<AppUser> login({
    required String phone,
    required String password,
  }) async {
    final data = await ApiClient.post('/api/auth/login', {
      'phone': normalisePhone(phone),
      'password': password,
    });
    return _startSession(data as Map<String, dynamic>);
  }

  static Future<AppUser> signup({
    required String name,
    required String phone,
    required String password,
    required String role,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    final data = await ApiClient.post('/api/auth/signup', {
      'name': name,
      'phone': normalisePhone(phone),
      'password': password,
      'role': role,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    });
    return _startSession(data as Map<String, dynamic>);
  }

  /// Restores a saved login on app start. Returns null if there is none or
  /// it has expired.
  static Future<AppUser?> restoreSession() async {
    final token = await ApiClient.loadToken();
    if (token == null) return null;

    try {
      final data = await ApiClient.get('/api/auth/me');
      currentUser = AppUser.fromJson(data as Map<String, dynamic>);
      return currentUser;
    } on ApiException catch (error) {
      if (error.isUnauthorized) await logout();
      return null;
    }
  }

  static Future<AppUser> updateProfile({
    required String name,
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    final data = await ApiClient.patch('/api/auth/me', {
      'name': name,
      'location': location ?? '',
      // Left out unless a new place was picked, so the saved one stays.
      if (latitude != null && longitude != null) ...{
        'latitude': latitude,
        'longitude': longitude,
      },
    });
    currentUser = AppUser.fromJson(data as Map<String, dynamic>);
    return currentUser!;
  }

  static Future<void> logout() async {
    currentUser = null;
    await ApiClient.clearToken();
  }

  static Future<AppUser> _startSession(Map<String, dynamic> data) async {
    await ApiClient.saveToken(data['token'] as String);
    currentUser = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    return currentUser!;
  }
}

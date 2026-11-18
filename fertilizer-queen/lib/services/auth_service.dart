import 'api_client.dart';

class RegistrationStorage {
  final bool persistent;
  final bool ready;
  const RegistrationStorage({required this.persistent, required this.ready});

  factory RegistrationStorage.fromJson(Map<String, dynamic> json) {
    final storage = json['storage'];
    if (storage is! Map ||
        storage['persistent'] is! bool ||
        json['provider_registration_ready'] is! bool) {
      throw const ApiException(
        'Restart the backend to check registration storage.',
      );
    }
    return RegistrationStorage(
      persistent: storage['persistent'] as bool,
      ready: json['provider_registration_ready'] as bool,
    );
  }
}

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

  /// Extra rows from fertilizer_suppliers / cdo_officers after login/signup.
  static Map<String, dynamic>? fertilizerSupplierProfile;
  static Map<String, dynamic>? cdoProfile;

  static Future<RegistrationStorage> registrationStorage() async {
    final data = await ApiClient.get('/api/health');
    return RegistrationStorage.fromJson(data as Map<String, dynamic>);
  }

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
    Map<String, dynamic>? serviceProvider,
    Map<String, dynamic>? fertilizerSupplier,
    Map<String, dynamic>? cdo,
  }) async {
    final data = await ApiClient.post('/api/auth/signup', {
      'name': name,
      'phone': normalisePhone(phone),
      'password': password,
      'role': role,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'service_provider': ?serviceProvider,
      'fertilizer_supplier': ?fertilizerSupplier,
      'cdo': ?cdo,
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
      final map = data as Map<String, dynamic>;
      currentUser = AppUser.fromJson(map);
      _cacheProfiles(map);
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
    fertilizerSupplierProfile = null;
    cdoProfile = null;
    await ApiClient.clearToken();
  }

  static Future<AppUser> _startSession(Map<String, dynamic> data) async {
    await ApiClient.saveToken(data['token'] as String);
    currentUser = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    _cacheProfiles(data);
    return currentUser!;
  }

  static void _cacheProfiles(Map<String, dynamic> data) {
    final supplier = data['fertilizer_supplier'];
    fertilizerSupplierProfile =
        supplier is Map ? Map<String, dynamic>.from(supplier) : null;
    final cdo = data['cdo'];
    cdoProfile = cdo is Map ? Map<String, dynamic>.from(cdo) : null;
  }

  static Future<Map<String, dynamic>> fetchSupplierProfile() async {
    final data = await ApiClient.get('/api/auth/me/supplier');
    fertilizerSupplierProfile = Map<String, dynamic>.from(
      data as Map<String, dynamic>,
    );
    return fertilizerSupplierProfile!;
  }

  static Future<Map<String, dynamic>> saveSupplierProfile({
    required String agentName,
    required String phone,
    required bool willingFar,
    required String coverageNote,
  }) async {
    final data = await ApiClient.patch('/api/auth/me/supplier', {
      'agent_name': agentName,
      'phone': normalisePhone(phone),
      'willing_far': willingFar,
      'coverage_note': coverageNote,
    });
    final map = data as Map<String, dynamic>;
    if (map['user'] is Map) {
      currentUser = AppUser.fromJson(map['user'] as Map<String, dynamic>);
    }
    if (map['fertilizer_supplier'] is Map) {
      fertilizerSupplierProfile = Map<String, dynamic>.from(
        map['fertilizer_supplier'] as Map,
      );
    }
    return fertilizerSupplierProfile ?? {};
  }

  static Future<Map<String, dynamic>> fetchCdoProfile() async {
    final data = await ApiClient.get('/api/auth/me/cdo');
    cdoProfile = Map<String, dynamic>.from(data as Map<String, dynamic>);
    return cdoProfile!;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Thrown for any failed request. [message] is safe to show to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Talks to the CocoConnect backend and remembers the login token.
class ApiClient {
  ApiClient._();

  static String get baseUrl {
    // Point at another server with --dart-define=API_URL=http://...
    const String override = String.fromEnvironment('API_URL');
    if (override.isNotEmpty) {
      return override;
    }
    // The Android emulator reaches the computer's localhost via 10.0.2.2.
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    return 'http://10.0.2.2:5000';
  }

  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 15);

  static String? _token;

  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    return _token;
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<dynamic> get(String path, {Map<String, String>? query}) {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _send(() => http.get(uri, headers: _headers));
  }

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) {
    return _send(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) {
    return _send(
      () => http.patch(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) {
    return _send(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: _headers,
        body: jsonEncode(body ?? {}),
      ),
    );
  }

  static Future<dynamic> delete(String path) {
    return _send(
      () => http.delete(Uri.parse('$baseUrl$path'), headers: _headers),
    );
  }

  static Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on SocketException {
      throw const ApiException(
        "Can't reach the server. Is the backend running?",
      );
    } on TimeoutException {
      throw const ApiException('The server took too long to respond');
    } on http.ClientException {
      throw const ApiException(
        "Can't reach the server. Is the backend running?",
      );
    }

    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      data = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    final String message = data is Map && data['message'] is String
        ? data['message'] as String
        : 'Something went wrong (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode);
  }
}

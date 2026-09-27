import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'employee_session.dart';

class SessionStore {
  static const _tokenKey = 'access_token';
  static const _sessionKey = 'session_json';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveSession(EmployeeSession session) async {
    await _storage.write(key: _tokenKey, value: session.accessToken);
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<EmployeeSession?> loadSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null) return null;
    try {
      return EmployeeSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> getAccessToken() => _storage.read(key: _tokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _sessionKey);
  }
}

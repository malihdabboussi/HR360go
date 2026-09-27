import 'package:dio/dio.dart';

import '../../config/env.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../permissions/permissions_repository.dart';
import 'aes_crypto.dart';
import 'employee_session.dart';
import 'session_store.dart';

class MobileAccessDeniedException implements Exception {
  MobileAccessDeniedException([
    this.message = 'Mobile app access is not permitted for your role.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._api, this._sessionStore);

  final ApiClient _api;
  final SessionStore _sessionStore;

  PermissionsRepository get _permissions => PermissionsRepository(_api);

  Future<EmployeeSession> login({
    required String email,
    required String password,
  }) async {
    if (Env.aesKeyHex.isEmpty) {
      throw StateError(
        'AES_KEY_HEX not set. Run with --dart-define=AES_KEY_HEX=...',
      );
    }

    final encrypted = AesCrypto(Env.aesKeyHex).encryptPassword(password);

    try {
      final response = await _api.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': encrypted},
        options: Options(
          headers: {'X-Client-App': 'hr360-go'},
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid login response');
      }

      final employeeData = data['employeeData'];
      if (employeeData is! Map<String, dynamic>) {
        throw Exception('Login failed');
      }

      var session = EmployeeSession.fromJson(employeeData);
      if (session.accessToken.isEmpty) {
        throw Exception('No access token in login response');
      }

      // Bearer token must be available before detailed permissions fetch.
      await _sessionStore.saveSession(session);
      session = await _permissions.hydrateSessionPermissions(session);
      await _sessionStore.saveSession(session);

      if (!session.canMobileAccess) {
        await _sessionStore.clear();
        throw MobileAccessDeniedException();
      }

      return session;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final errorCode = body is Map ? body['error']?.toString() : null;
      if (status == 403 || errorCode == 'mobile_access_denied') {
        final msg = body is Map
            ? body['message']?.toString()
            : null;
        throw MobileAccessDeniedException(
          msg ?? 'Mobile app access is not permitted for your role.',
        );
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Cannot reach API at ${Env.apiBaseUrl}. '
          'On a physical phone use your Mac LAN IP in .env (not localhost), '
          'same Wi‑Fi, and restart flutter run.',
        );
      }
      rethrow;
    }
  }

  Future<EmployeeSession?> currentSession() async {
    final session = await _sessionStore.loadSession();
    if (session == null) return null;
    if (session.enabledActionIds != null) return session;

    final hydrated = await _permissions.hydrateSessionPermissions(session);
    if (hydrated.enabledActionIds != null ||
        hydrated.permissions != session.permissions) {
      await _sessionStore.saveSession(hydrated);
    }
    return hydrated;
  }

  Future<void> logout() => _sessionStore.clear();
}

import '../../config/env.dart';
import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../auth/aes_crypto.dart';
import '../auth/employee_session.dart';
import '../auth/permission_codec.dart';
import 'detailed_permissions_decode.dart';

/// Fetches detailed catalog permissions (web Client parity).
class PermissionsRepository {
  PermissionsRepository(this._api);

  final ApiClient _api;

  /// Returns a session copy with `enabledActionIds` (and optional legacy
  /// `permissions` overlay) from `/permissions/me/detailed`. On failure,
  /// returns [session] unchanged so soft-default check-in still applies.
  Future<EmployeeSession> hydrateSessionPermissions(
    EmployeeSession session,
  ) async {
    try {
      final response = await _api.get(ApiEndpoints.permissionsMeDetailed);
      final aes = Env.aesKeyHex.isNotEmpty ? AesCrypto(Env.aesKeyHex) : null;
      final decoded = decodeDetailedPermissionsApiResponse(
        response.data,
        aes: aes,
      );
      if (decoded == null) return session;

      var next = session;
      if (decoded.enabledActionIds != null) {
        next = next.copyWith(enabledActionIds: decoded.enabledActionIds);
      }

      // When detailed payload includes legacy permissions, prefer them so an
      // explicit `check-in.read: false` is honored.
      if (decoded.permissions != null && decoded.permissions!.isNotEmpty) {
        final legacy = PermissionCodec.decompress(decoded.permissions);
        if (legacy.isNotEmpty) {
          next = next.copyWith(permissions: {
            ...next.permissions,
            ...legacy,
          });
        }
      }

      return next;
    } catch (_) {
      return session;
    }
  }
}

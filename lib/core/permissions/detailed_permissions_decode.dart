import 'dart:convert';

import 'package:archive/archive.dart';

import '../auth/aes_crypto.dart';

/// Decoded `/api/v2/permissions/me/detailed` payload (mirrors web Client).
class DetailedPermissionsPayload {
  const DetailedPermissionsPayload({
    this.enabledActionIds,
    this.permissions,
    this.permissionsVersion,
    this.rolePermissionId,
  });

  final List<String>? enabledActionIds;
  final Map<String, dynamic>? permissions;
  final int? permissionsVersion;
  final String? rolePermissionId;
}

/// Decode detailed permissions API response.
///
/// - Dev / unprotected: plain JSON with `enabled_action_ids` (or permissions)
/// - Production: `{ encrypted_payload }` → AES decrypt → base64 gzip → JSON
DetailedPermissionsPayload? decodeDetailedPermissionsApiResponse(
  dynamic apiResponse, {
  AesCrypto? aes,
}) {
  if (apiResponse == null) return null;

  Map<String, dynamic>? asMap;
  if (apiResponse is Map) {
    asMap = Map<String, dynamic>.from(apiResponse);
  } else if (apiResponse is String) {
    try {
      final parsed = jsonDecode(apiResponse);
      if (parsed is Map) {
        asMap = Map<String, dynamic>.from(parsed);
      }
    } catch (_) {
      return null;
    }
  }
  if (asMap == null) return null;

  if (_looksLikePlainPayload(asMap)) {
    return _fromPlainMap(asMap);
  }

  final encryptedPayload = asMap['encrypted_payload'];
  if (encryptedPayload is! Map || aes == null) return null;

  try {
    final gzBase64 = aes.decryptMessage(
      Map<String, dynamic>.from(encryptedPayload),
    );
    final gzBytes = base64Decode(gzBase64);
    final jsonBytes = const GZipDecoder().decodeBytes(gzBytes);
    final parsed = jsonDecode(utf8.decode(jsonBytes));
    if (parsed is! Map) return null;
    return _fromPlainMap(Map<String, dynamic>.from(parsed));
  } catch (_) {
    return null;
  }
}

bool _looksLikePlainPayload(Map<String, dynamic> map) {
  if (map['permissions'] is Map) return true;
  if (map['enabled_action_ids'] is List) return true;
  return false;
}

DetailedPermissionsPayload _fromPlainMap(Map<String, dynamic> map) {
  List<String>? actionIds;
  final rawIds = map['enabled_action_ids'];
  if (rawIds is List) {
    actionIds = rawIds.map((e) => '$e').toList();
  }

  Map<String, dynamic>? permissions;
  final rawPerms = map['permissions'];
  if (rawPerms is Map) {
    permissions = Map<String, dynamic>.from(rawPerms);
  }

  final versionRaw = map['permissions_version'];
  int? version;
  if (versionRaw is int) {
    version = versionRaw;
  } else if (versionRaw != null) {
    version = int.tryParse('$versionRaw');
  }

  return DetailedPermissionsPayload(
    enabledActionIds: actionIds,
    permissions: permissions,
    permissionsVersion: version,
    rolePermissionId: map['role_permission_id']?.toString(),
  );
}

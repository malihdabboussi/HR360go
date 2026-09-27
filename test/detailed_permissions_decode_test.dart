import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/core/auth/aes_crypto.dart';
import 'package:hr360_go/core/permissions/check_in_permission.dart';
import 'package:hr360_go/core/permissions/detailed_permissions_decode.dart';

void main() {
  const keyHex =
      '4b788e38de3d203f531ae18a115c012a2c1421382d8d725e4b69cff8d1033bf9';

  group('decodeDetailedPermissionsApiResponse', () {
    test('parses plain JSON with enabled_action_ids', () {
      final decoded = decodeDetailedPermissionsApiResponse({
        'enabled_action_ids': [remoteCheckInActionId, 'actions.my-team.export'],
        'permissions_version': 9,
        'role_permission_id': 'role-1',
      });

      expect(decoded, isNotNull);
      expect(decoded!.enabledActionIds, contains(remoteCheckInActionId));
      expect(decoded.permissionsVersion, 9);
      expect(decoded.rolePermissionId, 'role-1');
    });

    test('parses plain JSON string body', () {
      final decoded = decodeDetailedPermissionsApiResponse(
        jsonEncode({
          'enabled_action_ids': [remoteCheckInActionId],
          'permissions_version': 1,
          'role_permission_id': 'r',
        }),
      );
      expect(decoded?.enabledActionIds, contains(remoteCheckInActionId));
    });

    test('decrypts production encrypted_payload (AES + gzip)', () {
      final payload = jsonEncode({
        'enabled_action_ids': [remoteCheckInActionId],
        'permissions_version': 2,
        'role_permission_id': 'enc-role',
      });
      final gz = const GZipEncoder().encode(utf8.encode(payload))!;
      final gzBase64 = base64Encode(gz);
      final aes = AesCrypto(keyHex);
      final encrypted = aes.encryptPassword(gzBase64);

      final decoded = decodeDetailedPermissionsApiResponse(
        {
          'encrypted_payload': encrypted,
          'permissions_version': 2,
          'role_permission_id': 'enc-role',
        },
        aes: aes,
      );

      expect(decoded, isNotNull);
      expect(decoded!.enabledActionIds, contains(remoteCheckInActionId));
      expect(decoded.rolePermissionId, 'enc-role');
    });
  });
}

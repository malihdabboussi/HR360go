import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/core/auth/aes_crypto.dart';

void main() {
  const keyHex =
      '4b788e38de3d203f531ae18a115c012a2c1421382d8d725e4b69cff8d1033bf9';

  test('content is ciphertext only (auth tag not appended)', () {
    const password = 'TestPassword123!';
    final encrypted = AesCrypto(keyHex).encryptPassword(password);

    final ciphertext = base64Decode(encrypted['content']!);
    final authTag = base64Decode(encrypted['authTag']!);

    expect(ciphertext.length, password.length);
    expect(authTag.length, 16);
  });

  test('encrypt then decrypt round-trips plaintext', () {
    const message = 'hello-permissions-payload';
    final aes = AesCrypto(keyHex);
    final encrypted = aes.encryptPassword(message);
    expect(aes.decryptMessage(encrypted), message);
  });
}

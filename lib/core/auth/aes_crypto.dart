import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-256-GCM — compatible with web `AESencryptMessage` in Client/lib/utils.ts.
class AesCrypto {
  AesCrypto(this._keyHex);

  final String _keyHex;

  Map<String, String> encryptPassword(String plaintext) {
    final key = _parseKey(_keyHex);
    final iv = _randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          128,
          iv,
          Uint8List(0),
        ),
      );

    final input = Uint8List.fromList(utf8.encode(plaintext));
    // Pointycastle appends the 16-byte GCM tag to `process()` output; Node keeps
    // ciphertext and authTag separate — match the web/server wire format.
    final output = cipher.process(input);
    const tagLength = 16;
    if (output.length < tagLength) {
      throw StateError('AES-GCM output shorter than auth tag');
    }
    final ciphertext = output.sublist(0, output.length - tagLength);
    final authTag = cipher.mac;

    return {
      'content': base64Encode(ciphertext),
      'iv': base64Encode(iv),
      'authTag': base64Encode(authTag),
    };
  }

  /// Decrypts `{ content, iv, authTag }` from web/server `AESencryptMessage`.
  String decryptMessage(Map<String, dynamic> encryptedData) {
    final key = _parseKey(_keyHex);
    final iv = base64Decode('${encryptedData['iv']}');
    final authTag = base64Decode('${encryptedData['authTag']}');
    final ciphertext = base64Decode('${encryptedData['content']}');

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          128,
          iv,
          Uint8List(0),
        ),
      );

    final combined = Uint8List(ciphertext.length + authTag.length)
      ..setRange(0, ciphertext.length, ciphertext)
      ..setRange(ciphertext.length, ciphertext.length + authTag.length, authTag);

    final decrypted = cipher.process(combined);
    return utf8.decode(decrypted);
  }

  Uint8List _parseKey(String hex) {
    if (hex.length != 64) {
      throw ArgumentError('AES key must be 32 bytes (64 hex chars)');
    }
    return Uint8List.fromList(
      List.generate(hex.length ~/ 2, (i) {
        return int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }),
    );
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }
}

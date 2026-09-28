import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../domain/attendance_control.dart';

/// Tag UID as uppercase hex from the platform tag map. Android nests it under
/// the tech (`nfca`, `mifareultralight`, `isodep`, ...) as `identifier`; iOS uses
/// `mifare` / `iso7816` / `iso15693` `identifier`, or FeliCa `currentIDm`.
String? extractNfcTagSerial(Map<String, dynamic> data) {
  String? search(dynamic node, String key) {
    if (node is Map) {
      final value = node[key];
      if (value is List && value.isNotEmpty && value.every((b) => b is int)) {
        return nfcSerialFromBytes(value.cast<int>());
      }
      for (final child in node.values) {
        final found = search(child, key);
        if (found != null) return found;
      }
    }
    return null;
  }

  return search(data, 'identifier') ?? search(data, 'currentIDm');
}

abstract class NfcReader {
  Future<bool> isAvailable();

  /// Emits the serial of every tag tapped until [stop] is called.
  Future<void> start({
    required void Function(String serial) onSerial,
    required void Function(String message) onError,
    required void Function() onCancelled,
    String? iosAlertMessage,
  });

  Future<void> stop({String? iosSuccessMessage, String? iosErrorMessage});
}

class PlatformNfcReader implements NfcReader {
  const PlatformNfcReader();

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('[nfc] isAvailable failed: $e');
      return false;
    }
  }

  @override
  Future<void> start({
    required void Function(String serial) onSerial,
    required void Function(String message) onError,
    required void Function() onCancelled,
    String? iosAlertMessage,
  }) {
    return NfcManager.instance.startSession(
      alertMessage: iosAlertMessage,
      // Keep the Android reader open so a wrong card can be retried in place.
      invalidateAfterFirstRead: false,
      onDiscovered: (tag) async {
        final serial = extractNfcTagSerial(Map<String, dynamic>.from(tag.data));
        if (serial == null) {
          onError('Could not read this card. Try again.');
          return;
        }
        onSerial(serial);
      },
      onError: (error) async {
        if (error.type == NfcErrorType.userCanceled) {
          onCancelled();
        } else {
          onError(error.message);
        }
      },
    );
  }

  @override
  Future<void> stop({String? iosSuccessMessage, String? iosErrorMessage}) async {
    try {
      await NfcManager.instance.stopSession(
        alertMessage: iosSuccessMessage,
        errorMessage: iosErrorMessage,
      );
    } catch (e) {
      debugPrint('[nfc] stopSession failed: $e');
    }
  }
}

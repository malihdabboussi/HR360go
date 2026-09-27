import 'dart:convert';

/// Decompress permissions — mirrors web `decompressPermissions` in lib/auth.ts.
/// Also accepts plain permission objects from login `employeeData.permissions`.
class PermissionCodec {
  static Map<String, Map<String, bool>> decompress(dynamic raw) {
    if (raw == null) return {};

    Map<String, dynamic> parsed;
    if (raw is String) {
      if (raw.isEmpty) return {};
      parsed = jsonDecode(raw) as Map<String, dynamic>;
    } else if (raw is Map) {
      parsed = Map<String, dynamic>.from(raw);
    } else {
      return {};
    }

    final result = <String, Map<String, bool>>{};

    for (final entry in parsed.entries) {
      final module = entry.key;
      final value = entry.value;

      if (value is Map) {
        result[module] = _parsePermissionMap(value);
        continue;
      }

      if (value is! String) continue;

      if (value.length == 4 && RegExp(r'^[01]+$').hasMatch(value)) {
        result[module] = _fromBinaryString(module, value);
        continue;
      }

      try {
        final binaryValue = base64Decode(value)[0];
        result[module] = _fromBinaryValue(module, binaryValue);
      } catch (_) {
        continue;
      }
    }

    return result;
  }

  static Map<String, bool> _parsePermissionMap(Map<dynamic, dynamic> map) {
    final out = <String, bool>{};
    for (final e in map.entries) {
      final v = e.value;
      if (v is bool) {
        out[e.key.toString()] = v;
      } else if (v == true || v == 1 || v == '1' || v == 'true') {
        out[e.key.toString()] = true;
      } else {
        out[e.key.toString()] = false;
      }
    }
    return out;
  }

  static Map<String, bool> _fromBinaryString(String module, String bits) {
    if (module == 'employees') {
      return {
        'read_all': bits[0] == '1',
        'read_my': bits.length > 1 && bits[1] == '1',
        'read_details': bits.length > 2 && bits[2] == '1',
      };
    }
    return {
      'read': bits[0] == '1',
      'add': bits.length > 1 && bits[1] == '1',
      'edit': bits.length > 2 && bits[2] == '1',
      'delete': bits.length > 3 && bits[3] == '1',
    };
  }

  static Map<String, bool> _fromBinaryValue(String module, int value) {
    if (module == 'employees') {
      return {
        'read_all': (value & (1 << 0)) != 0,
        'read_my': (value & (1 << 1)) != 0,
        'read_details': (value & (1 << 2)) != 0,
      };
    }
    return {
      'read': (value & (1 << 0)) != 0,
      'add': (value & (1 << 1)) != 0,
      'edit': (value & (1 << 2)) != 0,
      'delete': (value & (1 << 3)) != 0,
    };
  }

  static bool canRead(
    Map<String, Map<String, bool>> permissions,
    String moduleKey,
  ) =>
      permissions[moduleKey]?['read'] == true;
}

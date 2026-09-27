import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime config from `.env` (see `.env.example`) or `--dart-define` overrides.
class Env {
  static String get apiBaseUrl => _value('API_BASE_URL', fallback: 'http://localhost:5001');

  static String get aesKeyHex => _value('AES_KEY_HEX');

  /// Same as server `NEXTAUTH_SECRET` / web NextAuth (JWT signing). Not used for
  /// password encryption; login uses [aesKeyHex] only.
  static String get nextAuthSecret => _value('NEXTAUTH_SECRET');

  static bool get attendancePlanBEnabled =>
      _value('ATTENDANCE_PLAN_B_ENABLED').toLowerCase() == 'true';

  static String get attendancePlanBUrl => _value('ATTENDANCE_PLAN_B_URL');

  /// Semver of the newest published build (e.g. `1.0.1`). Empty = skip prompts.
  static String get latestAppVersion => _value('LATEST_APP_VERSION');

  /// When true and [latestAppVersion] is newer, update dialog cannot be dismissed.
  static bool get forceAppUpdate =>
      _value('FORCE_APP_UPDATE').toLowerCase() == 'true';

  static String get iosStoreUrl => _value('IOS_STORE_URL');

  static String get androidStoreUrl => _value('ANDROID_STORE_URL');

  static bool get isConfigured => apiBaseUrl.isNotEmpty && aesKeyHex.isNotEmpty;

  static String _value(String key, {String fallback = ''}) {
    final fromDefine = _fromDefine(key);
    if (fromDefine.isNotEmpty) return fromDefine;
    return _stripQuotes(dotenv.env[key] ?? fallback);
  }

  static String _fromDefine(String key) {
    switch (key) {
      case 'API_BASE_URL':
        return const String.fromEnvironment('API_BASE_URL');
      case 'AES_KEY_HEX':
        return const String.fromEnvironment('AES_KEY_HEX');
      case 'NEXTAUTH_SECRET':
        return const String.fromEnvironment('NEXTAUTH_SECRET');
      case 'ATTENDANCE_PLAN_B_ENABLED':
        return const String.fromEnvironment('ATTENDANCE_PLAN_B_ENABLED');
      case 'ATTENDANCE_PLAN_B_URL':
        return const String.fromEnvironment('ATTENDANCE_PLAN_B_URL');
      case 'LATEST_APP_VERSION':
        return const String.fromEnvironment('LATEST_APP_VERSION');
      case 'FORCE_APP_UPDATE':
        return const String.fromEnvironment('FORCE_APP_UPDATE');
      case 'IOS_STORE_URL':
        return const String.fromEnvironment('IOS_STORE_URL');
      case 'ANDROID_STORE_URL':
        return const String.fromEnvironment('ANDROID_STORE_URL');
      default:
        return '';
    }
  }

  static String _stripQuotes(String value) {
    final v = value.trim();
    if (v.length >= 2 &&
        ((v.startsWith("'") && v.endsWith("'")) ||
            (v.startsWith('"') && v.endsWith('"')))) {
      return v.substring(1, v.length - 1);
    }
    return v;
  }
}

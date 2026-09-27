import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env.dart';

class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
  });

  final String version;
  final String buildNumber;

  String get displayLabel => 'v$version ($buildNumber)';
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.current,
    required this.latestConfigured,
    required this.updateAvailable,
    required this.forceUpdate,
    this.storeUrl,
  });

  final AppVersionInfo current;
  final String? latestConfigured;
  final bool updateAvailable;
  final bool forceUpdate;
  final String? storeUrl;
}

/// Compares installed version to [Env.latestAppVersion] and opens store URLs.
class AppUpdateService {
  Future<AppVersionInfo> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      version: info.version,
      buildNumber: info.buildNumber,
    );
  }

  Future<AppUpdateCheckResult> checkForUpdates() async {
    final current = await currentVersion();
    final latest = Env.latestAppVersion.trim();
    final latestConfigured = latest.isEmpty ? null : latest;
    final updateAvailable = latestConfigured != null &&
        isNewerVersion(latestConfigured, current.version);
    return AppUpdateCheckResult(
      current: current,
      latestConfigured: latestConfigured,
      updateAvailable: updateAvailable,
      forceUpdate: updateAvailable && Env.forceAppUpdate,
      storeUrl: storeUrlForPlatform(),
    );
  }

  String? storeUrlForPlatform() {
    if (kIsWeb) return Env.androidStoreUrl.isNotEmpty
        ? Env.androidStoreUrl
        : (Env.iosStoreUrl.isNotEmpty ? Env.iosStoreUrl : null);
    if (!kIsWeb && Platform.isIOS) {
      return Env.iosStoreUrl.isNotEmpty ? Env.iosStoreUrl : null;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return Env.androidStoreUrl.isNotEmpty ? Env.androidStoreUrl : null;
    }
    return null;
  }

  Future<bool> openStore({String? url}) async {
    final target = (url ?? storeUrlForPlatform())?.trim();
    if (target == null || target.isEmpty) return false;
    final uri = Uri.tryParse(target);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Returns true when [candidate] is greater than [current] (semver-ish).
  static bool isNewerVersion(String candidate, String current) {
    final a = _parseParts(candidate);
    final b = _parseParts(current);
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av > bv) return true;
      if (av < bv) return false;
    }
    return false;
  }

  static List<int> _parseParts(String raw) {
    final cleaned = raw.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    return cleaned
        .split(RegExp(r'[^0-9]+'))
        .where((p) => p.isNotEmpty)
        .map(int.parse)
        .toList();
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location_availability.dart';
import '../models/check_in_geo.dart';
import 'web_geo_capture_stub.dart'
    if (dart.library.html) 'web_geo_capture_web.dart' as web_geo;

/// Thin seam over [Geolocator] so the fix strategy can be unit-tested.
abstract class PositionSource {
  Future<Position?> lastKnown({bool forceLocationManager = false});
  Future<Position> current(LocationSettings settings);
}

class GeolocatorPositionSource implements PositionSource {
  const GeolocatorPositionSource();

  @override
  Future<Position?> lastKnown({bool forceLocationManager = false}) =>
      Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: forceLocationManager,
      );

  @override
  Future<Position> current(LocationSettings settings) =>
      Geolocator.getCurrentPosition(locationSettings: settings);
}

class FixAttempt {
  const FixAttempt(this.label, this.settings);

  final String label;
  final LocationSettings settings;
}

/// Last-known fixes younger than this are used without waiting for a new lock.
const Duration freshFixMaxAge = Duration(minutes: 5);

bool isFreshFix(Position position, DateTime now, {Duration maxAge = freshFixMaxAge}) {
  final age = now.toUtc().difference(position.timestamp.toUtc());
  return age <= maxAge;
}

/// Ordered fresh-fix attempts. Balanced (network/fused) first because
/// high accuracy waits for a satellite lock that often never arrives indoors.
List<FixAttempt> buildFixAttempts(TargetPlatform platform) {
  if (platform == TargetPlatform.android) {
    return [
      FixAttempt(
        'android-medium',
        AndroidSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 7),
        ),
      ),
      FixAttempt(
        'android-high',
        AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        ),
      ),
      FixAttempt(
        'android-location-manager',
        AndroidSettings(
          accuracy: LocationAccuracy.medium,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 6),
        ),
      ),
    ];
  }
  return const [
    FixAttempt(
      'medium',
      LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 8),
      ),
    ),
    FixAttempt(
      'high',
      LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    ),
  ];
}

class LocationService {
  LocationService({
    PositionSource source = const GeolocatorPositionSource(),
    TargetPlatform? platform,
    DateTime Function()? clock,
  })  : _source = source,
        _platform = platform,
        _clock = clock ?? DateTime.now;

  final PositionSource _source;
  final TargetPlatform? _platform;
  final DateTime Function() _clock;

  static const Duration _lastKnownTimeout = Duration(seconds: 3);

  Future<bool> ensurePermission() async {
    final availability = await diagnose();
    return availability.ok;
  }

  /// Inspect service + permission without capturing a fix.
  Future<LocationAvailability> diagnose() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const LocationAvailability.blocked(
        LocationBlockReason.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationAvailability.blocked(
        LocationBlockReason.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      return const LocationAvailability.blocked(
        LocationBlockReason.permissionDenied,
      );
    }

    return const LocationAvailability.ready();
  }

  Future<bool> openSettingsFor(LocationAvailability availability) {
    switch (availability.settingsTarget) {
      case LocationSettingsTarget.systemLocation:
        return Geolocator.openLocationSettings();
      case LocationSettingsTarget.appSettings:
        return Geolocator.openAppSettings();
    }
  }

  /// Best-effort GPS for check-in (web + mobile). Returns null if denied/unavailable.
  Future<CheckInGeo?> captureOptional({
    Duration webTimeout = const Duration(seconds: 15),
  }) async {
    try {
      final webGeo = await web_geo.captureWebOptional(timeout: webTimeout);
      if (webGeo != null) return webGeo;
    } catch (e) {
      _log('web capture failed: $e');
    }

    try {
      final availability = await diagnose();
      if (!availability.ok) {
        _log('not available: ${availability.blockReason}');
        return null;
      }
    } catch (e) {
      _log('diagnose failed: $e');
      return null;
    }

    return captureFix();
  }

  /// Fix strategy once service + permission are known to be OK.
  @visibleForTesting
  Future<CheckInGeo?> captureFix() async {
    final last = await _lastKnown(forceLocationManager: false);
    if (last != null && isFreshFix(last, _clock())) {
      _log('using fresh last-known (acc=${last.accuracy}m, at=${last.timestamp})');
      return _toGeo(last);
    }

    for (final attempt in buildFixAttempts(_platform ?? defaultTargetPlatform)) {
      try {
        final position = await _source.current(attempt.settings);
        _log('${attempt.label} ok (acc=${position.accuracy}m)');
        return _toGeo(position);
      } catch (e) {
        _log('${attempt.label} failed: ${e.runtimeType} $e');
      }
    }

    final fallback = last ??
        ((_platform ?? defaultTargetPlatform) == TargetPlatform.android
            ? await _lastKnown(forceLocationManager: true)
            : null);
    if (fallback != null) {
      _log('using stale last-known (at=${fallback.timestamp})');
      return _toGeo(fallback);
    }

    _log('no fix available');
    return null;
  }

  Future<Position?> _lastKnown({required bool forceLocationManager}) async {
    try {
      final position = await _source
          .lastKnown(forceLocationManager: forceLocationManager)
          .timeout(_lastKnownTimeout);
      _log('lastKnown(lm=$forceLocationManager)=${position == null ? 'null' : position.timestamp}');
      return position;
    } catch (e) {
      _log('lastKnown(lm=$forceLocationManager) failed: $e');
      return null;
    }
  }

  CheckInGeo _toGeo(Position position) => CheckInGeo(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAtIso: _clock().toUtc().toIso8601String(),
      );

  void _log(String message) => debugPrint('[gps] $message');
}

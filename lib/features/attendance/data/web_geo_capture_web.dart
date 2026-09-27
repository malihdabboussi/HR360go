// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import '../models/check_in_geo.dart';

Future<CheckInGeo?> captureWebOptional({required Duration timeout}) async {
  final geolocation = html.window.navigator.geolocation;

  try {
    final pos = await geolocation
        .getCurrentPosition(
          enableHighAccuracy: true,
          timeout: timeout,
          maximumAge: Duration.zero,
        )
        .timeout(timeout + const Duration(seconds: 2));
    final coords = pos.coords;
    if (coords == null) return null;
    return CheckInGeo(
      latitude: (coords.latitude ?? 0).toDouble(),
      longitude: (coords.longitude ?? 0).toDouble(),
      accuracyMeters: (coords.accuracy ?? 0).toDouble(),
      capturedAtIso: DateTime.now().toUtc().toIso8601String(),
    );
  } catch (_) {
    try {
      final pos = await geolocation
          .watchPosition(
            enableHighAccuracy: true,
            timeout: timeout,
            maximumAge: Duration.zero,
          )
          .first
          .timeout(timeout + const Duration(seconds: 2));
      final coords = pos.coords;
      if (coords == null) return null;
      return CheckInGeo(
        latitude: (coords.latitude ?? 0).toDouble(),
        longitude: (coords.longitude ?? 0).toDouble(),
        accuracyMeters: (coords.accuracy ?? 0).toDouble(),
        capturedAtIso: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {
      return null;
    }
  }
}

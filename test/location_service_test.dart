import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hr360_go/features/attendance/data/location_service.dart';

final _now = DateTime.utc(2026, 9, 27, 12);

Position _pos(double lat, {required DateTime at}) => Position(
      latitude: lat,
      longitude: 35.5,
      timestamp: at,
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _FakeSource implements PositionSource {
  _FakeSource({this.last, this.lastViaLocationManager, List<Object>? results})
      : results = results ?? [];

  final Position? last;
  final Position? lastViaLocationManager;

  /// One entry per `current` call: a [Position] to return or an error to throw.
  final List<Object> results;
  final List<LocationSettings> currentCalls = [];

  @override
  Future<Position?> lastKnown({bool forceLocationManager = false}) async =>
      forceLocationManager ? lastViaLocationManager : last;

  @override
  Future<Position> current(LocationSettings settings) async {
    currentCalls.add(settings);
    final next = results.isEmpty
        ? TimeoutException('gps')
        : results.removeAt(0);
    if (next is Position) return next;
    throw next;
  }
}

LocationService _service(_FakeSource source) => LocationService(
      source: source,
      platform: TargetPlatform.android,
      clock: () => _now,
    );

void main() {
  test('isFreshFix respects max age', () {
    expect(isFreshFix(_pos(1, at: _now.subtract(const Duration(minutes: 1))), _now), isTrue);
    expect(isFreshFix(_pos(1, at: _now.subtract(const Duration(minutes: 30))), _now), isFalse);
  });

  test('android attempts use AndroidSettings, balanced first, then location manager', () {
    final attempts = buildFixAttempts(TargetPlatform.android);
    expect(attempts.every((a) => a.settings is AndroidSettings), isTrue);
    expect(attempts.first.settings.accuracy, LocationAccuracy.medium);
    expect((attempts.last.settings as AndroidSettings).forceLocationManager, isTrue);
  });

  test('fresh last-known is returned without requesting a new fix', () async {
    final source = _FakeSource(
      last: _pos(33.1, at: _now.subtract(const Duration(minutes: 2))),
    );
    final geo = await _service(source).captureFix();
    expect(geo?.latitude, 33.1);
    expect(source.currentCalls, isEmpty);
  });

  test('stale last-known is skipped in favour of a fresh fix', () async {
    final source = _FakeSource(
      last: _pos(1, at: _now.subtract(const Duration(hours: 2))),
      results: [_pos(33.9, at: _now)],
    );
    final geo = await _service(source).captureFix();
    expect(geo?.latitude, 33.9);
    expect(source.currentCalls, hasLength(1));
  });

  test('falls through every attempt when earlier ones time out', () async {
    final source = _FakeSource(
      results: [TimeoutException('medium'), TimeoutException('high'), _pos(34.0, at: _now)],
    );
    final geo = await _service(source).captureFix();
    expect(geo?.latitude, 34.0);
    expect(source.currentCalls, hasLength(3));
  });

  test('uses stale last-known when no fresh fix arrives', () async {
    final source = _FakeSource(
      last: _pos(12.5, at: _now.subtract(const Duration(hours: 2))),
    );
    final geo = await _service(source).captureFix();
    expect(geo?.latitude, 12.5);
  });

  test('tries location-manager last-known before giving up on android', () async {
    final source = _FakeSource(
      lastViaLocationManager: _pos(7.7, at: _now.subtract(const Duration(hours: 1))),
    );
    final geo = await _service(source).captureFix();
    expect(geo?.latitude, 7.7);
  });

  test('returns null when nothing is available', () async {
    final geo = await _service(_FakeSource()).captureFix();
    expect(geo, isNull);
  });
}

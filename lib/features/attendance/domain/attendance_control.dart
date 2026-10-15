import 'dart:math' as math;

import '../models/check_in_geo.dart';
import 'shift_watch.dart';

/// Extra meters allowed beyond a geofence radius for GPS noise; capped so a
/// very poor fix cannot stretch the fence arbitrarily. Server applies the same rule.
const double geofenceMaxAccuracyBufferM = 100;

class AttendanceNfcCard {
  const AttendanceNfcCard({
    required this.id,
    required this.name,
    required this.serial,
  });

  final String id;
  final String name;

  /// Normalized uppercase hex UID (see [normalizeNfcSerial]).
  final String serial;

  factory AttendanceNfcCard.fromJson(Map<String, dynamic> json) =>
      AttendanceNfcCard(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        serial: normalizeNfcSerial('${json['serial'] ?? ''}'),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'serial': serial};
}

class AttendanceGeofence {
  const AttendanceGeofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;

  static AttendanceGeofence? tryParse(Map<String, dynamic> json) {
    final lat = _toDouble(json['latitude']);
    final lng = _toDouble(json['longitude']);
    final radius = _toDouble(json['radius_m'] ?? json['radiusM']);
    if (lat == null || lng == null || radius == null || radius <= 0) return null;
    return AttendanceGeofence(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      latitude: lat,
      longitude: lng,
      radiusM: radius,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius_m': radiusM,
      };
}

/// Effective rules for the signed-in employee, already resolved by the Server
/// (company switches + assignments to employee / department / policy profile).
/// Only active, assigned cards and locations are returned.
class AttendanceControlConfig {
  const AttendanceControlConfig({
    this.nfcRequired = false,
    this.geofenceRequired = false,
    this.nfcCards = const [],
    this.geofences = const [],
    this.shiftWatch = ShiftWatchConfig.none,
  });

  static const none = AttendanceControlConfig();

  final bool nfcRequired;
  final bool geofenceRequired;
  final List<AttendanceNfcCard> nfcCards;

  /// Assigned locations. Also sent when only auto check-out is on, so punches
  /// check them only when [geofenceRequired].
  final List<AttendanceGeofence> geofences;
  final ShiftWatchConfig shiftWatch;

  bool get hasRules => nfcRequired || geofenceRequired;

  factory AttendanceControlConfig.fromJson(dynamic raw) {
    var map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    if (map['data'] is Map) map = Map<String, dynamic>.from(map['data'] as Map);

    List<Map<String, dynamic>> listOf(String key) => map[key] is List
        ? (map[key] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];

    return AttendanceControlConfig(
      nfcRequired: map['nfc_required'] == true,
      geofenceRequired: map['geofence_required'] == true,
      nfcCards: listOf('nfc_cards')
          .map(AttendanceNfcCard.fromJson)
          .where((c) => c.serial.isNotEmpty)
          .toList(),
      geofences: listOf('geofences')
          .map(AttendanceGeofence.tryParse)
          .whereType<AttendanceGeofence>()
          .toList(),
      shiftWatch: ShiftWatchConfig.fromJson(map['shift_watch']),
    );
  }

  Map<String, dynamic> toJson() => {
        'nfc_required': nfcRequired,
        'geofence_required': geofenceRequired,
        'nfc_cards': nfcCards.map((c) => c.toJson()).toList(),
        'geofences': geofences.map((g) => g.toJson()).toList(),
        'shift_watch': shiftWatch.toJson(),
      };

  AttendanceNfcCard? cardForSerial(String serial) {
    final normalized = normalizeNfcSerial(serial);
    for (final card in nfcCards) {
      if (card.serial == normalized) return card;
    }
    return null;
  }
}

/// Same normalization as the web admin: separators stripped, uppercase hex.
String normalizeNfcSerial(String raw) =>
    raw.replaceAll(RegExp(r'[\s:\-]'), '').toUpperCase();

String nfcSerialFromBytes(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

double _degToRad(double deg) => deg * math.pi / 180;

/// Great-circle distance in meters.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusM = 6371000.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadiusM * math.asin(math.min(1, math.sqrt(a)));
}

class GeofenceCheck {
  const GeofenceCheck({
    required this.inside,
    this.matched,
    this.nearest,
    this.distanceToEdgeM,
  });

  final bool inside;
  final AttendanceGeofence? matched;
  final AttendanceGeofence? nearest;

  /// Meters the employee must move to reach the nearest fence (0 when inside).
  final double? distanceToEdgeM;
}

GeofenceCheck checkGeofences(CheckInGeo geo, List<AttendanceGeofence> fences) {
  if (fences.isEmpty) return const GeofenceCheck(inside: false);
  final buffer = geo.accuracyMeters.isFinite
      ? math.min(math.max(geo.accuracyMeters, 0), geofenceMaxAccuracyBufferM)
      : 0.0;

  AttendanceGeofence? nearest;
  double? nearestEdge;
  for (final fence in fences) {
    final distance =
        haversineMeters(geo.latitude, geo.longitude, fence.latitude, fence.longitude);
    if (distance <= fence.radiusM + buffer) {
      return GeofenceCheck(inside: true, matched: fence, nearest: fence, distanceToEdgeM: 0);
    }
    final edge = distance - fence.radiusM - buffer;
    if (nearestEdge == null || edge < nearestEdge) {
      nearestEdge = edge;
      nearest = fence;
    }
  }
  return GeofenceCheck(inside: false, nearest: nearest, distanceToEdgeM: nearestEdge);
}

String formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

double? _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/features/attendance/data/nfc_reader.dart';
import 'package:hr360_go/features/attendance/domain/attendance_checkin_errors.dart';
import 'package:hr360_go/features/attendance/domain/attendance_control.dart';
import 'package:hr360_go/features/attendance/domain/pending_attendance_punch.dart';
import 'package:hr360_go/features/attendance/models/attendance_check_in_request.dart';
import 'package:hr360_go/features/attendance/models/check_in_geo.dart';

CheckInGeo geoAt(double lat, double lng, {double accuracy = 10}) => CheckInGeo(
      latitude: lat,
      longitude: lng,
      accuracyMeters: accuracy,
      capturedAtIso: '2026-09-28T08:00:00.000Z',
    );

const office = AttendanceGeofence(
  id: 'g1',
  name: 'Head office',
  latitude: 36.8065,
  longitude: 10.1815,
  radiusM: 100,
);

void main() {
  group('AttendanceControlConfig.fromJson', () {
    test('parses rules, normalizes serials, drops invalid entries', () {
      final config = AttendanceControlConfig.fromJson({
        'data': {
          'nfc_required': true,
          'geofence_required': true,
          'nfc_cards': [
            {'id': 'c1', 'name': 'Main door', 'serial': '04:a1:b2:c3'},
            {'id': 'c2', 'name': 'Blank', 'serial': ''},
          ],
          'geofences': [
            {'id': 'g1', 'name': 'HQ', 'latitude': '36.8', 'longitude': 10.18, 'radius_m': 150},
            {'id': 'g2', 'name': 'Broken', 'latitude': null, 'longitude': 1, 'radius_m': 10},
          ],
        },
      });
      expect(config.nfcRequired, isTrue);
      expect(config.geofenceRequired, isTrue);
      expect(config.nfcCards.map((c) => c.serial), ['04A1B2C3']);
      expect(config.geofences.single.latitude, 36.8);
      expect(config.cardForSerial('04-A1-B2-C3')?.name, 'Main door');
      expect(config.cardForSerial('DEADBEEF'), isNull);
    });

    test('missing or malformed body means no rules', () {
      expect(AttendanceControlConfig.fromJson(null).hasRules, isFalse);
      expect(AttendanceControlConfig.fromJson('oops').hasRules, isFalse);
    });

    test('round-trips through the cache JSON', () {
      const config = AttendanceControlConfig(
        nfcRequired: true,
        nfcCards: [AttendanceNfcCard(id: 'c1', name: 'Door', serial: '04A1B2C3')],
        geofences: [office],
      );
      final restored = AttendanceControlConfig.fromJson(config.toJson());
      expect(restored.nfcRequired, isTrue);
      expect(restored.geofenceRequired, isFalse);
      expect(restored.nfcCards.single.serial, '04A1B2C3');
      expect(restored.geofences.single.radiusM, 100);
    });
  });

  group('geofence check', () {
    test('haversine is roughly right (1 degree latitude ~ 111 km)', () {
      expect(haversineMeters(0, 0, 1, 0), closeTo(111195, 50));
    });

    test('inside the radius passes', () {
      final check = checkGeofences(geoAt(36.8066, 10.1816), [office]);
      expect(check.inside, isTrue);
      expect(check.matched?.id, 'g1');
    });

    test('just outside the radius passes thanks to the accuracy buffer', () {
      // ~130 m north of center: outside 100 m, inside 100 + 40 m accuracy.
      final check = checkGeofences(geoAt(36.80767, 10.1815, accuracy: 40), [office]);
      expect(check.inside, isTrue);
    });

    test('accuracy buffer is capped', () {
      // ~1 km away with a terrible 5 km fix must still be outside.
      final check = checkGeofences(geoAt(36.8155, 10.1815, accuracy: 5000), [office]);
      expect(check.inside, isFalse);
      expect(check.nearest?.name, 'Head office');
      expect(check.distanceToEdgeM, greaterThan(700));
    });

    test('no fences means outside', () {
      expect(checkGeofences(geoAt(0, 0), const []).inside, isFalse);
    });

    test('formats distance', () {
      expect(formatDistance(349.6), '350 m');
      expect(formatDistance(2345), '2.3 km');
    });
  });

  group('extractNfcTagSerial', () {
    test('reads Android NfcA identifier', () {
      final serial = extractNfcTagSerial({
        'nfca': {
          'identifier': Uint8List.fromList([0x04, 0xA1, 0xB2, 0xC3]),
          'atqa': Uint8List.fromList([0x44, 0x00]),
        },
        'mifareultralight': {'type': 2},
      });
      expect(serial, '04A1B2C3');
    });

    test('reads iOS MiFare identifier and FeliCa currentIDm', () {
      expect(
        extractNfcTagSerial({
          'mifare': {'identifier': [4, 26, 255, 1]},
        }),
        '041AFF01',
      );
      expect(
        extractNfcTagSerial({
          'felica': {'currentIDm': [1, 2, 3, 4, 5, 6, 7, 8]},
        }),
        '0102030405060708',
      );
    });

    test('returns null when no UID is present', () {
      expect(extractNfcTagSerial({'ndef': {'isWritable': true}}), isNull);
    });
  });

  group('pending punch keeps the NFC serial for retries', () {
    test('request -> pending -> JSON -> request', () {
      final punch = buildPendingPunchFromInput(
        AttendanceCheckInRequest(
          timeZone: 'Africa/Tunis',
          checkinTime: '2026-09-28T08:00:00.000Z',
          geo: geoAt(36.8, 10.18),
          nfcSerial: '04A1B2C3',
        ),
        const BuildPendingPunchMeta(
          expectedAction: PendingAttendancePunchAction.checkOut,
        ),
      );
      final restored = PendingAttendancePunch.fromJson(punch.toJson())!;
      final request = punchToAttendanceRequest(restored.copyWith(attempts: 2));
      expect(request.nfcSerial, '04A1B2C3');
      expect(request.geo?.latitude, 36.8);
    });
  });

  group('attendanceControlRejection', () {
    DioException rejection(dynamic body, {int status = 403}) => DioException(
          requestOptions: RequestOptions(path: '/'),
          response: Response(
            requestOptions: RequestOptions(path: '/'),
            statusCode: status,
            data: body,
          ),
          type: DioExceptionType.badResponse,
        );

    test('prefers the server message for a known code', () {
      expect(
        attendanceControlRejection(
          rejection({'code': 'OUTSIDE_GEOFENCE', 'message': 'You are 300 m from HQ.'}),
        ),
        'You are 300 m from HQ.',
      );
    });

    test('falls back to built-in copy', () {
      expect(
        attendanceControlRejection(rejection({'code': 'nfc_not_assigned'})),
        'This NFC card is not assigned to you.',
      );
    });

    test('ignores unrelated errors', () {
      expect(attendanceControlRejection(rejection({'code': 'OTHER'})), isNull);
      expect(attendanceControlRejection(StateError('x')), isNull);
    });
  });
}

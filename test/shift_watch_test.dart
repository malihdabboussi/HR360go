import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/features/attendance/domain/attendance_control.dart';
import 'package:hr360_go/features/attendance/domain/shift_watch.dart';

void main() {
  group('ShiftWatchConfig', () {
    test('parses the server shift_watch block and survives the cache round trip', () {
      final config = AttendanceControlConfig.fromJson({
        'geofence_required': false,
        'geofences': [
          {'id': 'g1', 'name': 'Head office', 'latitude': 34.4, 'longitude': 35.8, 'radius_m': 100},
        ],
        'shift_watch': {
          'auto_checkout_on_exit': true,
          'exit_grace_minutes': 5,
          'checkout_reminder_enabled': true,
          'checkout_reminder_after_minutes': 20,
          'open_attendance_id': 'a1',
          'shift_end_at': '2026-10-15T14:00:00.000Z',
          'reminder_at': '2026-10-15T14:20:00.000Z',
        },
      });
      final watch = config.shiftWatch;
      expect(watch.autoCheckoutOnExit, isTrue);
      expect(watch.exitGraceMinutes, 5);
      expect(watch.reminderAfterMinutes, 20);
      expect(watch.openAttendanceId, 'a1');
      expect(watch.reminderAt, DateTime.utc(2026, 10, 15, 14, 20));
      // Geofence on punches stays off even though locations are sent.
      expect(config.geofenceRequired, isFalse);
      expect(config.geofences, hasLength(1));

      final cached = AttendanceControlConfig.fromJson(config.toJson());
      expect(cached.shiftWatch.toJson(), watch.toJson());
    });

    test('old servers without shift_watch → everything off', () {
      final config = AttendanceControlConfig.fromJson({'nfc_required': true});
      expect(config.shiftWatch.enabled, isFalse);
      expect(config.shiftWatch.exitGraceMinutes, 10);
    });
  });

  group('rules', () {
    const on = ShiftWatchConfig(
      autoCheckoutOnExit: true,
      reminderEnabled: true,
    );

    test('locations are watched only while checked in with locations assigned', () {
      expect(shouldWatchGeofences(on, isOpen: true, fenceCount: 1), isTrue);
      expect(shouldWatchGeofences(on, isOpen: false, fenceCount: 1), isFalse);
      expect(shouldWatchGeofences(on, isOpen: true, fenceCount: 0), isFalse);
      expect(
        shouldWatchGeofences(ShiftWatchConfig.none, isOpen: true, fenceCount: 1),
        isFalse,
      );
    });

    test('reminder is scheduled only for a future time while checked in', () {
      final now = DateTime.utc(2026, 10, 15, 12);
      final future = ShiftWatchConfig(reminderEnabled: true, reminderAt: DateTime.utc(2026, 10, 15, 14, 15));
      final past = ShiftWatchConfig(reminderEnabled: true, reminderAt: DateTime.utc(2026, 10, 15, 11));
      expect(nextReminderTime(future, isOpen: true, now: now), DateTime.utc(2026, 10, 15, 14, 15));
      expect(nextReminderTime(future, isOpen: false, now: now), isNull);
      expect(nextReminderTime(past, isOpen: true, now: now), isNull);
      expect(nextReminderTime(on, isOpen: true, now: now), isNull); // no scheduled end
    });

    test('snooze is at least a minute away', () {
      final now = DateTime.utc(2026, 10, 15, 12);
      expect(snoozeReminderTime(now), DateTime.utc(2026, 10, 15, 13));
      expect(snoozeReminderTime(now, snooze: Duration.zero), DateTime.utc(2026, 10, 15, 12, 1));
    });

    test('geofence ids are prefixed and recognised', () {
      final id = shiftWatchGeofenceId('g1');
      expect(id, 'hr360_shift_g1');
      expect(fenceIdFromShiftWatchId(id), 'g1');
      expect(fenceIdFromShiftWatchId('someone_else'), isNull);
    });

    test('exit message mentions the place and the grace period', () {
      expect(
        exitNotificationBody('Head office', 10),
        'You left Head office. You will be checked out in 10 min unless you come back.',
      );
      expect(
        exitNotificationBody('', 0),
        'You left your work location. You will be checked out automatically.',
      );
    });
  });
}

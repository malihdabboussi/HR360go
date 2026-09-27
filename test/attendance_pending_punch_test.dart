import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/features/attendance/domain/attendance_pending_punch_confirm.dart';
import 'package:hr360_go/features/attendance/domain/pending_attendance_punch.dart';
import 'package:hr360_go/features/attendance/models/attendance_check_in_request.dart';

const checkinTime = '2026-06-04T14:25:34.756Z';

void main() {
  group('pending punch', () {
    test('builds stable id from tenant employee action time', () {
      final id = buildPendingPunchId(
        tenantId: 't1',
        employeeId: 'e1',
        expectedAction: PendingAttendancePunchAction.checkIn,
        checkinTime: checkinTime,
      );
      expect(id, 't1:e1:in:$checkinTime');
    });

    test('shouldPollQueuedPunch only when queued without optimistic UI', () {
      final punch = buildPendingPunchFromInput(
        const AttendanceCheckInRequest(
          timeZone: 'Africa/Tunis',
          checkinTime: checkinTime,
        ),
        const BuildPendingPunchMeta(
          expectedAction: PendingAttendancePunchAction.checkIn,
        ),
      );
      final queued = punch.copyWith(status: PendingAttendancePunchStatus.queued);
      expect(shouldPollQueuedPunch(queued), isTrue);
      expect(
        shouldPollQueuedPunch(
          queued.copyWith(optimisticUiApplied: true),
        ),
        isFalse,
      );
    });

    test('isAttendanceStatusConfirmed for check-in', () {
      final punch = buildPendingPunchFromInput(
        const AttendanceCheckInRequest(
          timeZone: 'Africa/Tunis',
          checkinTime: checkinTime,
        ),
        BuildPendingPunchMeta(
          expectedAction: PendingAttendancePunchAction.checkIn,
          baselineStatus: const AttendanceStatusSnapshot(
            checkinStatus: false,
            checkoutTime: '17:00:00',
          ),
        ),
      );
      expect(
        isAttendanceStatusConfirmed(
          punch,
          const AttendanceStatusSnapshot(
            checkinStatus: true,
            checkinTime: '09:00:00',
          ),
        ),
        isTrue,
      );
    });

    test('confirms whenever open/closed flips vs baseline', () {
      // Expected check-in, but server closed the open session (toggle out).
      final punch = buildPendingPunchFromInput(
        const AttendanceCheckInRequest(
          timeZone: 'Africa/Tunis',
          checkinTime: checkinTime,
        ),
        BuildPendingPunchMeta(
          expectedAction: PendingAttendancePunchAction.checkIn,
          baselineStatus: const AttendanceStatusSnapshot(
            checkinStatus: true,
            checkinTime: '09:00:00',
          ),
        ),
      );
      expect(
        isAttendanceStatusConfirmed(
          punch,
          const AttendanceStatusSnapshot(
            checkinStatus: true,
            checkinTime: '09:00:00',
            checkoutTime: '17:05:00',
          ),
        ),
        isTrue,
      );
    });

    test('shouldRetryPendingPunch stops at max attempts', () {
      final punch = buildPendingPunchFromInput(
        const AttendanceCheckInRequest(
          timeZone: 'Africa/Tunis',
          checkinTime: checkinTime,
        ),
        const BuildPendingPunchMeta(
          expectedAction: PendingAttendancePunchAction.checkIn,
        ),
      );
      expect(
        shouldRetryPendingPunch(
          punch.copyWith(
            status: PendingAttendancePunchStatus.failed,
            attempts: maxPendingPunchRetryAttempts,
          ),
          null,
        ),
        isFalse,
      );
    });

    test('round-trips JSON', () {
      final punch = buildPendingPunchFromInput(
        const AttendanceCheckInRequest(
          timeZone: 'Africa/Tunis',
          checkinTime: checkinTime,
        ),
        const BuildPendingPunchMeta(
          expectedAction: PendingAttendancePunchAction.checkOut,
          tenantId: 't1',
          employeeId: 'e1',
        ),
      );
      final restored = PendingAttendancePunch.fromJson(punch.toJson());
      expect(restored?.expectedAction, PendingAttendancePunchAction.checkOut);
      expect(restored?.checkinTime, checkinTime);
    });
  });
}

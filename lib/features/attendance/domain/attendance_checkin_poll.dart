import 'dart:async';

import '../data/attendance_repository.dart';
import '../domain/attendance_checkin_config.dart';
import '../domain/attendance_pending_punch_confirm.dart';
import '../domain/pending_attendance_punch.dart';
import '../models/check_in_status.dart';

Future<bool> pollAttendanceCheckInStatusUntilConfirmed(
  AttendanceRepository repository,
  PendingAttendancePunch punch,
  String timeZone,
) async {
  await Future<void>.delayed(
    const Duration(milliseconds: attendanceStatusPollInitialDelayMs),
  );

  for (var attempt = 0; attempt < attendanceStatusPollAttempts; attempt++) {
    final status = await repository.getStatus(timeZone);
    final snapshot = AttendanceStatusSnapshot(
      checkinStatus: status.isCheckedIn,
      checkinTime: status.checkinTime,
      checkoutTime: status.checkoutTime,
    );
    if (isAttendanceStatusConfirmed(punch, snapshot)) {
      return true;
    }

    if (attempt < attendanceStatusPollAttempts - 1) {
      await Future<void>.delayed(
        const Duration(milliseconds: attendanceStatusPollIntervalMs),
      );
    }
  }

  return false;
}

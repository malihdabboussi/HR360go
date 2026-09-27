import 'pending_attendance_punch.dart';

class AttendanceStatusSnapshot {
  const AttendanceStatusSnapshot({
    this.checkinStatus,
    this.checkinTime,
    this.checkoutTime,
  });

  final bool? checkinStatus;
  final String? checkinTime;
  final String? checkoutTime;

  factory AttendanceStatusSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AttendanceStatusSnapshot();
    return AttendanceStatusSnapshot(
      checkinStatus: json['checkin_status'] as bool?,
      checkinTime: json['checkin_time']?.toString(),
      checkoutTime: json['checkout_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'checkin_status': checkinStatus,
        'checkin_time': checkinTime,
        'checkout_time': checkoutTime,
      };
}

AttendanceStatusSnapshot? captureAttendanceStatusSnapshot(dynamic status) {
  if (status is! Map) return null;
  return AttendanceStatusSnapshot.fromJson(
    Map<String, dynamic>.from(status),
  );
}

bool isOpenAttendanceSnapshot(AttendanceStatusSnapshot s) =>
    s.checkinStatus == true &&
    (s.checkoutTime == null || s.checkoutTime!.isEmpty);

/// Server toggle applied when open/closed state flipped vs punch baseline.
bool isAttendanceToggleApplied(
  AttendanceStatusSnapshot? baseline,
  AttendanceStatusSnapshot current,
) {
  if (baseline == null) return false;
  return isOpenAttendanceSnapshot(baseline) != isOpenAttendanceSnapshot(current);
}

bool isAttendanceStatusConfirmed(
  PendingAttendancePunch punch,
  AttendanceStatusSnapshot current,
) {
  final baseline = punch.baselineStatus;

  // Backend Checkin is a toggle — if open/closed flipped, the queued event landed
  // even when the client expected the opposite direction (stale local status).
  if (isAttendanceToggleApplied(baseline, current)) {
    return true;
  }

  if (punch.expectedAction == PendingAttendancePunchAction.checkIn) {
    final nowIn = isOpenAttendanceSnapshot(current);
    if (baseline == null) return nowIn;
    final wasOut = !isOpenAttendanceSnapshot(baseline);
    return wasOut && nowIn;
  }

  final nowOut = !isOpenAttendanceSnapshot(current);
  if (baseline == null) return nowOut;
  final wasIn = isOpenAttendanceSnapshot(baseline);
  return wasIn && nowOut;
}

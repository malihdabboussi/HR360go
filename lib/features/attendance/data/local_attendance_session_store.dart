import 'package:hive/hive.dart';

import '../domain/attendance_pending_punch_confirm.dart';
import '../domain/pending_attendance_punch.dart';

const localAttendanceSessionKey = 'hr360_local_attendance_session';

class LocalAttendanceSession {
  const LocalAttendanceSession({
    required this.checkinTime,
    required this.timeZone,
    required this.isCheckedIn,
    this.employeeId,
    this.tenantId,
  });

  final String checkinTime;
  final String timeZone;
  final bool isCheckedIn;
  final String? employeeId;
  final String? tenantId;

  static const source = 'plan_b';

  Map<String, dynamic> toJson() => {
        'checkinTime': checkinTime,
        'timeZone': timeZone,
        'isCheckedIn': isCheckedIn,
        'source': source,
        'employeeId': employeeId,
        'tenantId': tenantId,
      };

  static LocalAttendanceSession? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final s = Map<String, dynamic>.from(raw);
    if (s['source'] != source) return null;
    if (s['checkinTime'] == null || s['timeZone'] == null) return null;
    if (s['isCheckedIn'] is! bool) return null;
    return LocalAttendanceSession(
      checkinTime: s['checkinTime'].toString(),
      timeZone: s['timeZone'].toString(),
      isCheckedIn: s['isCheckedIn'] as bool,
      employeeId: s['employeeId']?.toString(),
      tenantId: s['tenantId']?.toString(),
    );
  }
}

LocalAttendanceSession buildLocalSessionFromPunch(
  PendingAttendancePunch punch, {
  String? employeeId,
  String? tenantId,
}) {
  return LocalAttendanceSession(
    checkinTime: punch.checkinTime,
    timeZone: punch.timeZone,
    isCheckedIn: punch.expectedAction == PendingAttendancePunchAction.checkIn,
    employeeId: employeeId,
    tenantId: tenantId,
  );
}

bool isLocalAttendanceSessionReconciled(
  LocalAttendanceSession session,
  AttendanceStatusSnapshot current,
) {
  if (session.isCheckedIn) {
    return current.checkinStatus == true &&
        (current.checkoutTime == null || current.checkoutTime!.isEmpty);
  }
  return current.checkinStatus != true ||
      (current.checkoutTime != null && current.checkoutTime!.isNotEmpty);
}

class LocalAttendanceSessionStore {
  static const boxName = 'attendance_local_session';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  LocalAttendanceSession? get() {
    final raw = _box?.get(localAttendanceSessionKey);
    if (raw is! Map) return null;
    return LocalAttendanceSession.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> save(LocalAttendanceSession session) async {
    await _box?.put(localAttendanceSessionKey, session.toJson());
  }

  Future<void> clear() async {
    await _box?.delete(localAttendanceSessionKey);
  }
}

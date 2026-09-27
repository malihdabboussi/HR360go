import '../../../config/env.dart';

const int attendancePrimaryCheckinTimeoutMs = 9000;
const int attendanceStatusPollInitialDelayMs = 2500;
const int attendanceStatusPollIntervalMs = 2000;
const int attendanceStatusPollAttempts = 5;
const String attendancePlanBSource = 'frontend_plan_b';
const int checkInCooldownSeconds = 6;

bool isAttendancePlanBEnabled() => Env.attendancePlanBEnabled;

String? getAttendancePlanBEndpointUrl() {
  final base = Env.attendancePlanBUrl.trim();
  if (base.isEmpty) return null;
  return '${base.replaceAll(RegExp(r'/$'), '')}/attendance/emergency-checkin';
}

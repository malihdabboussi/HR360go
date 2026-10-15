/// Company "shift watch" rules (Server: attendance_shift_rules) plus the open
/// shift's times, as returned in `/mobile/attendance-control/me` → `shift_watch`.
///
/// - Auto check-out: while checked in, HR360 Go watches the employee's assigned
///   locations with OS geofencing and reports exits; the Server checks the
///   employee out at the exit time after [exitGraceMinutes] unless they return.
/// - Reminder: a local notification at [reminderAt] (scheduled end + delay).
class ShiftWatchConfig {
  const ShiftWatchConfig({
    this.autoCheckoutOnExit = false,
    this.exitGraceMinutes = 10,
    this.reminderEnabled = false,
    this.reminderAfterMinutes = 15,
    this.openAttendanceId,
    this.shiftEndAt,
    this.reminderAt,
  });

  static const none = ShiftWatchConfig();

  final bool autoCheckoutOnExit;
  final int exitGraceMinutes;
  final bool reminderEnabled;
  final int reminderAfterMinutes;

  /// Server's open attendance row (null when not checked in).
  final String? openAttendanceId;
  final DateTime? shiftEndAt;
  final DateTime? reminderAt;

  bool get enabled => autoCheckoutOnExit || reminderEnabled;

  factory ShiftWatchConfig.fromJson(dynamic raw) {
    if (raw is! Map) return none;
    final map = Map<String, dynamic>.from(raw);
    return ShiftWatchConfig(
      autoCheckoutOnExit: map['auto_checkout_on_exit'] == true,
      exitGraceMinutes: _toInt(map['exit_grace_minutes'], 10),
      reminderEnabled: map['checkout_reminder_enabled'] == true,
      reminderAfterMinutes: _toInt(map['checkout_reminder_after_minutes'], 15),
      openAttendanceId: _nonEmpty(map['open_attendance_id']),
      shiftEndAt: _toDate(map['shift_end_at']),
      reminderAt: _toDate(map['reminder_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'auto_checkout_on_exit': autoCheckoutOnExit,
        'exit_grace_minutes': exitGraceMinutes,
        'checkout_reminder_enabled': reminderEnabled,
        'checkout_reminder_after_minutes': reminderAfterMinutes,
        'open_attendance_id': openAttendanceId,
        'shift_end_at': shiftEndAt?.toUtc().toIso8601String(),
        'reminder_at': reminderAt?.toUtc().toIso8601String(),
      };
}

/// OS geofence ids are prefixed so ours never clash with anything else.
const shiftWatchGeofencePrefix = 'hr360_shift_';

String shiftWatchGeofenceId(String fenceId) => '$shiftWatchGeofencePrefix$fenceId';

String? fenceIdFromShiftWatchId(String id) => id.startsWith(shiftWatchGeofencePrefix)
    ? id.substring(shiftWatchGeofencePrefix.length)
    : null;

/// Watch the locations only while a shift is open and the company enabled it.
bool shouldWatchGeofences(
  ShiftWatchConfig config, {
  required bool isOpen,
  required int fenceCount,
}) =>
    isOpen && config.autoCheckoutOnExit && fenceCount > 0;

/// When to show the forgot-to-check-out reminder; null = nothing to schedule
/// (not checked in, disabled, no scheduled end, or already past: the Server's
/// web notification covers a reminder that came due while the app was closed).
DateTime? nextReminderTime(
  ShiftWatchConfig config, {
  required bool isOpen,
  required DateTime now,
}) {
  final at = config.reminderAt;
  if (!isOpen || !config.reminderEnabled || at == null) return null;
  return at.isAfter(now) ? at : null;
}

/// "Still working": ask again later, never earlier than a minute from now.
DateTime snoozeReminderTime(DateTime now, {Duration snooze = const Duration(hours: 1)}) =>
    now.add(snooze < const Duration(minutes: 1) ? const Duration(minutes: 1) : snooze);

String exitNotificationBody(String placeName, int graceMinutes) {
  final place = placeName.trim().isEmpty ? 'your work location' : placeName.trim();
  if (graceMinutes <= 0) {
    return 'You left $place. You will be checked out automatically.';
  }
  return 'You left $place. You will be checked out in $graceMinutes min unless you come back.';
}

int _toInt(dynamic v, int fallback) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String? _nonEmpty(dynamic v) {
  final s = v?.toString() ?? '';
  return s.isEmpty ? null : s;
}

DateTime? _toDate(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v)?.toUtc();
}

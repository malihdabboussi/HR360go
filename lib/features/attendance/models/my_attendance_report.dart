class MyAttendanceReport {
  const MyAttendanceReport({
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.workingDays,
    required this.workedHours,
    required this.overtime,
    required this.absentDays,
    required this.days,
    required this.latePunches,
  });

  final String employeeId;
  final String firstName;
  final String lastName;
  final int workingDays;
  final num workedHours;
  final num overtime;
  final int absentDays;
  final List<AttendanceDayReport> days;
  final List<LatePunchEntry> latePunches;

  factory MyAttendanceReport.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['daysReport'];
    final lateRaw = json['late_punch_array'];
    return MyAttendanceReport(
      employeeId: '${json['employee_id'] ?? ''}',
      firstName: '${json['first_name'] ?? ''}',
      lastName: '${json['last_name'] ?? ''}',
      workingDays: _asInt(json['working_days']),
      // Prefer decimal fields; API also sends H:MM strings in worked_hours/overtime.
      workedHours: _asHours(
        json['worked_hours_decimal'] ?? json['worked_hours'],
      ),
      overtime: _asHours(
        json['overtime_decimal'] ?? json['overtime'],
      ),
      absentDays: _asInt(json['absent_days']),
      days: daysRaw is List
          ? daysRaw
              .whereType<Map>()
              .map((e) => AttendanceDayReport.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : [],
      latePunches: lateRaw is List
          ? lateRaw
              .whereType<Map>()
              .map((e) => LatePunchEntry.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList()
          : [],
    );
  }

  AttendanceDayReport? dayForDate(String yyyyMmDd) {
    for (final d in days) {
      if (d.date == yyyyMmDd) return d;
    }
    return null;
  }

  int get presentDaysCount => days
      .where((d) =>
          d.status == 'present' ||
          d.status == 'late' ||
          d.status == 'working' ||
          d.status == 'flat scheduled')
      .length;

  double get attendanceRatePercent =>
      workingDays > 0 ? (presentDaysCount / workingDays) * 100 : 0;
}

class AttendanceDayReport {
  const AttendanceDayReport({
    required this.date,
    required this.dayName,
    required this.status,
    required this.scheduled,
    required this.punched,
    this.checkInTime,
    this.checkOutTime,
    required this.isLate,
    required this.lateMinutes,
    required this.totalTimeHours,
    required this.overtimeHoursDay,
    required this.notes,
    required this.punchErrors,
    required this.attendancePortal,
    this.checkinAddress,
    this.checkinLatitude,
    this.checkinLongitude,
    this.checkinAccuracyM,
    this.scheduleType,
    this.attendanceCyclesCount = 0,
  });

  final String date;
  final String dayName;
  final String status;
  final bool scheduled;
  final bool punched;
  final String? checkInTime;
  final String? checkOutTime;
  final bool isLate;
  final int lateMinutes;
  final double totalTimeHours;
  final double overtimeHoursDay;
  final String notes;
  final String punchErrors;
  final String attendancePortal;
  final String? checkinAddress;
  final String? checkinLatitude;
  final String? checkinLongitude;
  final num? checkinAccuracyM;
  final String? scheduleType;
  final int attendanceCyclesCount;

  bool get hasLocation =>
      (checkinAddress != null && checkinAddress!.isNotEmpty) ||
      (checkinLatitude != null && checkinLatitude.toString().isNotEmpty);

  factory AttendanceDayReport.fromJson(Map<String, dynamic> json) {
    final cycles = json['attendance_cycles'];
    return AttendanceDayReport(
      date: '${json['date'] ?? ''}',
      dayName: '${json['day_name'] ?? ''}',
      status: '${json['status'] ?? ''}',
      scheduled: json['scheduled'] == true,
      punched: json['punched'] == true,
      checkInTime: json['check_in_time']?.toString(),
      checkOutTime: json['check_out_time']?.toString(),
      isLate: json['isLate'] == true,
      lateMinutes: _asInt(json['lateMinutes']),
      totalTimeHours: _asHours(
        json['total_time_decimal_hours'] ??
            json['total_time_decimal'] ??
            json['total_time'],
      ).toDouble(),
      overtimeHoursDay: _asHours(
        json['overtime_hours_day_decimal'] ?? json['overtime_hours_day'],
      ).toDouble(),
      notes: '${json['notes'] ?? ''}',
      punchErrors: '${json['punch_errors'] ?? ''}',
      attendancePortal: '${json['attendance_portal'] ?? ''}',
      checkinAddress: json['checkin_address']?.toString(),
      checkinLatitude: json['checkin_latitude']?.toString(),
      checkinLongitude: json['checkin_longitude']?.toString(),
      checkinAccuracyM: _asNum(json['checkin_accuracy_m']),
      scheduleType: json['schedule_type']?.toString(),
      attendanceCyclesCount: cycles is List
          ? cycles.length
          : _asInt(json['total_sessions']),
    );
  }

  /// Share of scheduled 8h day (for progress bars).
  double get workedFraction => (totalTimeHours / 8).clamp(0.0, 1.5);
}

class LatePunchEntry {
  const LatePunchEntry({
    required this.id,
    required this.checkInTime,
    required this.checkOutTime,
    required this.checkinDate,
    required this.scheduleStartTime,
    required this.latePunchMinutes,
  });

  final String id;
  final String checkInTime;
  final String checkOutTime;
  final String checkinDate;
  final String scheduleStartTime;
  final int latePunchMinutes;

  factory LatePunchEntry.fromJson(Map<String, dynamic> json) {
    return LatePunchEntry(
      id: '${json['id'] ?? ''}',
      checkInTime: '${json['clock_in_time'] ?? json['check_in_time'] ?? ''}',
      checkOutTime: '${json['clock_out_time'] ?? json['check_out_time'] ?? ''}',
      checkinDate: '${json['checkin_date'] ?? ''}',
      scheduleStartTime: '${json['schedule_start_time'] ?? ''}',
      latePunchMinutes: (json['late_punch_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

String formatYyyyMmDd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? _asHours(value).toInt();
  return 0;
}

num? _asNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null) return parsed;
  }
  return null;
}

/// Accepts decimal hours (`8.5`) or H:MM / H:MM:SS strings (`8:30`).
num _asHours(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  final raw = value.toString().trim();
  if (raw.isEmpty) return 0;
  final asNum = num.tryParse(raw);
  if (asNum != null) return asNum;
  final parts = raw.split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final s = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return h + (m / 60) + (s / 3600);
  }
  return 0;
}

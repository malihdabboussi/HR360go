import '../models/attendance_check_in_request.dart';
import '../models/check_in_geo.dart';
import 'attendance_pending_punch_confirm.dart';

const int maxPendingPunchRetryAttempts = 12;

enum PendingAttendancePunchStatus { pending, queued, confirmed, failed }

enum PendingAttendancePunchAction { checkIn, checkOut }

class PendingAttendancePunch {
  PendingAttendancePunch({
    required this.id,
    required this.checkinTime,
    required this.timeZone,
    required this.status,
    required this.expectedAction,
    required this.attempts,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationCapturedAt,
    this.lastAttemptAt,
    this.lastError,
    this.baselineStatus,
    this.optimisticUiApplied = false,
  });

  final String id;
  final String checkinTime;
  final String timeZone;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? locationCapturedAt;
  final PendingAttendancePunchStatus status;
  final PendingAttendancePunchAction expectedAction;
  final int attempts;
  final String createdAt;
  final String? lastAttemptAt;
  final String? lastError;
  final AttendanceStatusSnapshot? baselineStatus;
  final bool optimisticUiApplied;

  PendingAttendancePunch copyWith({
    PendingAttendancePunchStatus? status,
    int? attempts,
    String? lastAttemptAt,
    String? lastError,
    bool? optimisticUiApplied,
  }) {
    return PendingAttendancePunch(
      id: id,
      checkinTime: checkinTime,
      timeZone: timeZone,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      locationCapturedAt: locationCapturedAt,
      status: status ?? this.status,
      expectedAction: expectedAction,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError,
      baselineStatus: baselineStatus,
      optimisticUiApplied: optimisticUiApplied ?? this.optimisticUiApplied,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'checkinTime': checkinTime,
        'timeZone': timeZone,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'locationCapturedAt': locationCapturedAt,
        'status': status.name,
        'expectedAction':
            expectedAction == PendingAttendancePunchAction.checkOut ? 'check_out' : 'check_in',
        'attempts': attempts,
        'createdAt': createdAt,
        'lastAttemptAt': lastAttemptAt,
        'lastError': lastError,
        'baselineStatus': baselineStatus?.toJson(),
        'optimisticUiApplied': optimisticUiApplied,
      };

  static PendingAttendancePunch? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final p = Map<String, dynamic>.from(raw);
    if (p['checkinTime'] == null || p['timeZone'] == null) return null;

    final expectedAction = p['expectedAction'] == 'check_out'
        ? PendingAttendancePunchAction.checkOut
        : PendingAttendancePunchAction.checkIn;

    PendingAttendancePunchStatus status;
    switch (p['status']?.toString()) {
      case 'queued':
        status = PendingAttendancePunchStatus.queued;
      case 'failed':
        status = PendingAttendancePunchStatus.failed;
      case 'confirmed':
        return null;
      default:
        status = PendingAttendancePunchStatus.pending;
    }

    AttendanceStatusSnapshot? baseline;
    if (p['baselineStatus'] is Map) {
      baseline = AttendanceStatusSnapshot.fromJson(
        Map<String, dynamic>.from(p['baselineStatus'] as Map),
      );
    }

    final createdAt = p['createdAt']?.toString() ?? p['checkinTime'].toString();
    final id = p['id']?.toString() ??
        buildPendingPunchId(
          expectedAction: expectedAction,
          checkinTime: p['checkinTime'].toString(),
        );

    return PendingAttendancePunch(
      id: id,
      checkinTime: p['checkinTime'].toString(),
      timeZone: p['timeZone'].toString(),
      latitude: (p['latitude'] as num?)?.toDouble(),
      longitude: (p['longitude'] as num?)?.toDouble(),
      accuracy: (p['accuracy'] as num?)?.toDouble(),
      locationCapturedAt: p['locationCapturedAt']?.toString(),
      status: status,
      expectedAction: expectedAction,
      attempts: p['attempts'] is int ? p['attempts'] as int : 0,
      createdAt: createdAt,
      lastAttemptAt: p['lastAttemptAt']?.toString(),
      lastError: p['lastError']?.toString(),
      baselineStatus: baseline,
      optimisticUiApplied: p['optimisticUiApplied'] == true,
    );
  }
}

class BuildPendingPunchMeta {
  const BuildPendingPunchMeta({
    required this.expectedAction,
    this.tenantId,
    this.employeeId,
    this.baselineStatus,
  });

  final PendingAttendancePunchAction expectedAction;
  final String? tenantId;
  final String? employeeId;
  final AttendanceStatusSnapshot? baselineStatus;
}

String buildPendingPunchId({
  String? tenantId,
  String? employeeId,
  required PendingAttendancePunchAction expectedAction,
  required String checkinTime,
}) {
  final tenant = tenantId ?? 'unknown';
  final employee = employeeId ?? 'unknown';
  final toggle = expectedAction == PendingAttendancePunchAction.checkIn ? 'in' : 'out';
  return '$tenant:$employee:$toggle:$checkinTime';
}

CheckInGeo? pendingPunchToGeo(PendingAttendancePunch punch) {
  if (punch.latitude == null ||
      punch.longitude == null ||
      punch.accuracy == null ||
      punch.locationCapturedAt == null) {
    return null;
  }
  return CheckInGeo(
    latitude: punch.latitude!,
    longitude: punch.longitude!,
    accuracyMeters: punch.accuracy!,
    capturedAtIso: punch.locationCapturedAt!,
  );
}

PendingAttendancePunch buildPendingPunchFromInput(
  AttendanceCheckInRequest input,
  BuildPendingPunchMeta meta,
) {
  final now = DateTime.now().toUtc().toIso8601String();
  final punch = PendingAttendancePunch(
    id: buildPendingPunchId(
      tenantId: meta.tenantId,
      employeeId: meta.employeeId,
      expectedAction: meta.expectedAction,
      checkinTime: input.checkinTime,
    ),
    checkinTime: input.checkinTime,
    timeZone: input.timeZone,
    status: PendingAttendancePunchStatus.pending,
    expectedAction: meta.expectedAction,
    attempts: 0,
    createdAt: now,
    lastAttemptAt: null,
    lastError: null,
    baselineStatus: meta.baselineStatus,
  );
  if (input.geo != null) {
    return PendingAttendancePunch(
      id: punch.id,
      checkinTime: punch.checkinTime,
      timeZone: punch.timeZone,
      latitude: input.geo!.latitude,
      longitude: input.geo!.longitude,
      accuracy: input.geo!.accuracyMeters,
      locationCapturedAt: input.geo!.capturedAtIso,
      status: punch.status,
      expectedAction: punch.expectedAction,
      attempts: punch.attempts,
      createdAt: punch.createdAt,
      baselineStatus: punch.baselineStatus,
    );
  }
  return punch;
}

AttendanceCheckInRequest punchToAttendanceRequest(PendingAttendancePunch punch) {
  return AttendanceCheckInRequest(
    checkinTime: punch.checkinTime,
    timeZone: punch.timeZone,
    geo: pendingPunchToGeo(punch),
  );
}

bool hasUnresolvedPendingAttendancePunch(PendingAttendancePunch? punch) {
  if (punch == null) return false;
  return punch.status == PendingAttendancePunchStatus.pending ||
      punch.status == PendingAttendancePunchStatus.queued ||
      punch.status == PendingAttendancePunchStatus.failed;
}

bool hasOptimisticPendingAttendanceUi(PendingAttendancePunch? punch) {
  return punch?.status == PendingAttendancePunchStatus.queued &&
      punch!.optimisticUiApplied;
}

bool shouldRetryPendingPunch(
  PendingAttendancePunch punch,
  AttendanceStatusSnapshot? currentStatus,
) {
  if (punch.status != PendingAttendancePunchStatus.pending &&
      punch.status != PendingAttendancePunchStatus.failed) {
    return false;
  }
  if (punch.attempts >= maxPendingPunchRetryAttempts) return false;
  if (currentStatus != null &&
      isAttendanceStatusConfirmed(punch, currentStatus)) {
    return false;
  }
  return true;
}

bool isRecoverablePendingPunchStatus(PendingAttendancePunchStatus status) {
  return status == PendingAttendancePunchStatus.queued ||
      status == PendingAttendancePunchStatus.failed ||
      status == PendingAttendancePunchStatus.pending;
}

bool shouldPollQueuedPunch(PendingAttendancePunch punch) {
  return punch.status == PendingAttendancePunchStatus.queued &&
      !punch.optimisticUiApplied;
}

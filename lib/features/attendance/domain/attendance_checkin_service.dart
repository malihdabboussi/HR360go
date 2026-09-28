import 'package:dio/dio.dart';

import '../data/attendance_repository.dart';
import '../models/attendance_check_in_request.dart';
import 'attendance_auth_token.dart';
import 'attendance_checkin_config.dart';
import 'attendance_checkin_errors.dart';
import 'attendance_checkin_response.dart';

enum AttendanceCheckInOutcomeKind {
  primaryLegacySuccess,
  primaryQueued,
  planBQueued,
  failed,
}

enum PlanBSkippedReason { noCompactJwt, planBDisabled, noPlanBUrl }

class AttendanceCheckInOutcome {
  const AttendanceCheckInOutcome._({
    required this.kind,
    this.legacyData,
    this.retryable = false,
    this.planBSkippedReason,
    this.userMessage,
  });

  final AttendanceCheckInOutcomeKind kind;
  final Map<String, dynamic>? legacyData;
  final bool retryable;
  final PlanBSkippedReason? planBSkippedReason;

  /// Server explanation for a rejected punch (e.g. outside geofence).
  final String? userMessage;

  factory AttendanceCheckInOutcome.primaryLegacySuccess(
    Map<String, dynamic> data,
  ) =>
      AttendanceCheckInOutcome._(
        kind: AttendanceCheckInOutcomeKind.primaryLegacySuccess,
        legacyData: data,
      );

  factory AttendanceCheckInOutcome.primaryQueued() => const AttendanceCheckInOutcome._(
        kind: AttendanceCheckInOutcomeKind.primaryQueued,
      );

  factory AttendanceCheckInOutcome.planBQueued() => const AttendanceCheckInOutcome._(
        kind: AttendanceCheckInOutcomeKind.planBQueued,
      );

  factory AttendanceCheckInOutcome.failed({
    required bool retryable,
    PlanBSkippedReason? planBSkippedReason,
    String? userMessage,
  }) =>
      AttendanceCheckInOutcome._(
        kind: AttendanceCheckInOutcomeKind.failed,
        retryable: retryable,
        planBSkippedReason: planBSkippedReason,
        userMessage: userMessage,
      );
}

class AttendanceCheckInService {
  AttendanceCheckInService(this._repository);

  final AttendanceRepository _repository;

  PlanBSkippedReason? _planBSkipReason(String? accessToken) {
    if (!isAttendancePlanBEnabled()) return PlanBSkippedReason.planBDisabled;
    if (getAttendancePlanBEndpointUrl() == null) return PlanBSkippedReason.noPlanBUrl;
    if (resolveCompactJwtForPlanB(accessToken) == null) {
      return PlanBSkippedReason.noCompactJwt;
    }
    return null;
  }

  Future<AttendanceCheckInOutcome> submitAttendanceCheckIn(
    AttendanceCheckInRequest input,
    String? accessToken,
  ) async {
    try {
      final primary = await _repository.callPrimaryCheckIn(input);
      if (primary is PrimaryCheckInQueued) {
        return AttendanceCheckInOutcome.primaryQueued();
      }
      if (primary is PrimaryCheckInLegacy) {
        return AttendanceCheckInOutcome.primaryLegacySuccess(primary.data.raw);
      }
      throw FormatException('Unexpected primary result');
    } catch (primaryError) {
      if (!isPlanBEligibleError(primaryError)) {
        return AttendanceCheckInOutcome.failed(
          retryable: false,
          userMessage: attendanceControlRejection(primaryError),
        );
      }

      final skip = _planBSkipReason(accessToken);
      if (skip != null) {
        return AttendanceCheckInOutcome.failed(
          retryable: true,
          planBSkippedReason: skip,
        );
      }

      final compactJwt = resolveCompactJwtForPlanB(accessToken)!;
      try {
        await _repository.callPlanBEmergencyCheckIn(input, compactJwt);
        return AttendanceCheckInOutcome.planBQueued();
      } catch (_) {
        return AttendanceCheckInOutcome.failed(retryable: true);
      }
    }
  }
}

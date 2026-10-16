import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/leave_models.dart';

/// Employee leave self-service (same Server endpoints as the web "My leaves" page).
class LeaveRepository {
  LeaveRepository(this._api);

  final ApiClient _api;

  Future<List<LeaveBalance>> getBalances() async {
    final res = await _api.get(ApiEndpoints.myLeaveBalance);
    return LeaveBalance.listFrom(res.data);
  }

  /// Types assigned to the employee (probation-locked types are left out by the Server).
  Future<List<LeaveTypeOption>> getRequestableTypes() async {
    final res = await _api.get(ApiEndpoints.assignedLeaves);
    return LeaveTypeOption.listFrom(res.data);
  }

  Future<List<LeaveRequestItem>> getMyRequests() async {
    final res = await _api.get(ApiEndpoints.myLeaveRequests);
    return LeaveRequestItem.listFrom(res.data);
  }

  /// Working days the draft would use (excludes off days / holidays), or null
  /// when it cannot be computed yet.
  Future<double?> computeDays(String employeeId, LeaveRequestDraft draft) async {
    if (draft.typeId == null || draft.start == null) return null;
    if (draft.durationType == LeaveDurationType.hourly &&
        (draft.startTime == null || draft.endTime == null)) {
      return null;
    }
    final payload = draft.toPayload();
    final res = await _api.get(
      ApiEndpoints.computeLeaveDuration,
      queryParameters: {
        'employee_id': employeeId,
        'leave_type': draft.typeId,
        'start': payload['start'],
        'end': payload['end'],
        'duration_type': payload['duration_type'],
        if (payload['half_day_period'] != null) 'half_day_period': payload['half_day_period'],
        if (payload['start_time'] != null) 'start_time': payload['start_time'],
        if (payload['end_time'] != null) 'end_time': payload['end_time'],
      },
    );
    final data = res.data;
    if (data is Map && data['ok'] == true) {
      final d = data['durationInDays'];
      if (d is num) return d.toDouble();
    }
    return null;
  }

  Future<LeaveSubmitResult> submit(LeaveRequestDraft draft) async {
    final res = await _api.post(ApiEndpoints.leaveRequest, data: draft.toPayload());
    return LeaveSubmitResult.fromResponse(res.data);
  }

  /// Cancel one of the employee's own pending requests (the Server deletes it).
  Future<void> cancel(String id) =>
      _api.delete('${ApiEndpoints.deleteLeaveRequest}?id=${Uri.encodeQueryComponent(id)}');
}

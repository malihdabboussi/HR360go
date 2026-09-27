/// Mirrors web Client API paths; mobile attendance uses dedicated routes.
class ApiEndpoints {
  static const login = '/api/v2/self_service/login';
  static const resetPassword = '/api/v2/self_service/resetPassword';

  static const permissionsMe = '/api/v2/permissions/me';
  static const permissionsMeDetailed = '/api/v2/permissions/me/detailed';

  /// Mobile-only attendance (gated by mobile-check-in / mobile-access).
  static const checkIn = '/api/v2/mobile/attendance/Checkin';
  static const checkInStatus = '/api/v2/mobile/attendance/GetCheckinStatus';
  static const myAttendance = '/api/v2/mobile/attendance/getMyAttendance';
  static const currentMonthPayroll = '/api/v2/payroll/myPeriodAttendanceSummary';

  static const myLeaveRequests = '/api/v2/leave_request/getEmployeeLeavesRequest';
  static const myLeaveBalance = '/api/v2/leave_request/MyLeaveBalance';
  static const leaveRequest = '/api/v2/leave_request/LeaveRequest';

  static const myTasks = '/api/v2/Task/getAllTasks';
  static String taskById(String id) => '/api/v2/Task/getTask?id=$id';

  static const myTrainings = '/api/v2/trainingAssignments/getMyAssignedTrainings';
  static const myTrainingStatus =
      '/api/v2/trainingAssignments/getMyAssignedTrainingsStatus';

  static String profileById(String id) => '/api/v2/Profiles/getProfile?id=$id';
  static const myPerformance = '/api/v2/performance/getMyPerformance';
  static const myAssignedAssets = '/api/v2/assets/getMyAssignedAssets';
  static const myExpenses = '/api/v2/Payments/getMyPaymentRequest';
  static const myPayroll = '/api/v2/payroll/getMyPayroll';
}

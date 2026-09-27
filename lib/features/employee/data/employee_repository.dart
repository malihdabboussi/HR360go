import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';

class EmployeeRepository {
  EmployeeRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>?> getProfile(String employeeId) async {
    final response = await _api.get(ApiEndpoints.profileById(employeeId));
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<dynamic>> getMyLeaveRequests() async {
    final response = await _api.get(ApiEndpoints.myLeaveRequests);
    if (response.data is List) return response.data as List<dynamic>;
    return [];
  }

  Future<dynamic> getMyLeaveBalance() async {
    final response = await _api.get(ApiEndpoints.myLeaveBalance);
    return response.data;
  }

  Future<List<dynamic>> getMyTasks({bool limit = false}) async {
    final path = limit
        ? '${ApiEndpoints.myTasks}?limit=5'
        : ApiEndpoints.myTasks;
    final response = await _api.get(path);
    if (response.data is List) return response.data as List<dynamic>;
    return [];
  }

  Future<List<dynamic>> getMyTrainings() async {
    final response = await _api.get(ApiEndpoints.myTrainings);
    if (response.data is List) return response.data as List<dynamic>;
    return [];
  }

  Future<dynamic> getMyPayroll() async {
    final response = await _api.get(ApiEndpoints.myPayroll);
    return response.data;
  }

  Future<dynamic> getMyPerformance() async {
    final response = await _api.get(ApiEndpoints.myPerformance);
    return response.data;
  }

  Future<List<dynamic>> getMyExpenses() async {
    final response = await _api.get(ApiEndpoints.myExpenses);
    if (response.data is List) return response.data as List<dynamic>;
    return [];
  }
}

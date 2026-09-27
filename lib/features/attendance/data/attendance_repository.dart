import 'package:dio/dio.dart';

import '../../../config/env.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/attendance_checkin_config.dart';
import '../domain/attendance_checkin_response.dart';
import '../models/attendance_check_in_request.dart';
import '../models/check_in_geo.dart';
import '../models/check_in_status.dart';
import '../models/my_attendance_report.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);

  final ApiClient _api;

  Future<CheckInStatus> getStatus(String timeZone) async {
    final response = await _api.get(
      ApiEndpoints.checkInStatus,
      queryParameters: {'timeZone': timeZone},
    );
    return CheckInStatus.fromJson(response.data);
  }

  Future<PrimaryCheckInParseResult> callPrimaryCheckIn(
    AttendanceCheckInRequest input,
  ) async {
    final params = <String, dynamic>{
      'timeZone': input.timeZone,
      'checkinTime': input.checkinTime,
    };
    if (input.geo != null) {
      params.addAll(input.geo!.toQueryParams());
    }

    final response = await _api.get(
      ApiEndpoints.checkIn,
      queryParameters: params,
      options: Options(
        receiveTimeout: const Duration(milliseconds: attendancePrimaryCheckinTimeoutMs),
        sendTimeout: const Duration(milliseconds: attendancePrimaryCheckinTimeoutMs),
      ),
    );

    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    return parsePrimaryCheckInResponse(response.data);
  }

  Future<void> callPlanBEmergencyCheckIn(
    AttendanceCheckInRequest input,
    String compactJwt,
  ) async {
    final url = getAttendancePlanBEndpointUrl();
    if (url == null) {
      throw StateError('Plan B attendance URL is not configured');
    }

    final body = <String, dynamic>{
      'checkinTime': input.checkinTime,
      'timeZone': input.timeZone,
      'source': attendancePlanBSource,
    };
    if (input.geo != null) {
      body['latitude'] = input.geo!.latitude;
      body['longitude'] = input.geo!.longitude;
      body['accuracy'] = input.geo!.accuracyMeters;
      body['locationCapturedAt'] = input.geo!.capturedAtIso;
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(milliseconds: attendancePrimaryCheckinTimeoutMs),
        receiveTimeout: const Duration(milliseconds: attendancePrimaryCheckinTimeoutMs),
        headers: {
          'Authorization': 'Bearer $compactJwt',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status == 200,
      ),
    );

    final response = await dio.post<dynamic>(url, data: body);
    if (response.statusCode != 200) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Plan B attendance returned ${response.statusCode}',
      );
    }

    final data = response.data;
    if (data is Map && data['success'] == false) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: data['message']?.toString() ?? 'Plan B attendance failed',
        type: DioExceptionType.badResponse,
      );
    }
  }

  Future<List<MyAttendanceReport>> fetchMyAttendanceReports({
    required String startDate,
    required String endDate,
  }) async {
    final response = await _api.get(
      ApiEndpoints.myAttendance,
      queryParameters: {
        'start_date': startDate,
        'end_date': endDate,
      },
    );
    if (response.data is! List) return [];
    return (response.data as List)
        .whereType<Map>()
        .map((e) => MyAttendanceReport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<MyAttendanceReport?> fetchMyAttendanceForPeriod({
    required String startDate,
    required String endDate,
  }) async {
    final reports = await fetchMyAttendanceReports(
      startDate: startDate,
      endDate: endDate,
    );
    if (reports.isEmpty) return null;
    return reports.first;
  }
}

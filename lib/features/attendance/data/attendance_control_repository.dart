import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../domain/attendance_control.dart';

class AttendanceControlRepository {
  AttendanceControlRepository(this._api);

  static const boxName = 'attendance_control';

  final ApiClient _api;
  Box<dynamic>? _box;

  Future<Box<dynamic>?> _openBox() async {
    try {
      return _box ??= await Hive.openBox(boxName);
    } catch (e) {
      debugPrint('[attendance-control] cache unavailable: $e');
      return null;
    }
  }

  String _cacheKey(String tenantId, String employeeId) => '$tenantId:$employeeId';

  Future<AttendanceControlConfig?> readCached(String tenantId, String employeeId) async {
    final raw = (await _openBox())?.get(_cacheKey(tenantId, employeeId));
    if (raw is! Map) return null;
    return AttendanceControlConfig.fromJson(raw);
  }

  /// Rules for the signed-in employee. Falls back to the last cached rules when
  /// offline so enforcement survives a dead connection. A 404 means the Server
  /// does not have the feature yet, so no rules apply.
  Future<AttendanceControlConfig> fetchMine({
    required String tenantId,
    required String employeeId,
  }) async {
    try {
      final response = await _api.get(ApiEndpoints.myAttendanceControl);
      final config = AttendanceControlConfig.fromJson(response.data);
      await (await _openBox())?.put(_cacheKey(tenantId, employeeId), config.toJson());
      return config;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404) {
        await (await _openBox())?.delete(_cacheKey(tenantId, employeeId));
        return AttendanceControlConfig.none;
      }
      final cached = await readCached(tenantId, employeeId);
      if (cached != null) return cached;
      rethrow;
    }
  }
}

import 'package:dio/dio.dart';

const _planBEligibleStatuses = {500, 502, 503, 504};

bool isPlanBEligibleError(Object error) {
  if (error is! DioException) return false;

  final code = error.type;
  if (code == DioExceptionType.connectionTimeout ||
      code == DioExceptionType.sendTimeout ||
      code == DioExceptionType.receiveTimeout ||
      code == DioExceptionType.connectionError) {
    return true;
  }

  final response = error.response;
  if (response == null) return true;

  return _planBEligibleStatuses.contains(response.statusCode);
}

const _attendanceControlMessages = {
  'NFC_REQUIRED': 'Tap your NFC card to check in or out.',
  'NFC_NOT_ASSIGNED': 'This NFC card is not assigned to you.',
  'OUTSIDE_GEOFENCE': 'You are outside your allowed check-in location.',
  'LOCATION_REQUIRED': 'Your location is required to check in or out.',
};

/// User-facing message when the Server rejects a punch for an attendance-control
/// rule (`{ code, message }` body, usually HTTP 403/422). Null for other errors.
String? attendanceControlRejection(Object error) {
  if (error is! DioException) return null;
  final data = error.response?.data;
  if (data is! Map) return null;
  final code = '${data['code'] ?? data['error_code'] ?? ''}'.toUpperCase();
  final fallback = _attendanceControlMessages[code];
  if (fallback == null) return null;
  final serverMessage = data['message']?.toString().trim();
  return serverMessage != null && serverMessage.isNotEmpty ? serverMessage : fallback;
}

bool isPlanBIneligibleClientError(Object error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  if (status == null) return false;
  return status >= 400 && status < 500;
}

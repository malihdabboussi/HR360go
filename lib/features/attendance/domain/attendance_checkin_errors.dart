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

bool isPlanBIneligibleClientError(Object error) {
  if (error is! DioException) return false;
  final status = error.response?.statusCode;
  if (status == null) return false;
  return status >= 400 && status < 500;
}

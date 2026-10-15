import 'package:dio/dio.dart';

/// Maps Dio / HTTP failures to short user-facing copy.
String formatAttendanceUserError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  // Refusals from the company's plan (System Admin) come with a code in the body.
  if (error is DioException) {
    final data = error.response?.data;
    final code = data is Map ? '${data['error'] ?? ''}' : '';
    if (code == 'SUBSCRIPTION_FEATURE_NOT_AVAILABLE') {
      return "This feature isn't part of your company's HR360 plan.";
    }
    if (code == 'tenant_subscription_suspended') {
      return "Your organization's HR360 subscription is suspended. Contact your administrator.";
    }
  }

  if (lower.contains('403') ||
      lower.contains('permission_denied') ||
      lower.contains('not permitted')) {
    return 'Check-in is not permitted for your role.';
  }
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return 'Your session expired. Please sign in again.';
  }
  if (lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('bad response')) {
    return 'Could not update attendance. Please try again.';
  }
  if (lower.contains('timeout') ||
      lower.contains('connection') ||
      lower.contains('socket')) {
    return 'Network error. Check your connection and try again.';
  }
  if (raw.length > 120 || lower.contains('dioexception')) {
    return 'Could not update attendance. Please try again.';
  }
  return raw;
}

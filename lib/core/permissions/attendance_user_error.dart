/// Maps Dio / HTTP failures to short user-facing copy.
String formatAttendanceUserError(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

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

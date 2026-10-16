import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/auth/auth_repository.dart';
import '../core/auth/employee_session.dart';
import '../core/auth/saved_credentials_store.dart';
import '../core/auth/session_store.dart';
import '../core/subscription/plan_modules.dart';
import '../core/updates/app_update_service.dart';
import '../features/attendance/data/attendance_control_repository.dart';
import '../features/attendance/data/attendance_repository.dart';
import '../features/attendance/data/local_attendance_session_store.dart';
import '../features/attendance/data/location_service.dart';
import '../features/attendance/data/nfc_reader.dart';
import '../features/attendance/data/pending_punch_store.dart';
import '../features/attendance/data/shift_watch_service.dart';
import '../features/attendance/domain/attendance_checkin_service.dart';
import '../features/employee/data/employee_repository.dart';
import '../features/leaves/data/leave_repository.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

final savedCredentialsStoreProvider =
    Provider<SavedCredentialsStore>((ref) => SavedCredentialsStore());

final appUpdateServiceProvider =
    Provider<AppUpdateService>((ref) => AppUpdateService());

final shiftWatchServiceProvider = Provider<ShiftWatchService>((ref) {
  return ShiftWatchService(sessionStore: ref.watch(sessionStoreProvider));
});

/// Auto check-out / reminder state for the attendance screen.
final shiftWatchStatusProvider =
    StateProvider<ShiftWatchStatus>((ref) => ShiftWatchStatus.idle);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(sessionStoreProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  );
});

final sessionProvider = FutureProvider<EmployeeSession?>((ref) async {
  return ref.watch(authRepositoryProvider).currentSession();
});

final pendingPunchStoreProvider = Provider<PendingPunchStore>((ref) {
  throw UnimplementedError('Initialize in main()');
});

final localAttendanceSessionStoreProvider =
    Provider<LocalAttendanceSessionStore>((ref) {
  throw UnimplementedError('Initialize in main()');
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(apiClientProvider));
});

final attendanceCheckInServiceProvider = Provider<AttendanceCheckInService>((ref) {
  return AttendanceCheckInService(ref.watch(attendanceRepositoryProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final attendanceControlRepositoryProvider =
    Provider<AttendanceControlRepository>((ref) {
  return AttendanceControlRepository(ref.watch(apiClientProvider));
});

final nfcReaderProvider = Provider<NfcReader>((ref) => const PlatformNfcReader());

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository(ref.watch(apiClientProvider));
});

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(apiClientProvider));
});

/// The company's plan modules, read once per session. Unreadable → nothing hidden
/// (the server still enforces the plan).
final planModulesProvider = FutureProvider<PlanModules>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  if (session == null) return const PlanModules.unrestricted();
  try {
    final response = await ref.watch(apiClientProvider).get(ApiEndpoints.mobileEntitlements);
    return PlanModules.fromJson(response.data);
  } catch (_) {
    return const PlanModules.unrestricted();
  }
});

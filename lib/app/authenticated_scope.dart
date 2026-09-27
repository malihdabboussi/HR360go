import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/employee_session.dart';
import '../features/attendance/presentation/attendance_controller.dart';
import 'providers.dart';

/// Provides session-scoped controllers after login.
final currentSessionProvider = Provider<EmployeeSession>((ref) {
  throw UnimplementedError('Override in AuthenticatedScope');
});

class AuthenticatedScope extends ConsumerStatefulWidget {
  const AuthenticatedScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AuthenticatedScope> createState() => _AuthenticatedScopeState();
}

class _AuthenticatedScopeState extends ConsumerState<AuthenticatedScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(scopedAttendanceControllerProvider.notifier).recoverOnStartup();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);
    return sessionAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (session) {
        if (session == null) {
          return const Scaffold(
            body: Center(child: Text('Session expired')),
          );
        }
        return ProviderScope(
          overrides: [
            currentSessionProvider.overrideWithValue(session),
          ],
          child: widget.child,
        );
      },
    );
  }
}

final scopedAttendanceControllerProvider =
    StateNotifierProvider<AttendanceController, AttendanceState>(
  (ref) {
    return AttendanceController(
      session: ref.watch(currentSessionProvider),
      repository: ref.watch(attendanceRepositoryProvider),
      pendingPunchStore: ref.watch(pendingPunchStoreProvider),
      localSessionStore: ref.watch(localAttendanceSessionStoreProvider),
      locationService: ref.watch(locationServiceProvider),
      checkInService: ref.watch(attendanceCheckInServiceProvider),
    );
  },
  dependencies: [currentSessionProvider],
);

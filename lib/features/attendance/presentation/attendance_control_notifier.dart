import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/employee_session.dart';
import '../data/attendance_control_repository.dart';
import '../domain/attendance_control.dart';

/// NFC / geofence rules for the signed-in employee. Loaded right after login
/// and refreshed on pull-to-refresh and before each punch.
class AttendanceControlNotifier
    extends StateNotifier<AsyncValue<AttendanceControlConfig>> {
  AttendanceControlNotifier({
    required EmployeeSession session,
    required AttendanceControlRepository repository,
  })  : _session = session,
        _repository = repository,
        super(const AsyncValue.loading()) {
    _primeFromCache();
    refresh();
  }

  final EmployeeSession _session;
  final AttendanceControlRepository _repository;
  Future<AttendanceControlConfig>? _inFlight;

  Future<void> _primeFromCache() async {
    final cached = await _repository.readCached(_session.tenantId, _session.employeeId);
    if (cached != null && mounted && state.isLoading) {
      state = AsyncValue.data(cached);
    }
  }

  /// Fetches fresh rules; concurrent callers share one request.
  Future<AttendanceControlConfig> refresh() {
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  /// Rules to enforce for a punch: fresh when the Server answers quickly,
  /// otherwise the last known (or cached) rules.
  Future<AttendanceControlConfig> forPunch() async {
    try {
      return await refresh().timeout(punchRulesTimeout);
    } catch (_) {
      final known = state.valueOrNull ??
          await _repository.readCached(_session.tenantId, _session.employeeId);
      if (known != null) return known;
      rethrow;
    }
  }

  static const punchRulesTimeout = Duration(seconds: 5);

  Future<AttendanceControlConfig> _fetch() async {
    try {
      final config = await _repository.fetchMine(
        tenantId: _session.tenantId,
        employeeId: _session.employeeId,
        timeZone: _session.timeZone,
      );
      if (mounted) state = AsyncValue.data(config);
      return config;
    } catch (e, st) {
      final previous = state.valueOrNull;
      if (previous != null) return previous;
      if (mounted) state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

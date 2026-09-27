import 'package:hive/hive.dart';

import '../domain/pending_attendance_punch.dart';

const pendingAttendancePunchStorageKey = 'hr360_pending_attendance_punch';

class PendingPunchStore {
  static const boxName = 'attendance_pending_punch';

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
  }

  PendingAttendancePunch? get() {
    final raw = _box?.get(pendingAttendancePunchStorageKey);
    if (raw is! Map) return null;
    return PendingAttendancePunch.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> save(PendingAttendancePunch punch) async {
    await _box?.put(pendingAttendancePunchStorageKey, punch.toJson());
  }

  Future<void> clear() async {
    await _box?.delete(pendingAttendancePunchStorageKey);
  }

  Future<void> markQueued({bool optimisticUiApplied = false}) async {
    final current = get();
    if (current == null) return;
    await save(
      current.copyWith(
        status: PendingAttendancePunchStatus.queued,
        lastError: null,
        optimisticUiApplied: optimisticUiApplied,
      ),
    );
  }

  Future<void> markFailed([String? error]) async {
    final current = get();
    if (current == null) return;
    await save(
      current.copyWith(
        status: PendingAttendancePunchStatus.failed,
        lastError: error ?? current.lastError,
      ),
    );
  }

  Future<void> markPending() async {
    final current = get();
    if (current == null) return;
    await save(current.copyWith(status: PendingAttendancePunchStatus.pending));
  }

  Future<void> recordAttempt([String? error]) async {
    final current = get();
    if (current == null) return;
    await save(
      current.copyWith(
        attempts: current.attempts + 1,
        lastAttemptAt: DateTime.now().toUtc().toIso8601String(),
        lastError: error,
      ),
    );
  }
}

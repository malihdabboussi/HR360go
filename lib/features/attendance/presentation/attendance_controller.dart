import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/employee_session.dart';
import '../data/attendance_repository.dart';
import '../data/local_attendance_session_store.dart';
import '../data/location_service.dart';
import '../data/pending_punch_store.dart';
import '../domain/attendance_checkin_config.dart';
import '../domain/attendance_checkin_poll.dart';
import '../domain/attendance_checkin_service.dart';
import '../domain/attendance_pending_punch_confirm.dart';
import '../domain/location_availability.dart';
import '../domain/pending_attendance_punch.dart';
import '../models/attendance_check_in_request.dart';
import '../../../core/permissions/attendance_user_error.dart';
import '../models/check_in_geo.dart';
import '../models/check_in_status.dart';
import '../models/my_attendance_report.dart';

class AttendanceState {
  const AttendanceState({
    this.status,
    this.isLoading = false,
    this.isAcquiringLocation = false,
    this.isSubmitting = false,
    this.isResolvingQueued = false,
    this.elapsed,
    this.hasPendingPunch = false,
    this.pendingPunchFailed = false,
    this.lastSyncAt,
    this.error,
    this.infoMessage,
    this.dailyHoursLabel,
    this.weeklyHoursLabel,
    this.weekReport,
    this.canToggleCheckIn = true,
    this.locationPrompt,
  });

  final CheckInStatus? status;
  final bool isLoading;
  final bool isAcquiringLocation;
  final bool isSubmitting;
  final bool isResolvingQueued;
  final Duration? elapsed;
  final bool hasPendingPunch;
  final bool pendingPunchFailed;
  final DateTime? lastSyncAt;
  final String? error;
  final String? infoMessage;
  final String? dailyHoursLabel;
  final String? weeklyHoursLabel;
  final MyAttendanceReport? weekReport;
  final bool canToggleCheckIn;
  /// Non-null when punch proceeded without GPS and UI should offer Settings.
  final LocationAvailability? locationPrompt;

  bool get isOpenSession => status?.isOpenSession ?? false;

  bool get isCheckInInteractionBlocked =>
      isSubmitting ||
      isAcquiringLocation ||
      hasPendingPunch ||
      isResolvingQueued;

  AttendanceState copyWith({
    CheckInStatus? status,
    bool? isLoading,
    bool? isAcquiringLocation,
    bool? isSubmitting,
    bool? isResolvingQueued,
    Duration? elapsed,
    bool? hasPendingPunch,
    bool? pendingPunchFailed,
    DateTime? lastSyncAt,
    String? error,
    String? infoMessage,
    String? dailyHoursLabel,
    String? weeklyHoursLabel,
    MyAttendanceReport? weekReport,
    bool? canToggleCheckIn,
    LocationAvailability? locationPrompt,
    bool clearError = false,
    bool clearInfo = false,
    bool clearLocationPrompt = false,
  }) =>
      AttendanceState(
        status: status ?? this.status,
        isLoading: isLoading ?? this.isLoading,
        isAcquiringLocation:
            isAcquiringLocation ?? this.isAcquiringLocation,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isResolvingQueued: isResolvingQueued ?? this.isResolvingQueued,
        elapsed: elapsed ?? this.elapsed,
        hasPendingPunch: hasPendingPunch ?? this.hasPendingPunch,
        pendingPunchFailed: pendingPunchFailed ?? this.pendingPunchFailed,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        error: clearError ? null : (error ?? this.error),
        infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
        dailyHoursLabel: dailyHoursLabel ?? this.dailyHoursLabel,
        weeklyHoursLabel: weeklyHoursLabel ?? this.weeklyHoursLabel,
        weekReport: weekReport ?? this.weekReport,
        canToggleCheckIn: canToggleCheckIn ?? this.canToggleCheckIn,
        locationPrompt: clearLocationPrompt
            ? null
            : (locationPrompt ?? this.locationPrompt),
      );
}

class AttendanceController extends StateNotifier<AttendanceState> {
  AttendanceController({
    required EmployeeSession session,
    required AttendanceRepository repository,
    required PendingPunchStore pendingPunchStore,
    required LocalAttendanceSessionStore localSessionStore,
    required LocationService locationService,
    required AttendanceCheckInService checkInService,
  })  : _session = session,
        _repository = repository,
        _pendingPunchStore = pendingPunchStore,
        _localSessionStore = localSessionStore,
        _locationService = locationService,
        _checkInService = checkInService,
        super(const AttendanceState()) {
    _startTimer();
    _syncPendingState();
    refresh();
  }

  final EmployeeSession _session;
  final AttendanceRepository _repository;
  final PendingPunchStore _pendingPunchStore;
  final LocalAttendanceSessionStore _localSessionStore;
  final LocationService _locationService;
  final AttendanceCheckInService _checkInService;

  Timer? _ticker;
  DateTime? _checkinStart;

  String get _timeZone =>
      _session.timeZone.isNotEmpty
          ? _session.timeZone
          : DateTime.now().timeZoneName;

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCooldown();
      if (_checkinStart == null) return;
      state = state.copyWith(
        elapsed: DateTime.now().difference(_checkinStart!),
      );
    });
  }

  void _syncPendingState() {
    final pending = _pendingPunchStore.get();
    state = state.copyWith(
      hasPendingPunch: hasUnresolvedPendingAttendancePunch(pending),
      pendingPunchFailed: pending?.status == PendingAttendancePunchStatus.failed,
    );
  }

  void _updateCooldown() {
    if (_checkinStart == null) {
      if (!state.canToggleCheckIn) {
        state = state.copyWith(canToggleCheckIn: true);
      }
      return;
    }
    final elapsedSec = DateTime.now().difference(_checkinStart!).inSeconds;
    final canToggle = elapsedSec >= checkInCooldownSeconds;
    if (canToggle != state.canToggleCheckIn) {
      state = state.copyWith(canToggleCheckIn: canToggle);
    }
  }

  AttendanceStatusSnapshot? _statusSnapshot(CheckInStatus? status) {
    if (status == null) return null;
    return AttendanceStatusSnapshot(
      checkinStatus: status.isCheckedIn,
      checkinTime: status.checkinTime,
      checkoutTime: status.checkoutTime,
    );
  }

  void _applyAttendanceUiState({
    required bool isCheckingOut,
    String? checkinTimeIso,
  }) {
    if (isCheckingOut) {
      _checkinStart = null;
      state = state.copyWith(elapsed: Duration.zero, canToggleCheckIn: true);
      return;
    }
    final start = checkinTimeIso != null
        ? DateTime.parse(checkinTimeIso).toLocal()
        : DateTime.now();
    _checkinStart = start;
    state = state.copyWith(
      elapsed: DateTime.now().difference(start),
      canToggleCheckIn: false,
    );
  }

  void _restoreLocalAttendanceSessionUi() {
    final local = _localSessionStore.get();
    if (local == null) return;
    _applyAttendanceUiState(
      isCheckingOut: !local.isCheckedIn,
      checkinTimeIso: local.isCheckedIn ? local.checkinTime : null,
    );
  }

  void _updateTimerFromStatus(CheckInStatus status) {
    if (status.isOpenSession && status.checkinTime != null) {
      _checkinStart = parseOpenCheckinLocalTime(status.checkinTime!);
      state = state.copyWith(
        elapsed: DateTime.now().difference(_checkinStart!),
      );
    } else if (_localSessionStore.get() == null) {
      _checkinStart = null;
      state = state.copyWith(elapsed: Duration.zero);
    }
    _updateCooldown();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final status = await _repository.getStatus(_timeZone);
      _updateTimerFromStatus(status);
      await _loadTodaySummary();
      _tryReconcilePendingFromStatus(status);
      _syncPendingState();

      state = state.copyWith(
        status: status,
        isLoading: false,
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      _restoreLocalAttendanceSessionUi();
      state = state.copyWith(
        isLoading: false,
        error: formatAttendanceUserError(e),
      );
      _syncPendingState();
    }
  }

  bool _tryReconcilePendingFromStatus(CheckInStatus status) {
    final pending = _pendingPunchStore.get();
    if (pending == null) return false;
    final snapshot = _statusSnapshot(status);
    if (snapshot == null) return false;

    if (isAttendanceStatusConfirmed(pending, snapshot)) {
      _pendingPunchStore.clear();
      _localSessionStore.clear();
      _syncPendingState();
      return true;
    }
    return false;
  }

  Future<void> _loadTodaySummary() async {
    final now = DateTime.now();
    final todayStr = formatYyyyMmDd(now);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    try {
      final weekReport = await _repository.fetchMyAttendanceForPeriod(
        startDate: formatYyyyMmDd(startOfWeek),
        endDate: todayStr,
      );

      String? dailyLabel;
      if (weekReport != null) {
        final todayDay = weekReport.dayForDate(todayStr);
        if (todayDay != null && todayDay.punched) {
          dailyLabel =
              '${todayDay.totalTimeHours.toStringAsFixed(2)} h today';
        } else if (weekReport.workedHours > 0) {
          dailyLabel = '${weekReport.workedHours} h (period)';
        }
      }

      state = state.copyWith(
        dailyHoursLabel: dailyLabel,
        weeklyHoursLabel: weekReport != null
            ? '${weekReport.workedHours} h worked · ${weekReport.overtime} h OT'
            : null,
        weekReport: weekReport,
      );
    } catch (_) {}
  }

  Future<void> _resolveQueuedAttendance(PendingAttendancePunch punch) async {
    state = state.copyWith(isResolvingQueued: true, clearError: true);
    try {
      final confirmed = await pollAttendanceCheckInStatusUntilConfirmed(
        _repository,
        punch,
        _timeZone,
      );
      if (confirmed) {
        await _pendingPunchStore.clear();
        await _localSessionStore.clear();
        await refresh();
        state = state.copyWith(
          isResolvingQueued: false,
          infoMessage: 'Attendance synced',
          clearInfo: false,
        );
      } else {
        // Poll window can end before the worker finishes — one more status check.
        final status = await _repository.getStatus(_timeZone);
        if (_tryReconcilePendingFromStatus(status)) {
          await refresh();
          state = state.copyWith(
            isResolvingQueued: false,
            infoMessage: 'Attendance synced',
            clearInfo: false,
          );
        } else {
          state = state.copyWith(
            isResolvingQueued: false,
            infoMessage: 'Attendance queued — still syncing',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        isResolvingQueued: false,
        error: formatAttendanceUserError(e),
      );
    }
    _syncPendingState();
  }

  Future<void> _handleOutcome(
    AttendanceCheckInOutcome outcome, {
    required bool isCheckingOut,
    required CheckInGeo? geo,
    required String checkinTimeIso,
  }) async {
    switch (outcome.kind) {
      case AttendanceCheckInOutcomeKind.primaryLegacySuccess:
        await _pendingPunchStore.clear();
        await _localSessionStore.clear();
        _syncPendingState();
        _applyAttendanceUiState(isCheckingOut: isCheckingOut);
        await refresh();
        state = state.copyWith(
          infoMessage: isCheckingOut ? 'Checked out' : 'Checked in',
        );
      case AttendanceCheckInOutcomeKind.primaryQueued:
        await _pendingPunchStore.markQueued();
        _syncPendingState();
        state = state.copyWith(
          infoMessage: 'Attendance queued — updating…',
        );
        final punch = _pendingPunchStore.get();
        if (punch != null) await _resolveQueuedAttendance(punch);
      case AttendanceCheckInOutcomeKind.planBQueued:
        final punch = _pendingPunchStore.get();
        await _localSessionStore.save(
          buildLocalSessionFromPunch(
            punch ?? buildPendingPunchFromInput(
              AttendanceCheckInRequest(
                timeZone: _timeZone,
                checkinTime: checkinTimeIso,
                geo: geo,
              ),
              BuildPendingPunchMeta(
                expectedAction: isCheckingOut
                    ? PendingAttendancePunchAction.checkOut
                    : PendingAttendancePunchAction.checkIn,
              ),
            ),
            employeeId: _session.employeeId,
            tenantId: _session.tenantId,
          ),
        );
        await _pendingPunchStore.clear();
        _syncPendingState();
        _applyAttendanceUiState(
          isCheckingOut: isCheckingOut,
          checkinTimeIso: checkinTimeIso,
        );
        state = state.copyWith(
          infoMessage: isCheckingOut ? 'Checked out' : 'Checked in',
        );
      case AttendanceCheckInOutcomeKind.failed:
        // Client may time out after the server already queued/processed the punch.
        try {
          final status = await _repository.getStatus(_timeZone);
          if (_tryReconcilePendingFromStatus(status)) {
            await refresh();
            state = state.copyWith(
              clearError: true,
              infoMessage: isCheckingOut ? 'Checked out' : 'Checked in',
            );
            return;
          }
        } catch (_) {}
        if (outcome.retryable) {
          await _pendingPunchStore.markFailed();
        } else {
          await _pendingPunchStore.clear();
        }
        _syncPendingState();
        state = state.copyWith(
          error: outcome.retryable
              ? 'Attendance failed — will retry when online'
              : 'Check-in/out failed',
        );
    }
  }

  Future<void> _submitAttendanceRequest({
    required AttendanceCheckInRequest request,
    required bool isCheckingOut,
    PendingAttendancePunch? existingPunch,
    bool silentFailure = false,
  }) async {
    if (existingPunch != null) {
      await _pendingPunchStore.markPending();
      await _pendingPunchStore.recordAttempt();
    } else {
      await _pendingPunchStore.save(
        buildPendingPunchFromInput(
          request,
          BuildPendingPunchMeta(
            expectedAction: isCheckingOut
                ? PendingAttendancePunchAction.checkOut
                : PendingAttendancePunchAction.checkIn,
            tenantId: _session.tenantId,
            employeeId: _session.employeeId,
            baselineStatus: _statusSnapshot(state.status),
          ),
        ),
      );
    }
    _syncPendingState();

    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final outcome = await _checkInService.submitAttendanceCheckIn(
        request,
        _session.accessToken,
      );
      await _handleOutcome(
        outcome,
        isCheckingOut: isCheckingOut,
        geo: request.geo,
        checkinTimeIso: request.checkinTime,
      );
    } catch (e) {
      try {
        final status = await _repository.getStatus(_timeZone);
        if (_tryReconcilePendingFromStatus(status)) {
          await refresh();
          if (!silentFailure) {
            state = state.copyWith(
              clearError: true,
              infoMessage: isCheckingOut ? 'Checked out' : 'Checked in',
            );
          }
          return;
        }
      } catch (_) {}
      await _pendingPunchStore.markFailed(formatAttendanceUserError(e));
      _syncPendingState();
      if (!silentFailure) {
        state = state.copyWith(error: formatAttendanceUserError(e));
      }
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  void clearLocationPrompt() {
    state = state.copyWith(clearLocationPrompt: true);
  }

  Future<void> dismissPendingPunch() async {
    await _pendingPunchStore.clear();
    await _localSessionStore.clear();
    _syncPendingState();
    state = state.copyWith(clearError: true, clearInfo: true);
    await refresh();
  }

  Future<void> openLocationSettingsFromPrompt() async {
    final prompt = state.locationPrompt;
    if (prompt == null) return;
    await _locationService.openSettingsFor(prompt);
    clearLocationPrompt();
  }

  Future<void> toggleCheck() async {
    if (state.isCheckInInteractionBlocked) return;
    if (!state.canToggleCheckIn && state.isOpenSession) return;

    state = state.copyWith(
      clearError: true,
      clearInfo: true,
      clearLocationPrompt: true,
      isAcquiringLocation: true,
    );

    // Align with server so expected action matches backend toggle direction.
    try {
      final status = await _repository.getStatus(_timeZone);
      _updateTimerFromStatus(status);
      state = state.copyWith(status: status);
    } catch (_) {}

    LocationAvailability? locationPrompt;
    CheckInGeo? geo;
    try {
      final availability = await _locationService.diagnose();
      if (!availability.ok) {
        locationPrompt = availability;
      } else {
        geo = await _locationService.captureOptional();
        if (geo == null) {
          locationPrompt = const LocationAvailability.blocked(
            LocationBlockReason.fixUnavailable,
          );
        }
      }
    } catch (_) {
      geo = null;
      locationPrompt ??= const LocationAvailability.blocked(
        LocationBlockReason.fixUnavailable,
      );
    } finally {
      state = state.copyWith(
        isAcquiringLocation: false,
        locationPrompt: locationPrompt,
      );
    }

    final isCheckingOut = state.isOpenSession;
    final checkinTime = DateTime.now().toUtc().toIso8601String();
    final request = AttendanceCheckInRequest(
      timeZone: _timeZone,
      checkinTime: checkinTime,
      geo: geo,
    );

    // Punch continues even without GPS (geo may be null).
    await _submitAttendanceRequest(
      request: request,
      isCheckingOut: isCheckingOut,
    );
  }

  Future<void> retryPendingPunch() async {
    final punch = _pendingPunchStore.get();
    if (punch == null || state.isSubmitting) return;
    await _submitAttendanceRequest(
      request: punchToAttendanceRequest(punch),
      isCheckingOut: punch.expectedAction == PendingAttendancePunchAction.checkOut,
      existingPunch: punch,
      silentFailure: false,
    );
  }

  Future<void> onConnectivityRestored() async {
    final pending = _pendingPunchStore.get();
    if (pending == null) return;

    final snapshot = _statusSnapshot(state.status);
    if (state.status != null && _tryReconcilePendingFromStatus(state.status!)) {
      return;
    }

    if (shouldPollQueuedPunch(pending)) {
      await _resolveQueuedAttendance(pending);
      return;
    }

    if (shouldRetryPendingPunch(pending, snapshot)) {
      await retryPendingPunch();
    }
  }

  Future<void> recoverOnStartup() async {
    _syncPendingState();
    final pending = _pendingPunchStore.get();
    if (pending == null) {
      _restoreLocalAttendanceSessionUi();
      return;
    }

    if (pending.status == PendingAttendancePunchStatus.queued &&
        pending.optimisticUiApplied) {
      await _pendingPunchStore.clear();
      await _localSessionStore.save(
        buildLocalSessionFromPunch(
          pending,
          employeeId: _session.employeeId,
          tenantId: _session.tenantId,
        ),
      );
      _restoreLocalAttendanceSessionUi();
      return;
    }

    if (shouldPollQueuedPunch(pending)) {
      await _resolveQueuedAttendance(pending);
      return;
    }

    final snapshot = _statusSnapshot(state.status);
    if (shouldRetryPendingPunch(pending, snapshot)) {
      await retryPendingPunch();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

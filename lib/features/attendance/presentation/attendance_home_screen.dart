import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../app/theme_mode_provider.dart';
import '../../../core/layout/shell_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/updates/app_update_dialog.dart';
import '../../../core/widgets/hr360_logo.dart';
import '../domain/attendance_control.dart';
import '../domain/location_availability.dart';
import '../models/my_attendance_report.dart';
import 'attendance_controller.dart';
import 'widgets/attendance_widgets.dart';
import 'widgets/nfc_scan_sheet.dart';
import 'widgets/shift_watch_widgets.dart';

class AttendanceHomeScreen extends ConsumerWidget {
  const AttendanceHomeScreen({super.key});

  Future<void> _showLocationPrompt(
    BuildContext context,
    AttendanceController controller,
    LocationAvailability prompt,
  ) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prompt.dialogTitle),
        content: Text(prompt.dialogMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.clearLocationPrompt();
            },
            child: const Text('Continue without GPS'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await controller.openLocationSettingsFromPrompt();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPunchHint(
    BuildContext context,
    AttendanceController controller,
    PunchHint hint,
  ) async {
    if (!context.mounted) return;
    final settings = hint.locationSettings;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline, size: 32),
        title: Text(hint.title),
        content: Text(hint.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          if (settings != null && !settings.ok)
            FilledButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await controller.openLocationSettings(settings);
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
    controller.clearPunchHint();
  }

  /// Rules check + GPS, then NFC tap when required, then submit.
  Future<void> _punch(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(scopedAttendanceControllerProvider.notifier);
    final preparation = await controller.preparePunch();
    if (preparation == null) return;

    String? serial;
    if (preparation.requiresNfc) {
      if (!context.mounted) {
        controller.cancelPunch();
        return;
      }
      serial = await showNfcScanSheet(
        context,
        reader: ref.read(nfcReaderProvider),
        isCheckingOut: preparation.isCheckingOut,
        cards: preparation.nfcCards,
      );
      if (serial == null) {
        controller.cancelPunch();
        return;
      }
    }
    await controller.submitPunch(preparation, nfcSerial: serial);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final state = ref.watch(scopedAttendanceControllerProvider);
    final controller = ref.read(scopedAttendanceControllerProvider.notifier);
    final canCheckIn = session.canRemoteCheckIn;
    final report = state.weekReport;
    final today = report?.dayForDate(formatYyyyMmDd(DateTime.now()));
    final themeMode = ref.watch(themeModeProvider);
    final control = ref.watch(attendanceControlProvider).valueOrNull;

    ref.listen<AttendanceState>(scopedAttendanceControllerProvider,
        (prev, next) {
      final prompt = next.locationPrompt;
      if (prompt == null || prompt.ok) return;
      if (prev?.locationPrompt?.blockReason == prompt.blockReason) return;
      _showLocationPrompt(context, controller, prompt);
    });

    ref.listen<AttendanceState>(scopedAttendanceControllerProvider,
        (prev, next) {
      final hint = next.punchHint;
      if (hint == null || identical(prev?.punchHint, hint)) return;
      _showPunchHint(context, controller, hint);
    });

    return ShiftWatchTapListener(
      onCheckOutNow: () => _punch(context, ref),
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            controller.refresh(),
            ref
                .read(attendanceControlProvider.notifier)
                .refresh()
                .then((_) {}, onError: (_) {}),
          ]);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  AppTheme.spaceSm,
                  AppTheme.spaceMd,
                  ShellLayout.homeScrollBottomPadding(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeHeader(
                      state: state,
                      firstName: session.firstName.isNotEmpty
                          ? session.firstName
                          : session.displayName.split(' ').first,
                      avatarUrl: session.avatar,
                      themeMode: themeMode,
                      onThemeChanged: (mode) {
                        ref.read(themeModeProvider.notifier).state = mode;
                      },
                      onCheckUpdates: () async {
                        final service = ref.read(appUpdateServiceProvider);
                        final result = await service.checkForUpdates();
                        if (!context.mounted) return;
                        await showAppUpdateDialog(
                          context,
                          result: result,
                          service: service,
                          userInitiated: true,
                        );
                      },
                      onLogout: () async {
                        await ref.read(authRepositoryProvider).logout();
                        ref.invalidate(sessionProvider);
                        if (context.mounted) context.go('/');
                      },
                    ),
                    const SizedBox(height: 12),
                    _HeroCard(
                      state: state,
                      today: today,
                      roleAllowsCheckIn: canCheckIn,
                      isLoading: state.isLoading ||
                          state.isAcquiringLocation ||
                          state.isSubmitting,
                      isAcquiringLocation: state.isAcquiringLocation,
                      control: control,
                      onToggle: state.isCheckInInteractionBlocked ||
                              (!state.canToggleCheckIn && state.isOpenSession)
                          ? null
                          : () => _punch(context, ref),
                    ),
                    if (state.infoMessage != null) ...[
                      const SizedBox(height: 12),
                      _MessageBanner(
                        message: state.infoMessage!,
                        color: AppColors.primary,
                      ),
                    ],
                    if (state.isResolvingQueued) ...[
                      const SizedBox(height: 12),
                      _MessageBanner(
                        message: 'Syncing attendance with server…',
                        color: AppColors.primary,
                      ),
                    ],
                    if (state.error != null ||
                        (state.hasPendingPunch &&
                            !state.isResolvingQueued)) ...[
                      const SizedBox(height: 12),
                      _SyncStatusBanner(
                        error: state.error,
                        pendingFailed: state.pendingPunchFailed,
                        hasPending: state.hasPendingPunch,
                        onRetry: state.pendingPunchFailed
                            ? controller.retryPendingPunch
                            : null,
                        onDismiss: state.hasPendingPunch
                            ? controller.dismissPendingPunch
                            : null,
                      ),
                    ],
                    if (state.isOpenSession) const ShiftWatchPermissionBanner(),
                    if (report != null) ...[
                      const SizedBox(height: 16),
                      WeekAtAGlance(report: report, today: today),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.state,
    required this.firstName,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onCheckUpdates,
    required this.onLogout,
    this.avatarUrl,
  });

  final AttendanceState state;
  final String firstName;
  final ThemeMode? themeMode;
  final ValueChanged<ThemeMode?> onThemeChanged;
  final Future<void> Function() onCheckUpdates;
  final Future<void> Function() onLogout;
  final String? avatarUrl;

  void _openNotifications(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Notifications',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync status'),
              subtitle: Text(
                state.lastSyncAt != null
                    ? 'Last sync: ${state.lastSyncAt!.toLocal()}'
                    : 'Not synced yet',
              ),
            ),
            if (state.hasPendingPunch)
              ListTile(
                leading:
                    const Icon(Icons.cloud_upload, color: AppColors.primary),
                title: const Text('Attendance pending sync'),
              ),
            if (state.error != null)
              ListTile(
                leading:
                    const Icon(Icons.error_outline, color: AppColors.danger),
                title: Text(state.error!),
              ),
            if (state.hasPendingPunch == false && state.error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No new notifications')),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openQuickActions(BuildContext context) {
    final effective = themeMode ?? ThemeMode.system;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Appearance', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 8),
              _ThemeOptionTile(
                label: 'System',
                selected: effective == ThemeMode.system,
                onTap: () => onThemeChanged(null),
              ),
              _ThemeOptionTile(
                label: 'Light',
                selected: effective == ThemeMode.light,
                onTap: () => onThemeChanged(ThemeMode.light),
              ),
              _ThemeOptionTile(
                label: 'Dark',
                selected: effective == ThemeMode.dark,
                onTap: () => onThemeChanged(ThemeMode.dark),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await onCheckUpdates();
                  },
                  icon: const Icon(Icons.system_update_alt),
                  label: const Text('Check for updates'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await onLogout();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAlert = state.hasPendingPunch || state.error != null;

    Widget trailingActions() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _openNotifications(context),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            icon: Badge(
              isLabelVisible: hasAlert,
              child: const Icon(Icons.notifications_none_outlined, size: 24),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _openQuickActions(context),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: avatarUrl == null || avatarUrl!.isEmpty
                  ? Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final logoWidth = compact ? 116.0 : 144.0;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Hr360Logo(width: logoWidth),
                  const Spacer(),
                  trailingActions(),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${greetingForHour()}, $firstName',
                style: theme.textTheme.titleMedium?.copyWith(height: 1.1),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Ready to start your day',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppDecorations.muted(context),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        }

        return Row(
          children: [
            Hr360Logo(width: logoWidth),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${greetingForHour()}, $firstName',
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ready to start your day',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppDecorations.muted(context),
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailingActions(),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.state,
    required this.today,
    required this.roleAllowsCheckIn,
    required this.isLoading,
    required this.isAcquiringLocation,
    required this.control,
    required this.onToggle,
  });

  final AttendanceState state;
  final AttendanceDayReport? today;
  final bool roleAllowsCheckIn;
  final bool isLoading;
  final bool isAcquiringLocation;
  final AttendanceControlConfig? control;
  final VoidCallback? onToggle;

  String? get _blockedMessage {
    if (state.isAwaitingNfc) {
      return 'Waiting for you to tap your NFC card…';
    }
    if (state.isSubmitting || state.isAcquiringLocation) {
      return 'Check-in is already in progress…';
    }
    if (state.isResolvingQueued) {
      return 'Still syncing the previous punch with the server…';
    }
    if (state.hasPendingPunch) {
      return state.pendingPunchFailed
          ? 'Previous punch sync failed — tap Retry or Dismiss below.'
          : 'Previous punch is still syncing — wait or pull to refresh.';
    }
    if (!state.canToggleCheckIn && state.isOpenSession) {
      return 'Please wait a few seconds before checking out.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = state.isOpenSession;
    final elapsed = state.elapsed ?? Duration.zero;
    final interactionBlocked = onToggle == null;

    return AppDecorations.glass(
      context: context,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StatusPill(
                label: isIn ? 'Checked in' : 'Checked out',
                color: isIn
                    ? const Color(0xFF22C55E)
                    : AppDecorations.muted(context),
                icon: isIn ? Icons.circle : Icons.circle_outlined,
              ),
              if (isIn) ...[
                const SizedBox(width: 8),
                const StatusPill(
                  label: 'Working',
                  color: AppColors.primary,
                  icon: Icons.work_outline,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            timerDisplay(state.status, elapsed),
            style: AppTheme.timerTextStyle(theme).copyWith(
              fontSize: 48,
              height: 1,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Today's working time",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppDecorations.muted(context),
            ),
          ),
          const SizedBox(height: 18),
          FloatingPunchButton(
            isCheckedIn: isIn,
            isLoading: isLoading,
            roleAllowsCheckIn: roleAllowsCheckIn,
            isInteractionBlocked: interactionBlocked,
            blockedMessage: _blockedMessage,
            showProgressSnack: control?.hasRules != true,
            onPressed: onToggle ?? () {},
          ),
          if (control?.hasRules == true) ...[
            const SizedBox(height: 12),
            _PunchRequirements(control: control!, isCheckedIn: isIn),
          ],
          const SizedBox(height: 14),
          _LocationRow(
            today: today,
            isAcquiringLocation: isAcquiringLocation,
          ),
        ],
      ),
    );
  }
}

/// Tells the employee up front what the next punch will ask for.
class _PunchRequirements extends StatelessWidget {
  const _PunchRequirements({required this.control, required this.isCheckedIn});

  final AttendanceControlConfig control;
  final bool isCheckedIn;

  @override
  Widget build(BuildContext context) {
    final action = isCheckedIn ? 'check out' : 'check in';
    final names = control.geofences
        .map((g) => g.name)
        .where((n) => n.isNotEmpty)
        .toList();
    final where = names.isEmpty
        ? 'your assigned location'
        : names.length <= 2
            ? names.join(' or ')
            : '${names.take(2).join(', ')} +${names.length - 2}';

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (control.nfcRequired)
          StatusPill(
            label: 'Tap NFC card to $action',
            color: AppColors.primary,
            icon: Icons.contactless,
          ),
        if (control.geofenceRequired)
          StatusPill(
            label: 'Only at $where',
            color: AppColors.secondary,
            icon: Icons.fence,
          ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.today,
    required this.isAcquiringLocation,
  });

  final AttendanceDayReport? today;
  final bool isAcquiringLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String label;
    String sub;
    Color iconColor;

    if (isAcquiringLocation) {
      label = 'Getting GPS location…';
      sub = 'Allow location when prompted';
      iconColor = AppColors.primary;
    } else if (today?.hasLocation == true) {
      label = today!.checkinAddress ?? 'Location captured';
      sub = today!.checkinAccuracyM != null
          ? 'Accuracy ${today!.checkinAccuracyM!.round()} m'
          : 'GPS recorded';
      iconColor = const Color(0xFF22C55E);
    } else {
      label = 'Location not recorded';
      sub = 'Enable location for check-in';
      iconColor = AppDecorations.muted(context);
    }

    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                sub,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppDecorations.muted(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

/// Single status row for pending/failed sync (avoids stacked duplicate banners).
class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({
    required this.error,
    required this.pendingFailed,
    required this.hasPending,
    this.onRetry,
    this.onDismiss,
  });

  final String? error;
  final bool pendingFailed;
  final bool hasPending;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failed = pendingFailed || error != null;
    final color = failed ? AppColors.danger : AppColors.gold;
    final message = error ??
        (pendingFailed
            ? 'Attendance sync failed'
            : hasPending
                ? 'Attendance pending sync'
                : '');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            failed ? Icons.cloud_off : Icons.cloud_sync_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: theme.textTheme.bodyMedium),
          ),
          if (onDismiss != null)
            TextButton(
              onPressed: onDismiss,
              child: const Text('Dismiss'),
            ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.primary : AppDecorations.muted(context),
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}

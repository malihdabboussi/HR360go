import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/authenticated_scope.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/shift_watch_service.dart';
import '../../domain/attendance_control.dart';
import '../../domain/shift_watch.dart';

/// Shift-watch prompts on the attendance screen:
/// - "Did you forget to check out?" when the reminder notification is tapped;
/// - "You left … check out now / wait" when the exit notification is tapped, or
///   whenever the app is open while an automatic check-out is pending;
/// - the background-location explanation before asking for "All the time".
class ShiftWatchTapListener extends ConsumerStatefulWidget {
  const ShiftWatchTapListener({
    super.key,
    required this.onCheckOutNow,
    required this.child,
  });

  /// The normal check-out flow (rules, GPS, NFC).
  final Future<void> Function() onCheckOutNow;
  final Widget child;

  @override
  ConsumerState<ShiftWatchTapListener> createState() => _ShiftWatchTapListenerState();
}

class _ShiftWatchTapListenerState extends ConsumerState<ShiftWatchTapListener>
    with WidgetsBindingObserver {
  bool _disclosureOpen = false;
  bool _exitPromptOpen = false;

  /// Pending exits already asked about (by exit time), so "Wait" is not asked again.
  final Set<DateTime> _answeredExits = {};

  /// Google Play prominent disclosure, shown before the system "All the time" prompt.
  Future<void> _showDisclosure() async {
    if (_disclosureOpen || !mounted) return;
    _disclosureOpen = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined, size: 32),
        title: const Text(shiftWatchDisclosureTitle),
        content: const Text(shiftWatchDisclosureText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No thanks'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    _disclosureOpen = false;
    if (!mounted) return;
    final service = ref.read(shiftWatchServiceProvider);
    if (accepted == true) {
      await service.acceptDisclosure();
    } else {
      service.declineDisclosure();
    }
    // Re-sync: asks for "All the time" after accepting, shows the banner after declining.
    await ref.read(scopedAttendanceControllerProvider.notifier).refresh();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    shiftWatchTapNotifier.addListener(_onTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    shiftWatchTapNotifier.removeListener(_onTap);
    super.dispose();
  }

  /// Back in the app (e.g. after leaving work): reload, which shows a pending exit.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(scopedAttendanceControllerProvider.notifier).refresh();
    }
  }

  Future<void> _onTap() async {
    if (!mounted) return;
    final payload = shiftWatchTapNotifier.value;
    if (payload == null) return;
    shiftWatchTapNotifier.value = null;
    final controller = ref.read(scopedAttendanceControllerProvider.notifier);
    switch (payload) {
      case shiftWatchReminderPayload:
        if (!ref.read(scopedAttendanceControllerProvider).isOpenSession) return; // Already out.
        showForgotCheckoutSheet(context, ref, onCheckOutNow: widget.onCheckOutNow);
      case shiftWatchExitPayload:
        // Fresh state from the Server, then the prompt shows if the exit is still pending.
        _answeredExits.clear();
        await controller.refresh();
      case shiftWatchRefreshSignal:
        await controller.refresh();
    }
  }

  void _maybeShowExitPrompt(AttendanceControlConfig? config) {
    final watch = config?.shiftWatch;
    final exitAt = watch?.pendingExitAt;
    if (watch == null || exitAt == null || _exitPromptOpen || _answeredExits.contains(exitAt)) return;
    if (!ref.read(scopedAttendanceControllerProvider).isOpenSession) return;
    _answeredExits.add(exitAt);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showExitPrompt(watch, exitAt));
  }

  Future<void> _showExitPrompt(ShiftWatchConfig watch, DateTime exitAt) async {
    if (!mounted) return;
    _exitPromptOpen = true;
    final checkOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.directions_walk, size: 32),
        title: const Text('You left your work location'),
        content: Text(exitPromptText(
          place: watch.pendingExitPlace,
          exitAt: exitAt,
          dueAt: watch.checkoutDueAt,
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Wait')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Check out now')),
        ],
      ),
    );
    _exitPromptOpen = false;
    if (checkOut != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await ref.read(shiftWatchServiceProvider).checkOutAtExit(
            dio: ref.read(apiClientProvider).dio,
            timeZone: ref.read(currentSessionProvider).timeZone,
          );
      final at = DateTime.tryParse('${res['checkout_at'] ?? ''}')?.toLocal();
      messenger.showSnackBar(SnackBar(
        content: Text(at == null
            ? 'Checked out'
            : 'Checked out at ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'),
      ));
    } on DioException catch (e) {
      final data = e.response?.data;
      messenger.showSnackBar(SnackBar(
        content: Text(data is Map && data['message'] != null
            ? '${data['message']}'
            : 'Could not check you out. Try again.'),
      ));
    }
    await ref.read(scopedAttendanceControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ShiftWatchStatus>(shiftWatchStatusProvider, (prev, next) {
      if (next == ShiftWatchStatus.needsDisclosure && prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showDisclosure());
      }
    });
    ref.listen<AsyncValue<AttendanceControlConfig>>(
      attendanceControlProvider,
      (_, next) => _maybeShowExitPrompt(next.valueOrNull),
    );
    return widget.child;
  }
}

Future<void> showForgotCheckoutSheet(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() onCheckOutNow,
}) async {
  final watch = ref.read(attendanceControlProvider).valueOrNull?.shiftWatch;
  final shiftEnd = watch?.shiftEndAt?.toLocal();
  final endLabel = shiftEnd == null ? null : TimeOfDay.fromDateTime(shiftEnd).format(context);

  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Did you forget to check out?',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              endLabel == null
                  ? 'You are still checked in.'
                  : 'Your shift ended at $endLabel and you are still checked in.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop('now'),
              icon: const Icon(Icons.logout),
              label: const Text('Check out now'),
            ),
            if (endLabel != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop('end'),
                icon: const Icon(Icons.schedule),
                label: Text('I left at $endLabel, check me out then'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('working'),
              child: const Text("I'm still working, remind me in 1 hour"),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || choice == null) return;

  final controller = ref.read(scopedAttendanceControllerProvider.notifier);
  final service = ref.read(shiftWatchServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  switch (choice) {
    case 'now':
      await onCheckOutNow();
    case 'end':
      try {
        await service.closeAtScheduleEnd(
          dio: ref.read(apiClientProvider).dio,
          timeZone: ref.read(currentSessionProvider).timeZone,
          attendanceId: watch?.openAttendanceId,
        );
        messenger.showSnackBar(SnackBar(content: Text('Checked out at $endLabel')));
      } on DioException catch (e) {
        final data = e.response?.data;
        final message = data is Map && data['message'] != null
            ? '${data['message']}'
            : 'Could not check you out. Try again or check out now.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
      await controller.refresh();
    case 'working':
      await service.snoozeReminder(watch?.shiftEndAt);
      messenger.showSnackBar(
        const SnackBar(content: Text("OK, we'll remind you again in 1 hour")),
      );
  }
}

/// Shown when the company turned on auto check-out but HR360 Go may not use
/// location in the background, so leaving cannot be detected.
class ShiftWatchPermissionBanner extends ConsumerWidget {
  const ShiftWatchPermissionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(shiftWatchStatusProvider);
    if (status != ShiftWatchStatus.needsAlwaysLocation) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your company checks you out automatically when you leave work. '
                  'Allow location "All the time" so HR360 Go can notice when you leave.',
                ),
                const SizedBox(height: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: () => ref.read(shiftWatchServiceProvider).openLocationSettings(),
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

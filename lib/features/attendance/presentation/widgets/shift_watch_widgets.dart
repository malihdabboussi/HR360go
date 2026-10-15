import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/authenticated_scope.dart';
import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/shift_watch_service.dart';

/// Opens the "Did you forget to check out?" sheet when the reminder
/// notification is tapped (also when it launched the app).
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

class _ShiftWatchTapListenerState extends ConsumerState<ShiftWatchTapListener> {
  @override
  void initState() {
    super.initState();
    shiftWatchTapNotifier.addListener(_onTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onTap());
  }

  @override
  void dispose() {
    shiftWatchTapNotifier.removeListener(_onTap);
    super.dispose();
  }

  void _onTap() {
    if (!mounted || shiftWatchTapNotifier.value != shiftWatchReminderPayload) return;
    shiftWatchTapNotifier.value = null;
    final open = ref.read(scopedAttendanceControllerProvider).isOpenSession;
    if (!open) return; // Already checked out.
    showForgotCheckoutSheet(context, ref, onCheckOutNow: widget.onCheckOutNow);
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

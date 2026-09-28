import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../models/check_in_status.dart';
import '../../models/my_attendance_report.dart';

enum DayStatusKind { present, late, absent, off, holiday, working, other }

DayStatusKind dayStatusKind(String status) {
  switch (status.toLowerCase()) {
    case 'present':
    case 'flat scheduled':
      return DayStatusKind.present;
    case 'late':
      return DayStatusKind.late;
    case 'absent':
      return DayStatusKind.absent;
    case 'off':
      return DayStatusKind.off;
    case 'holiday':
      return DayStatusKind.holiday;
    case 'working':
      return DayStatusKind.working;
    default:
      return DayStatusKind.other;
  }
}

Color dayStatusColor(DayStatusKind kind) {
  switch (kind) {
    case DayStatusKind.present:
    case DayStatusKind.working:
      return AppColors.primary;
    case DayStatusKind.late:
      return AppColors.secondary;
    case DayStatusKind.absent:
      return AppColors.danger;
    case DayStatusKind.holiday:
      return AppColors.gold;
    case DayStatusKind.off:
      return AppColors.lightMuted;
    case DayStatusKind.other:
      return AppColors.lightMuted;
  }
}

String formatTime12(String? time24) {
  if (time24 == null || time24.isEmpty) {
    return '—';
  }
  final parts = time24.split(':');
  if (parts.length < 2) {
    return time24;
  }
  var h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final am = h < 12;
  if (h == 0) {
    h = 12;
  } else if (h > 12) {
    h -= 12;
  }
  return '$h:$m ${am ? 'AM' : 'PM'}';
}

String greetingForHour() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stat chip (Uber / Stripe style).
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.accent,
  });

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppDecorations.glassCard(context, radius: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppDecorations.muted(context),
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Home: week summary + compact day dots.
class WeekAtAGlance extends StatelessWidget {
  const WeekAtAGlance({
    super.key,
    required this.report,
    this.today,
  });

  final MyAttendanceReport report;
  final AttendanceDayReport? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayH = today?.totalTimeHours ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('This week', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              '${report.workedHours}h total',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              StatChip(
                label: 'Worked',
                value: '${report.workedHours}h',
                accent: AppColors.primary,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: 'Overtime',
                value: '${report.overtime}h',
                accent: AppColors.secondary,
              ),
              const SizedBox(width: 8),
              StatChip(
                label: 'Today',
                value: '${todayH.toStringAsFixed(1)}h',
              ),
              const SizedBox(width: 8),
              StatChip(
                label: 'Rate',
                value: '${report.attendanceRatePercent.round()}%',
              ),
              const SizedBox(width: 8),
              StatChip(
                label: 'Absent',
                value: '${report.absentDays}',
                accent: AppColors.danger,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CompactWeekRow(days: report.days),
      ],
    );
  }
}

class CompactWeekRow extends StatelessWidget {
  const CompactWeekRow({super.key, required this.days});

  final List<AttendanceDayReport> days;

  @override
  Widget build(BuildContext context) {
    final week = days.length <= 7 ? days : days.sublist(days.length - 7);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final d in week) Expanded(child: _CompactDayDot(day: d)),
      ],
    );
  }
}

class _CompactDayDot extends StatelessWidget {
  const _CompactDayDot({required this.day});

  final AttendanceDayReport day;

  @override
  Widget build(BuildContext context) {
    final kind = dayStatusKind(day.status);
    final color = dayStatusColor(kind);
    final label = day.dayName.length >= 3
        ? day.dayName.substring(0, 3)
        : (day.date.length >= 10 ? day.date.substring(8) : '?');

    return Tooltip(
      message:
          '${day.date} · ${day.status}${day.totalTimeHours > 0 ? ' · ${day.totalTimeHours.toStringAsFixed(1)}h' : ''}',
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppDecorations.muted(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color.withValues(
                alpha: day.punched || day.scheduled ? 0.22 : 0.08,
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: day.totalTimeHours > 0
                    ? (12 + (day.totalTimeHours.clamp(0.0, 10.0) * 2.2))
                    : 12,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: day.punched || day.scheduled
                      ? color
                      : AppDecorations.muted(context),
                ),
                child: day.totalTimeHours > 0
                    ? Center(
                        child: Text(
                          day.totalTimeHours.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WorkHoursRing extends StatelessWidget {
  const WorkHoursRing({
    super.key,
    required this.workedHours,
    required this.overtimeHours,
    required this.targetHours,
    this.centerLabel = 'This week',
  });

  final num workedHours;
  final num overtimeHours;
  final double targetHours;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final worked = workedHours.toDouble();
    final overtime = overtimeHours.toDouble();
    final total = worked + overtime;
    final remaining = (targetHours - worked).clamp(0.0, targetHours);
    final segments = [
      _RingSegment(worked, AppColors.primary),
      _RingSegment(overtime, AppColors.secondary),
      if (remaining > 0) _RingSegment(remaining, AppColors.primary.withValues(alpha: 0.25)),
    ];

    return SizedBox(
      height: 160,
      width: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(160, 160),
            painter: _RingPainter(segments: segments, total: total > 0 ? total : targetHours),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${workedHours is int ? workedHours : workedHours.toStringAsFixed(0)}h',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                centerLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.lightMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingSegment {
  const _RingSegment(this.value, this.color);
  final double value;
  final Color color;
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.segments, required this.total});

  final List<_RingSegment> segments;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const stroke = 14.0;
    var start = -math.pi / 2;

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}

/// Floating biometric punch — circular shadow via [PhysicalModel].
class FloatingPunchButton extends StatelessWidget {
  const FloatingPunchButton({
    super.key,
    required this.isCheckedIn,
    required this.isLoading,
    required this.roleAllowsCheckIn,
    required this.isInteractionBlocked,
    this.blockedMessage,
    this.showProgressSnack = true,
    required this.onPressed,
  });

  final bool isCheckedIn;
  final bool isLoading;
  final bool roleAllowsCheckIn;
  final bool isInteractionBlocked;
  final String? blockedMessage;

  /// Off when attendance-control rules apply: the NFC sheet / hint dialog speaks instead.
  final bool showProgressSnack;
  final VoidCallback onPressed;

  void _handleTap(BuildContext context) {
    if (isLoading) return;
    if (!roleAllowsCheckIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-in is not permitted for your role.'),
        ),
      );
      return;
    }
    if (isInteractionBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blockedMessage ??
                'Wait for the current attendance sync to finish, then try again.',
          ),
        ),
      );
      return;
    }
    if (showProgressSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isCheckedIn ? 'Checking out…' : 'Checking in…'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final glow = isCheckedIn ? AppColors.secondary : AppColors.primary;
    final inner = isCheckedIn
        ? const LinearGradient(
            colors: [AppColors.secondary, Color(0xFFFF9A5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [AppColors.primary, AppColors.darkBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PhysicalModel(
          color: Colors.transparent,
          elevation: 14,
          shadowColor: glow.withValues(alpha: 0.55),
          shape: BoxShape.circle,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : () => _handleTap(context),
              customBorder: const CircleBorder(),
              child: Ink(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: inner,
                ),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isCheckedIn
                              ? Icons.logout_rounded
                              : Icons.fingerprint_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          isCheckedIn ? 'Check out' : 'Check in',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class WeekDayChip extends StatelessWidget {
  const WeekDayChip({super.key, required this.day});

  final AttendanceDayReport day;

  @override
  Widget build(BuildContext context) {
    final kind = dayStatusKind(day.status);
    final color = dayStatusColor(kind);
    final label = switch (kind) {
      DayStatusKind.present => 'P',
      DayStatusKind.late => 'L',
      DayStatusKind.absent => 'A',
      DayStatusKind.working => 'W',
      DayStatusKind.off => '—',
      _ => '?',
    };

    return Column(
      children: [
        Text(
          day.dayName.length >= 3 ? day.dayName.substring(0, 3) : day.dayName,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.lightMuted,
                fontSize: 10,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: day.punched || day.scheduled ? 0.2 : 0.08),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class TimelineDayCard extends StatelessWidget {
  const TimelineDayCard({super.key, required this.day});

  final AttendanceDayReport day;

  @override
  Widget build(BuildContext context) {
    final kind = dayStatusKind(day.status);
    final accent = dayStatusColor(kind);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppDecorations.glassCard(context, radius: 14),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
          ),
          title: Text(
            '${day.dayName} · ${day.date}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _subtitleLine(day),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppDecorations.muted(context),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (day.isLate)
                    StatusPill(
                      label: 'Late by ${day.lateMinutes} min',
                      color: AppColors.secondary,
                      icon: Icons.schedule,
                    ),
                  if (day.checkInTime != null)
                    _DetailRow(
                      icon: Icons.login,
                      text:
                          'In ${formatTime12(day.checkInTime)} · Out ${formatTime12(day.checkOutTime)}',
                    ),
                  if (day.totalTimeHours > 0)
                    _DetailRow(
                      icon: Icons.timelapse,
                      text:
                          'Worked ${day.totalTimeHours.toStringAsFixed(1)} h'
                          '${day.overtimeHoursDay > 0 ? ' · OT ${day.overtimeHoursDay.toStringAsFixed(1)} h' : ''}',
                    ),
                  if (day.hasLocation)
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      text: day.checkinAddress ??
                          '${day.checkinLatitude}, ${day.checkinLongitude}'
                              '${day.checkinAccuracyM != null ? ' · ${day.checkinAccuracyM}m' : ''}',
                    ),
                  if (day.attendanceCyclesCount > 1)
                    _DetailRow(
                      icon: Icons.repeat,
                      text: '${day.attendanceCyclesCount} sessions',
                    ),
                  if (day.notes.isNotEmpty)
                    _DetailRow(icon: Icons.notes, text: day.notes),
                  if (day.punchErrors.isNotEmpty &&
                      day.punchErrors != 'No attendance recorded')
                    _DetailRow(
                      icon: Icons.warning_amber,
                      text: day.punchErrors,
                      color: AppColors.danger,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleLine(AttendanceDayReport day) {
    if (!day.punched) return day.status;
    final inOut =
        '${formatTime12(day.checkInTime)} – ${formatTime12(day.checkOutTime)}';
    if (day.totalTimeHours > 0) {
      return '$inOut · ${day.totalTimeHours.toStringAsFixed(1)} h';
    }
    return inOut;
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? AppDecorations.muted(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String timerDisplay(CheckInStatus? status, Duration? elapsed) {
  if (status?.isOpenSession == true && elapsed != null) {
    return formatDuration(elapsed);
  }
  return '00:00:00';
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/layout/shell_layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/theme/app_theme.dart';
import '../models/my_attendance_report.dart';
import 'widgets/attendance_widgets.dart';

class MyTimeScreen extends ConsumerStatefulWidget {
  const MyTimeScreen({super.key});

  @override
  ConsumerState<MyTimeScreen> createState() => _MyTimeScreenState();
}

class _MyTimeScreenState extends ConsumerState<MyTimeScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  MyAttendanceReport? _report;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = now.subtract(Duration(days: now.weekday - 1));
    _endDate = now;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report =
          await ref.read(attendanceRepositoryProvider).fetchMyAttendanceForPeriod(
                startDate: formatYyyyMmDd(_startDate),
                endDate: formatYyyyMmDd(_endDate),
              );
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final report = _report;

    return RefreshIndicator(
      onRefresh: _load,
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
                ShellLayout.scrollBottomPadding(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My time', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Your attendance timeline',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppDecorations.muted(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateChip(
                          label: 'From',
                          date: formatYyyyMmDd(_startDate),
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DateChip(
                          label: 'To',
                          date: formatYyyyMmDd(_endDate),
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  if (!_loading && report != null) ...[
                    const SizedBox(height: 14),
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
                            label: 'Absent',
                            value: '${report.absentDays}',
                            accent: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CompactWeekRow(days: report.days),
                    const SizedBox(height: 16),
                    Text('Timeline', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...report.days.reversed.map((d) => TimelineDayCard(day: d)),
                    if (report.latePunches.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Late punches', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ...report.latePunches.map((e) => _LateRow(entry: e)),
                    ],
                  ],
                  if (!_loading && report == null && _error == null)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No attendance for this period',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppDecorations.muted(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: AppDecorations.glassCard(context, radius: 12),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppDecorations.muted(context),
                        ),
                  ),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LateRow extends StatelessWidget {
  const _LateRow({required this.entry});

  final LatePunchEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecorations.glassCard(context, radius: 12),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Late ${entry.latePunchMinutes} min · '
              '${formatTime12(entry.checkInTime)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

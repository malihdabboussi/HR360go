import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/leave_models.dart';

/// "Request leave": type, full day / half day / hours, dates, reason. Shows the
/// working days it will use (Server computeLeaveDuration) and the Server's
/// message when a request is blocked (balance, probation…). Pops `true` when sent.
class LeaveRequestFormScreen extends ConsumerStatefulWidget {
  const LeaveRequestFormScreen({super.key});

  @override
  ConsumerState<LeaveRequestFormScreen> createState() => _LeaveRequestFormScreenState();
}

class _LeaveRequestFormScreenState extends ConsumerState<LeaveRequestFormScreen> {
  List<LeaveTypeOption> _types = [];
  List<LeaveBalance> _balances = [];
  bool _loadingTypes = true;
  String? _loadError;

  LeaveRequestDraft _draft = LeaveRequestDraft(start: _today(), end: _today());
  final _reason = TextEditingController();

  double? _days;
  bool _computing = false;
  Timer? _debounce;
  int _computeSeq = 0;

  bool _submitting = false;
  String? _formError;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _loadTypes() async {
    final repo = ref.read(leaveRepositoryProvider);
    try {
      final results = await Future.wait([repo.getRequestableTypes(), repo.getBalances()]);
      if (!mounted) return;
      final types = results[0] as List<LeaveTypeOption>;
      setState(() {
        _types = types;
        _balances = results[1] as List<LeaveBalance>;
        _loadingTypes = false;
        if (types.length == 1) _draft = _draft.copyWith(typeId: types.first.id);
      });
      _scheduleCompute();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingTypes = false;
        _loadError = 'Could not load your leave types.';
      });
    }
  }

  void _update(LeaveRequestDraft next) {
    setState(() {
      _draft = next;
      _formError = null;
    });
    _scheduleCompute();
  }

  void _scheduleCompute() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _compute);
  }

  Future<void> _compute() async {
    final seq = ++_computeSeq;
    if (_draft.typeId == null || _draft.start == null) {
      setState(() => _days = null);
      return;
    }
    setState(() => _computing = true);
    double? days;
    try {
      days = await ref
          .read(leaveRepositoryProvider)
          .computeDays(ref.read(currentSessionProvider).employeeId, _draft);
    } catch (_) {
      days = null;
    }
    if (!mounted || seq != _computeSeq) return;
    setState(() {
      _days = days;
      _computing = false;
    });
  }

  LeaveBalance? get _selectedBalance {
    final type = _types.where((t) => t.id == _draft.typeId).firstOrNull;
    if (type == null) return null;
    // MyLeaveBalance has no id: match by description, then by code.
    return _balances.where((b) => b.name == type.description).firstOrNull ??
        _balances.where((b) => b.name == type.code).firstOrNull;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _draft.start : _draft.effectiveEnd) ?? _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(_today().year - 1),
      lastDate: DateTime(_today().year + 2, 12, 31),
    );
    if (picked == null) return;
    if (isStart) {
      final end = _draft.end;
      _update(_draft.copyWith(start: picked, end: end == null || end.isBefore(picked) ? picked : end));
    } else {
      _update(_draft.copyWith(end: picked));
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _draft.startTime : _draft.endTime;
    final parts = (current ?? (isStart ? '09:00' : '13:00')).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    final v = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _update(isStart ? _draft.copyWith(startTime: v) : _draft.copyWith(endTime: v));
  }

  Future<void> _submit() async {
    final draft = _draft.copyWith(reason: _reason.text);
    final problem = draft.validate();
    if (problem != null) {
      setState(() => _formError = problem);
      return;
    }
    setState(() {
      _submitting = true;
      _formError = null;
    });
    try {
      final result = await ref.read(leaveRepositoryProvider).submit(draft);
      if (!mounted) return;
      if (result.ok) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _formError = result.message);
    } on DioException catch (e) {
      final data = e.response?.data;
      setState(() => _formError = data is Map && data['message'] != null
          ? '${data['message']}'
          : 'Could not send the request. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = _selectedBalance;
    return Scaffold(
      appBar: AppBar(title: const Text('Request leave')),
      body: _loadingTypes
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(_loadError!))
              : _types.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No leave types are assigned to you, or you are still on probation. Contact HR.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _draft.typeId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Leave type', border: OutlineInputBorder()),
                          items: [
                            for (final t in _types)
                              DropdownMenuItem(value: t.id, child: Text(t.label, overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => _update(_draft.copyWith(typeId: v)),
                        ),
                        if (balance != null) ...[
                          const SizedBox(height: 6),
                          Text('Available: ${formatDays(balance.remaining)}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                        const SizedBox(height: 16),
                        SegmentedButton<LeaveDurationType>(
                          segments: [
                            for (final t in LeaveDurationType.values)
                              ButtonSegment(value: t, label: Text(t.label)),
                          ],
                          selected: {_draft.durationType},
                          onSelectionChanged: (s) => _update(_draft.copyWith(durationType: s.first)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _PickerField(
                                label: _draft.durationType == LeaveDurationType.fullDay ? 'From' : 'Date',
                                value: _draft.start == null ? '' : formatDay(_draft.start!),
                                icon: Icons.event,
                                onTap: () => _pickDate(isStart: true),
                              ),
                            ),
                            if (_draft.durationType == LeaveDurationType.fullDay) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PickerField(
                                  label: 'To',
                                  value: _draft.effectiveEnd == null ? '' : formatDay(_draft.effectiveEnd!),
                                  icon: Icons.event,
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (_draft.durationType == LeaveDurationType.halfDay) ...[
                          const SizedBox(height: 16),
                          SegmentedButton<HalfDayPeriod>(
                            segments: [
                              for (final p in HalfDayPeriod.values) ButtonSegment(value: p, label: Text(p.label)),
                            ],
                            selected: {_draft.halfDayPeriod},
                            onSelectionChanged: (s) => _update(_draft.copyWith(halfDayPeriod: s.first)),
                          ),
                        ],
                        if (_draft.durationType == LeaveDurationType.hourly) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _PickerField(
                                  label: 'From',
                                  value: _draft.startTime ?? '',
                                  icon: Icons.schedule,
                                  onTap: () => _pickTime(isStart: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PickerField(
                                  label: 'To',
                                  value: _draft.endTime ?? '',
                                  icon: Icons.schedule,
                                  onTap: () => _pickTime(isStart: false),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        _DurationLine(days: _days, computing: _computing, hasType: _draft.typeId != null),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reason,
                          maxLength: 255,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                          onChanged: (_) {
                            if (_formError != null) setState(() => _formError = null);
                          },
                        ),
                        if (_formError != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(_formError!, style: const TextStyle(color: AppColors.danger)),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send),
                          label: const Text('Send request'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your manager and/or HR approve the request. Your balance changes only when it is approved.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.value, required this.icon, required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: Icon(icon),
          ),
          child: Text(value.isEmpty ? 'Choose' : value),
        ),
      );
}

class _DurationLine extends StatelessWidget {
  const _DurationLine({required this.days, required this.computing, required this.hasType});

  final double? days;
  final bool computing;
  final bool hasType;

  @override
  Widget build(BuildContext context) {
    if (!hasType) return const SizedBox.shrink();
    if (computing) {
      return const Row(children: [
        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Calculating…'),
      ]);
    }
    if (days == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            days == 0
                ? 'These dates are not working days for you.'
                : 'Uses ${formatDays(days!)} (working days only)',
          ),
        ),
      ],
    );
  }
}

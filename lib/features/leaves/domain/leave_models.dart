// Leave self-service models, matching the Server `leave_request` API
// (same contract as the web "My leaves" page; see Server/docs/features/leave-requests.md).

enum LeaveDurationType {
  fullDay('full_day', 'Full day'),
  halfDay('half_day', 'Half day'),
  hourly('hourly', 'Hours');

  const LeaveDurationType(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static LeaveDurationType parse(dynamic v) => LeaveDurationType.values.firstWhere(
        (t) => t.apiValue == '$v',
        orElse: () => LeaveDurationType.fullDay,
      );
}

enum HalfDayPeriod {
  morning('morning', 'Morning'),
  afternoon('afternoon', 'Afternoon');

  const HalfDayPeriod(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static HalfDayPeriod? parse(dynamic v) {
    for (final p in HalfDayPeriod.values) {
      if (p.apiValue == '$v') return p;
    }
    return null;
  }
}

enum LeaveStatus { pending, approved, rejected, other }

LeaveStatus parseLeaveStatus(dynamic v) {
  switch ('$v'.toLowerCase()) {
    case 'pending':
    case 'requested':
      return LeaveStatus.pending;
    case 'approved':
      return LeaveStatus.approved;
    case 'rejected':
      return LeaveStatus.rejected;
    default:
      return LeaveStatus.other;
  }
}

/// One row of `GET /leave_request/MyLeaveBalance` (days).
class LeaveBalance {
  const LeaveBalance({
    required this.name,
    required this.total,
    required this.used,
    required this.remaining,
    this.onProbation = false,
  });

  final String name;
  final double total;
  final double used;

  /// Already net of `used` (computed by the Server); never subtract again.
  final double remaining;
  final bool onProbation;

  static List<LeaveBalance> listFrom(dynamic raw) {
    final rows = _unwrapList(raw);
    return rows
        .map((r) => LeaveBalance(
              name: '${r['description'] ?? r['code'] ?? 'Leave'}',
              total: _toDouble(r['total']),
              used: _toDouble(r['used']),
              remaining: _toDouble(r['remaining_days'] ?? r['remaining']),
              onProbation: r['on_probation'] == true,
            ))
        // Server placeholder when nothing is assigned.
        .where((b) => b.name != 'No Leaves Added Yet')
        .toList();
  }
}

/// A leave type the employee may request (`GET /leave_request/getAssignedLeaves`).
class LeaveTypeOption {
  const LeaveTypeOption({
    required this.id,
    required this.code,
    this.description,
    this.primaryTag,
    this.paid = true,
  });

  final String id;
  final String code;
  final String? description;
  final String? primaryTag;
  final bool paid;

  /// Same label as the web picker: `code · tag`.
  String get label => [code, if (primaryTag != null && primaryTag!.isNotEmpty) primaryTag!].join(' · ');

  static List<LeaveTypeOption> listFrom(dynamic raw) => _unwrapList(raw)
      .where((r) => '${r['id'] ?? ''}'.isNotEmpty)
      .map((r) => LeaveTypeOption(
            id: '${r['id']}',
            code: '${r['code'] ?? r['description'] ?? 'Leave'}',
            description: r['description']?.toString(),
            primaryTag: r['primaryTag']?.toString(),
            paid: r['paid'] != false,
          ))
      .toList();
}

/// One of the employee's own requests (`GET /leave_request/getEmployeeLeavesRequest`).
class LeaveRequestItem {
  const LeaveRequestItem({
    required this.id,
    required this.leaveType,
    required this.start,
    required this.end,
    required this.status,
    this.reason = '',
    this.durationType = LeaveDurationType.fullDay,
    this.halfDayPeriod,
    this.startTime,
    this.endTime,
    this.approvedByManager,
    this.approvedByHr,
    this.createdAt,
  });

  final String id;
  final String leaveType;
  final DateTime start;
  final DateTime end;
  final LeaveStatus status;
  final String reason;
  final LeaveDurationType durationType;
  final HalfDayPeriod? halfDayPeriod;
  final String? startTime;
  final String? endTime;
  final bool? approvedByManager;
  final bool? approvedByHr;
  final DateTime? createdAt;

  bool get isPending => status == LeaveStatus.pending;

  static List<LeaveRequestItem> listFrom(dynamic raw) {
    final out = <LeaveRequestItem>[];
    for (final r in _unwrapList(raw)) {
      final start = parseYmd(r['start']);
      if (start == null || '${r['id'] ?? ''}'.isEmpty) continue;
      out.add(LeaveRequestItem(
        id: '${r['id']}',
        leaveType: '${r['leave_type'] ?? 'Leave'}',
        start: start,
        end: parseYmd(r['end']) ?? start,
        status: parseLeaveStatus(r['status']),
        reason: '${r['reason'] ?? ''}',
        durationType: LeaveDurationType.parse(r['duration_type']),
        halfDayPeriod: HalfDayPeriod.parse(r['half_day_period']),
        startTime: _hhmm(r['start_time']),
        endTime: _hhmm(r['end_time']),
        approvedByManager: r['approved_by_manager'] is bool ? r['approved_by_manager'] as bool : null,
        approvedByHr: r['approved_by_hr'] is bool ? r['approved_by_hr'] as bool : null,
        createdAt: DateTime.tryParse('${r['created_at'] ?? ''}'),
      ));
    }
    return out;
  }

  /// Where a pending request is in the approval chain.
  String get statusLabel {
    switch (status) {
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
      case LeaveStatus.pending:
        if (approvedByManager == true && approvedByHr != true) return 'Waiting for HR';
        return 'Pending';
      case LeaveStatus.other:
        return 'Unknown';
    }
  }

  String get whenLabel => describeLeaveWhen(
        start: start,
        end: end,
        durationType: durationType,
        halfDayPeriod: halfDayPeriod,
        startTime: startTime,
        endTime: endTime,
      );
}

/// What the employee fills in on the "Request leave" form.
class LeaveRequestDraft {
  const LeaveRequestDraft({
    this.typeId,
    this.durationType = LeaveDurationType.fullDay,
    this.start,
    this.end,
    this.halfDayPeriod = HalfDayPeriod.morning,
    this.startTime,
    this.endTime,
    this.reason = '',
  });

  final String? typeId;
  final LeaveDurationType durationType;
  final DateTime? start;
  final DateTime? end;
  final HalfDayPeriod halfDayPeriod;

  /// "HH:mm"
  final String? startTime;
  final String? endTime;
  final String reason;

  LeaveRequestDraft copyWith({
    String? typeId,
    LeaveDurationType? durationType,
    DateTime? start,
    DateTime? end,
    HalfDayPeriod? halfDayPeriod,
    String? startTime,
    String? endTime,
    String? reason,
  }) =>
      LeaveRequestDraft(
        typeId: typeId ?? this.typeId,
        durationType: durationType ?? this.durationType,
        start: start ?? this.start,
        end: end ?? this.end,
        halfDayPeriod: halfDayPeriod ?? this.halfDayPeriod,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        reason: reason ?? this.reason,
      );

  /// The range end used for the request (half day / hours are single-day).
  DateTime? get effectiveEnd => durationType == LeaveDurationType.fullDay ? (end ?? start) : start;

  /// First problem to show, or null when the draft can be sent. Same rules as the web form
  /// (reason ≥ 2 chars) plus the Server's checks that would otherwise come back as errors.
  String? validate() {
    if (typeId == null || typeId!.isEmpty) return 'Choose a leave type.';
    if (start == null) return 'Choose the date.';
    final e = effectiveEnd!;
    if (e.isBefore(start!)) return 'The end date must be on or after the start date.';
    if (durationType == LeaveDurationType.hourly) {
      if (startTime == null || endTime == null) return 'Choose the start and end time.';
      if (_minutes(endTime!) <= _minutes(startTime!)) return 'The end time must be after the start time.';
    }
    if (reason.trim().length < 2) return 'Add a short reason.';
    if (reason.trim().length > 255) return 'The reason is too long (255 characters max).';
    return null;
  }

  /// Body for `POST /leave_request/LeaveRequest` (same as the web `buildLeaveRequestPayload`).
  Map<String, dynamic> toPayload() => {
        'type': typeId,
        'start': formatYmd(start!),
        'end': formatYmd(effectiveEnd!),
        'reason': reason.trim(),
        'duration_type': durationType.apiValue,
        if (durationType == LeaveDurationType.halfDay) 'half_day_period': halfDayPeriod.apiValue,
        if (durationType == LeaveDurationType.hourly) 'start_time': startTime,
        if (durationType == LeaveDurationType.hourly) 'end_time': endTime,
      };
}

/// Result of submitting a request: the Server answers HTTP 200 with
/// `{ success: false, message }` when a request is blocked (balance, probation…).
class LeaveSubmitResult {
  const LeaveSubmitResult.ok() : ok = true, message = null;
  const LeaveSubmitResult.blocked(this.message) : ok = false;

  final bool ok;
  final String? message;

  static LeaveSubmitResult fromResponse(dynamic data) {
    if (data is Map && data['success'] == false) {
      final msg = '${data['message'] ?? data['answer'] ?? 'The request could not be sent.'}';
      return LeaveSubmitResult.blocked(msg);
    }
    return const LeaveSubmitResult.ok();
  }
}

String describeLeaveWhen({
  required DateTime start,
  required DateTime end,
  required LeaveDurationType durationType,
  HalfDayPeriod? halfDayPeriod,
  String? startTime,
  String? endTime,
}) {
  final s = formatDay(start);
  switch (durationType) {
    case LeaveDurationType.halfDay:
      return '$s · ${halfDayPeriod?.label ?? 'Half day'}';
    case LeaveDurationType.hourly:
      return '$s · ${startTime ?? '?'}–${endTime ?? '?'}';
    case LeaveDurationType.fullDay:
      final sameDay = start.year == end.year && start.month == end.month && start.day == end.day;
      return sameDay ? s : '$s → ${formatDay(end)}';
  }
}

String formatDays(double days) {
  // 1.50 → "1.5", 2.00 → "2"
  final text = days.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$text ${days == 1 ? 'day' : 'days'}';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

String formatYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? parseYmd(dynamic v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('${v ?? ''}');
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String? _hhmm(dynamic v) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${v ?? ''}');
  if (m == null) return null;
  return '${m.group(1)!.padLeft(2, '0')}:${m.group(2)}';
}

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

List<Map<String, dynamic>> _unwrapList(dynamic raw) {
  var data = raw;
  if (data is Map && data['data'] is List) data = data['data'];
  if (data is! List) return const [];
  return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

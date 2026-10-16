import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/features/leaves/domain/leave_models.dart';

void main() {
  group('parsing Server responses', () {
    test('balances: remaining is taken as-is, placeholder row dropped', () {
      final list = LeaveBalance.listFrom([
        {'description': 'Annual', 'total': 21, 'used': 5, 'remaining_days': 16, 'on_probation': false},
        {'description': 'No Leaves Added Yet', 'total': 0, 'used': 0, 'remaining_days': 0},
      ]);
      expect(list, hasLength(1));
      expect(list.first.name, 'Annual');
      expect(list.first.remaining, 16);
    });

    test('assigned types use the web label "code · tag"', () {
      final types = LeaveTypeOption.listFrom({
        'data': [
          {'id': 't1', 'code': 'AL', 'description': 'Annual', 'primaryTag': 'Paid'},
          {'id': '', 'code': 'bad'},
        ],
      });
      expect(types, hasLength(1));
      expect(types.first.label, 'AL · Paid');
    });

    test('requests: status, approval step and when', () {
      final items = LeaveRequestItem.listFrom([
        {
          'id': 'r1', 'leave_type': 'AL', 'start': '2026-10-20', 'end': '2026-10-22',
          'status': 'Pending', 'approved_by_manager': true, 'approved_by_hr': null,
          'duration_type': 'full_day', 'reason': 'Trip',
        },
        {
          'id': 'r2', 'leave_type': 'SL', 'start': '2026-10-01T00:00:00.000Z', 'end': '2026-10-01',
          'status': 'Approved', 'duration_type': 'hourly', 'start_time': '09:00:00', 'end_time': '11:30:00',
        },
        {'id': 'r3', 'start': null},
      ]);
      expect(items, hasLength(2));
      expect(items[0].isPending, isTrue);
      expect(items[0].statusLabel, 'Waiting for HR');
      expect(items[0].whenLabel, '20 Oct 2026 → 22 Oct 2026');
      expect(items[1].statusLabel, 'Approved');
      expect(items[1].whenLabel, '1 Oct 2026 · 09:00–11:30');
    });
  });

  group('draft', () {
    final base = LeaveRequestDraft(
      typeId: 't1',
      start: DateTime(2026, 10, 20),
      end: DateTime(2026, 10, 22),
      reason: 'Family trip',
    );

    test('full day payload keeps the range', () {
      expect(base.validate(), isNull);
      expect(base.toPayload(), {
        'type': 't1', 'start': '2026-10-20', 'end': '2026-10-22',
        'reason': 'Family trip', 'duration_type': 'full_day',
      });
    });

    test('half day and hours are single-day with their extra fields', () {
      final half = base.copyWith(durationType: LeaveDurationType.halfDay, halfDayPeriod: HalfDayPeriod.afternoon);
      expect(half.toPayload(), containsPair('end', '2026-10-20'));
      expect(half.toPayload(), containsPair('half_day_period', 'afternoon'));
      final hours = base.copyWith(durationType: LeaveDurationType.hourly, startTime: '09:00', endTime: '11:00');
      expect(hours.validate(), isNull);
      expect(hours.toPayload(), allOf(containsPair('start_time', '09:00'), containsPair('end', '2026-10-20')));
    });

    test('validation messages', () {
      expect(const LeaveRequestDraft().validate(), 'Choose a leave type.');
      expect(base.copyWith(end: DateTime(2026, 10, 19)).validate(), contains('end date'));
      expect(base.copyWith(durationType: LeaveDurationType.hourly).validate(), contains('start and end time'));
      expect(
        base.copyWith(durationType: LeaveDurationType.hourly, startTime: '11:00', endTime: '10:00').validate(),
        contains('after the start time'),
      );
      expect(base.copyWith(reason: ' x ').validate(), 'Add a short reason.');
    });
  });

  test('blocked requests come back as HTTP 200 with success:false', () {
    final blocked = LeaveSubmitResult.fromResponse({
      'success': false,
      'code': 'LEAVE_REQUEST_BLOCKED',
      'message': 'Insufficient leave balance. Remaining: 2.00 days',
    });
    expect(blocked.ok, isFalse);
    expect(blocked.message, contains('Insufficient'));
    expect(LeaveSubmitResult.fromResponse({'id': 'x', 'status': 'Pending'}).ok, isTrue);
  });

  test('formatDays', () {
    expect(formatDays(1), '1 day');
    expect(formatDays(2), '2 days');
    expect(formatDays(1.5), '1.5 days');
    expect(formatDays(0.25), '0.25 days');
  });
}

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/core/permissions/attendance_user_error.dart';
import 'package:hr360_go/core/subscription/plan_modules.dart';

void main() {
  test('attendance-only plan: check-in yes, leaves and tasks no', () {
    final plan = PlanModules.fromJson({
      'subscriptionStatus': 'active',
      'legacyUnrestricted': false,
      'modules': {
        'attendance': {'enabled': true},
      },
    });
    expect(plan.has(PlanModuleKeys.attendance), isTrue);
    expect(plan.has(PlanModuleKeys.leave), isFalse);
    expect(plan.has(PlanModuleKeys.tasks), isFalse);
  });

  test('HR bundle plan opens leaves and check-in', () {
    final plan = PlanModules.fromJson({
      'legacyUnrestricted': false,
      'modules': {
        'attendance': {'enabled': true},
        'leave': {'enabled': true},
        'employees': {'enabled': true},
      },
    });
    expect(plan.has(PlanModuleKeys.leave), isTrue);
    expect(plan.has(PlanModuleKeys.attendance), isTrue);
    expect(plan.has(PlanModuleKeys.payroll), isFalse);
  });

  test('legacy companies, Full HR360 and unreadable plans hide nothing', () {
    expect(PlanModules.fromJson({'legacyUnrestricted': true, 'modules': {}}).has('leave'), isTrue);
    expect(PlanModules.fromJson({'modules': {'full_hr360': {'enabled': true}}}).has('tasks'), isTrue);
    expect(PlanModules.fromJson('not json').has('attendance'), isTrue);
  });

  test('plan refusals get a clear message', () {
    DioException refused(String code) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 403,
            data: {'error': code},
          ),
        );
    expect(formatAttendanceUserError(refused('SUBSCRIPTION_FEATURE_NOT_AVAILABLE')),
        contains("isn't part of your company's HR360 plan"));
    expect(formatAttendanceUserError(refused('tenant_subscription_suspended')), contains('suspended'));
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/core/permissions/check_in_permission.dart';

void main() {
  group('evaluateCanMobileCheckIn', () {
    test('empty session permissions soft-defaults to allowed', () {
      expect(evaluateCanMobileCheckIn(permissions: {}), isTrue);
    });

    test('explicit mobile-check-in.read false denies', () {
      expect(
        evaluateCanMobileCheckIn(
          permissions: {
            'mobile-check-in': {'read': false},
          },
        ),
        isFalse,
      );
    });

    test('explicit mobile-check-in.read true allows', () {
      expect(
        evaluateCanMobileCheckIn(
          permissions: {
            'mobile-check-in': {'read': true},
          },
        ),
        isTrue,
      );
    });

    test('catalog action id present allows', () {
      expect(
        evaluateCanMobileCheckIn(
          permissions: {},
          enabledActionIds: [mobileCheckInActionId],
        ),
        isTrue,
      );
    });

    test('legacy false wins over catalog action id', () {
      expect(
        evaluateCanMobileCheckIn(
          permissions: {
            'mobile-check-in': {'read': false},
          },
          enabledActionIds: [mobileCheckInActionId],
        ),
        isFalse,
      );
    });
  });

  group('evaluateCanMobileAccess', () {
    test('soft-defaults on when absent', () {
      expect(evaluateCanMobileAccess(permissions: {}), isTrue);
    });

    test('explicit false denies', () {
      expect(
        evaluateCanMobileAccess(
          permissions: {
            'mobile-access': {'read': false},
          },
        ),
        isFalse,
      );
    });
  });
}

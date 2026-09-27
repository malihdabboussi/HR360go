import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/features/attendance/domain/attendance_auth_token.dart';
import 'package:hr360_go/features/attendance/domain/attendance_checkin_errors.dart';
import 'package:hr360_go/features/attendance/domain/attendance_checkin_response.dart';

const sampleJwt =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U';

const checkinTime = '2026-06-04T14:25:34.756Z';

void main() {
  group('compact JWT for Plan B', () {
    test('accepts a three-segment JWT', () {
      expect(isCompactJwt(sampleJwt), isTrue);
      expect(resolveCompactJwtForPlanB(sampleJwt), sampleJwt);
    });

    test('rejects session-like JSON strings', () {
      expect(isCompactJwt('{"token":"x"}'), isFalse);
      expect(resolveCompactJwtForPlanB('{"token":"x"}'), isNull);
    });
  });

  group('primary /Checkin response parsing', () {
    test('queued:true does not require Checkin_Details', () {
      final queued = {
        'success': true,
        'queued': true,
        'status': 'received',
        'checkinTime': checkinTime,
      };
      expect(isQueuedCheckInResponse(queued), isTrue);
      expect(isLegacyCheckInResponse(queued), isFalse);
      expect(parsePrimaryCheckInResponse(queued), isA<PrimaryCheckInQueued>());
    });

    test('legacy Checkin_Details response still works', () {
      final legacy = {
        'Checkin_Details': {
          'attendance_id': '1',
          'checkin_date': '2026-06-04',
          'clock_in_time': '09:00:00',
          'clock_out_time': '',
          'created_at': '',
          'employee_id': 'e1',
          'updated_at': '',
        },
      };
      expect(isLegacyCheckInResponse(legacy), isTrue);
      expect(parsePrimaryCheckInResponse(legacy), isA<PrimaryCheckInLegacy>());
    });
  });

  group('isPlanBEligibleError', () {
    test('returns true for HTTP 500', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(isPlanBEligibleError(err), isTrue);
    });

    test('returns false for HTTP 401', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
          requestOptions: RequestOptions(path: '/'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );
      expect(isPlanBEligibleError(err), isFalse);
    });

    test('returns true for connection timeout', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(isPlanBEligibleError(err), isTrue);
    });
  });
}

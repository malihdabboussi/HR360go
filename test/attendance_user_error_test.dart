import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/core/permissions/attendance_user_error.dart';

void main() {
  test('maps Dio 500 noise to short copy', () {
    expect(
      formatAttendanceUserError(
        'DioException [bad response]: This exception was thrown because the response has a status code of 500',
      ),
      'Could not update attendance. Please try again.',
    );
  });

  test('maps 403 to role message', () {
    expect(
      formatAttendanceUserError('DioException [bad response]: status code of 403'),
      'Check-in is not permitted for your role.',
    );
  });
}

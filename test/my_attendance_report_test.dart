import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/features/attendance/models/my_attendance_report.dart';

void main() {
  group('MyAttendanceReport.fromJson', () {
    test('accepts H:MM string hours and decimal fields', () {
      final report = MyAttendanceReport.fromJson({
        'employee_id': 'e1',
        'first_name': 'A',
        'last_name': 'B',
        'working_days': 5,
        'worked_hours': '0:00',
        'worked_hours_decimal': 0,
        'overtime': '1:30',
        'overtime_decimal': 1.5,
        'absent_days': 0,
        'daysReport': [
          {
            'date': '2026-07-15',
            'day_name': 'Wed',
            'status': 'present',
            'scheduled': true,
            'punched': true,
            'total_time': '0:00',
            'total_time_decimal_hours': 0,
            'overtime_hours_day': '0:00',
            'overtime_hours_day_decimal': 0,
          },
        ],
        'late_punch_array': [],
      });

      expect(report.workedHours, 0);
      expect(report.overtime, 1.5);
      expect(report.days.single.totalTimeHours, 0);
    });
  });
}

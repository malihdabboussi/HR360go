import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/core/updates/app_update_service.dart';

void main() {
  group('AppUpdateService version compare', () {
    test('detects newer patch', () {
      expect(AppUpdateService.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('detects newer minor/major', () {
      expect(AppUpdateService.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(AppUpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
    });

    test('equal versions are not newer', () {
      expect(AppUpdateService.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(AppUpdateService.isNewerVersion('v1.2.3', '1.2.3'), isFalse);
    });
  });
}

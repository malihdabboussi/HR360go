import 'package:flutter_test/flutter_test.dart';
import 'package:hr360_go/features/attendance/domain/location_availability.dart';

void main() {
  group('LocationAvailability', () {
    test('service disabled opens system location settings', () {
      const blocked = LocationAvailability.blocked(
        LocationBlockReason.serviceDisabled,
      );
      expect(blocked.ok, isFalse);
      expect(blocked.settingsTarget, LocationSettingsTarget.systemLocation);
    });

    test('permission denied forever opens app settings', () {
      const blocked = LocationAvailability.blocked(
        LocationBlockReason.permissionDeniedForever,
      );
      expect(blocked.settingsTarget, LocationSettingsTarget.appSettings);
    });

    test('fix unavailable does not claim location is turned off', () {
      const blocked = LocationAvailability.blocked(
        LocationBlockReason.fixUnavailable,
      );
      expect(blocked.ok, isFalse);
      expect(blocked.settingsTarget, LocationSettingsTarget.systemLocation);
      expect(blocked.dialogTitle, isNot(contains('turned off')));
      expect(blocked.dialogMessage, contains('Location is on'));
    });
  });
}

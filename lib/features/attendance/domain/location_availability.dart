/// Why GPS could not be captured on a device.
enum LocationBlockReason {
  /// Device location services (system GPS) are off.
  serviceDisabled,

  /// Permission denied; can ask again.
  permissionDenied,

  /// Permanently denied — user must open app settings.
  permissionDeniedForever,

  /// Service and permission are OK, but no position fix arrived in time.
  fixUnavailable,
}

enum LocationSettingsTarget {
  /// System location services toggle (iOS Settings → Privacy → Location / Android location).
  systemLocation,

  /// App-specific permissions page.
  appSettings,
}

class LocationAvailability {
  const LocationAvailability.ready()
      : ok = true,
        blockReason = null;

  const LocationAvailability.blocked(this.blockReason) : ok = false;

  final bool ok;
  final LocationBlockReason? blockReason;

  LocationSettingsTarget get settingsTarget {
    switch (blockReason) {
      case LocationBlockReason.serviceDisabled:
      case LocationBlockReason.fixUnavailable:
        return LocationSettingsTarget.systemLocation;
      case LocationBlockReason.permissionDenied:
      case LocationBlockReason.permissionDeniedForever:
      case null:
        return LocationSettingsTarget.appSettings;
    }
  }

  String get dialogTitle {
    switch (blockReason) {
      case LocationBlockReason.serviceDisabled:
        return 'Location is turned off';
      case LocationBlockReason.permissionDenied:
      case LocationBlockReason.permissionDeniedForever:
        return 'Location permission needed';
      case LocationBlockReason.fixUnavailable:
        return 'Could not get your location';
      case null:
        return 'Location unavailable';
    }
  }

  String get dialogMessage {
    switch (blockReason) {
      case LocationBlockReason.serviceDisabled:
        return 'Turn on Location Services so HR360 Go can record where you check in. You can continue without GPS if needed.';
      case LocationBlockReason.permissionDenied:
        return 'Allow location access for HR360 Go to record your check-in location. You can continue without GPS if needed.';
      case LocationBlockReason.permissionDeniedForever:
        return 'Location access is blocked for HR360 Go. Open Settings and enable Location for this app. You can continue without GPS if needed.';
      case LocationBlockReason.fixUnavailable:
        return 'Location is on, but your phone could not get a GPS fix in time. Move near a window or outdoors, make sure precise location / Google location accuracy is enabled, then try again. You can continue without GPS if needed.';
      case null:
        return 'Location could not be captured. You can continue without GPS if needed.';
    }
  }
}

class CheckInGeo {
  const CheckInGeo({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAtIso,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final String capturedAtIso;

  Map<String, String> toQueryParams() => {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'accuracy': accuracyMeters.toString(),
        'locationCapturedAt': capturedAtIso,
      };
}

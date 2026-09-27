class CheckInStatus {
  const CheckInStatus({
    required this.isCheckedIn,
    this.checkinTime,
    this.checkoutTime,
    this.raw,
  });

  /// From API `checkin_status` (boolean on web).
  final bool isCheckedIn;
  final String? checkinTime;
  final String? checkoutTime;
  final Map<String, dynamic>? raw;

  /// Live timer when checked in and not yet checked out (mirrors web Navbar).
  bool get isOpenSession =>
      isCheckedIn && (checkoutTime == null || checkoutTime!.isEmpty);

  factory CheckInStatus.fromJson(dynamic data) {
    if (data is! Map) {
      return const CheckInStatus(isCheckedIn: false);
    }
    final map = Map<String, dynamic>.from(data);
    final rawStatus = map['checkin_status'];
    final bool isIn;
    if (rawStatus is bool) {
      isIn = rawStatus;
    } else {
      final status = rawStatus?.toString().toLowerCase();
      isIn = status == 'checked_in' ||
          status == 'checkin' ||
          status == 'in' ||
          status == 'true' ||
          map['is_checked_in'] == true;
    }
    return CheckInStatus(
      isCheckedIn: isIn,
      checkinTime: map['checkin_time']?.toString(),
      checkoutTime: map['checkout_time']?.toString(),
      raw: map,
    );
  }
}

/// Parses API time-only check-in for live timer (mirrors web Navbar).
DateTime parseOpenCheckinLocalTime(String checkinTime) {
  final parts = checkinTime.split(':').map(int.parse).toList();
  final h = parts.isNotEmpty ? parts[0] : 0;
  final m = parts.length > 1 ? parts[1] : 0;
  final s = parts.length > 2 ? parts[2] : 0;
  final now = DateTime.now();
  var d = DateTime(now.year, now.month, now.day, h, m, s);
  if (d.isAfter(now)) {
    d = d.subtract(const Duration(days: 1));
  }
  return d;
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

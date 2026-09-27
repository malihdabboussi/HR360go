import 'check_in_geo.dart';

class AttendanceCheckInRequest {
  const AttendanceCheckInRequest({
    required this.timeZone,
    required this.checkinTime,
    this.geo,
  });

  final String timeZone;
  final String checkinTime;
  final CheckInGeo? geo;
}

class QueuedCheckInResponse {
  const QueuedCheckInResponse({
    this.success,
    required this.queued,
    this.status,
    this.checkinTime,
    this.message,
  });

  final bool? success;
  final bool queued;
  final String? status;
  final String? checkinTime;
  final String? message;

  factory QueuedCheckInResponse.fromJson(Map<String, dynamic> json) {
    return QueuedCheckInResponse(
      success: json['success'] as bool?,
      queued: json['queued'] == true,
      status: json['status']?.toString(),
      checkinTime: json['checkinTime']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

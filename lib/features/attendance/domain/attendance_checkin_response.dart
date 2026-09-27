import '../models/attendance_check_in_request.dart';

class LegacyCheckInDetails {
  LegacyCheckInDetails(this.raw);
  final Map<String, dynamic> raw;
}

bool isQueuedCheckInResponse(dynamic data) {
  return data is Map && data['queued'] == true;
}

bool isLegacyCheckInResponse(dynamic data) {
  return data is Map && data.containsKey('Checkin_Details');
}

sealed class PrimaryCheckInParseResult {}

class PrimaryCheckInQueued extends PrimaryCheckInParseResult {
  PrimaryCheckInQueued(this.data);
  final QueuedCheckInResponse data;
}

class PrimaryCheckInLegacy extends PrimaryCheckInParseResult {
  PrimaryCheckInLegacy(this.data);
  final LegacyCheckInDetails data;
}

PrimaryCheckInParseResult parsePrimaryCheckInResponse(dynamic data) {
  if (isQueuedCheckInResponse(data)) {
    return PrimaryCheckInQueued(
      QueuedCheckInResponse.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }
  if (isLegacyCheckInResponse(data)) {
    return PrimaryCheckInLegacy(
      LegacyCheckInDetails(Map<String, dynamic>.from(data as Map)),
    );
  }
  throw FormatException('Unexpected /Checkin response shape');
}

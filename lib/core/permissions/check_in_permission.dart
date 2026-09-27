/// Catalog action for HR360 Go mobile punch.
const mobileCheckInActionId = 'actions.mobile.check-in';

/// Catalog action for HR360 Go mobile app login / access.
const mobileAccessActionId = 'actions.mobile.access';

/// @Deprecated Prefer [mobileCheckInActionId]. Kept for transitional tests.
const remoteCheckInActionId = 'actions.time-attendance.remote-checkin';

bool _evaluateMobileReadGate({
  required Map<String, Map<String, bool>> permissions,
  required String legacyModule,
  required String catalogActionId,
  List<String>? enabledActionIds,
}) {
  if (permissions.containsKey(legacyModule)) {
    return permissions[legacyModule]?['read'] == true;
  }

  if (enabledActionIds != null && enabledActionIds.contains(catalogActionId)) {
    return true;
  }

  // Soft-default ON when legacy key absent (pre-migration roles).
  return true;
}

/// Whether the employee may punch from HR360 Go (mobile check-in).
bool evaluateCanRemoteCheckIn({
  required Map<String, Map<String, bool>> permissions,
  List<String>? enabledActionIds,
}) =>
    evaluateCanMobileCheckIn(
      permissions: permissions,
      enabledActionIds: enabledActionIds,
    );

bool evaluateCanMobileCheckIn({
  required Map<String, Map<String, bool>> permissions,
  List<String>? enabledActionIds,
}) =>
    _evaluateMobileReadGate(
      permissions: permissions,
      legacyModule: 'mobile-check-in',
      catalogActionId: mobileCheckInActionId,
      enabledActionIds: enabledActionIds,
    );

/// Whether the employee may use the HR360 Go mobile app.
bool evaluateCanMobileAccess({
  required Map<String, Map<String, bool>> permissions,
  List<String>? enabledActionIds,
}) =>
    _evaluateMobileReadGate(
      permissions: permissions,
      legacyModule: 'mobile-access',
      catalogActionId: mobileAccessActionId,
      enabledActionIds: enabledActionIds,
    );

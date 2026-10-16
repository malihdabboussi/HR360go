import 'permission_codec.dart';
import '../permissions/check_in_permission.dart';

class EmployeeSession {
  const EmployeeSession({
    required this.employeeId,
    required this.tenantId,
    required this.email,
    required this.accessToken,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.timeZone,
    required this.permissions,
    this.enabledActionIds,
    this.avatar,
    this.companyName,
    this.companyId,
    this.department,
    this.managerId,
    this.profilePolicyId,
  });

  final String employeeId;
  final String tenantId;
  final String email;
  final String accessToken;
  final String firstName;
  final String lastName;
  final String role;
  final String timeZone;
  final Map<String, Map<String, bool>> permissions;

  /// Sparse catalog action ids from `/permissions/me/detailed` (enabled-only).
  final List<String>? enabledActionIds;
  final String? avatar;
  final String? companyName;
  final String? companyId;
  final String? department;
  final String? managerId;
  final String? profilePolicyId;

  String get displayName =>
      [firstName, lastName].where((s) => s.isNotEmpty).join(' ').trim();

  bool canReadModule(String permissionKey) =>
      PermissionCodec.canRead(permissions, permissionKey);

  /// `add` / `edit` / `delete` on a module, e.g. `can('my-leaves', 'add')`.
  bool can(String permissionKey, String action) =>
      PermissionCodec.can(permissions, permissionKey, action);

  /// Mobile punch — gated by `mobile-check-in` / `actions.mobile.check-in`.
  bool get canRemoteCheckIn => evaluateCanMobileCheckIn(
        permissions: permissions,
        enabledActionIds: enabledActionIds,
      );

  /// Mobile app access — gated by `mobile-access` / `actions.mobile.access`.
  bool get canMobileAccess => evaluateCanMobileAccess(
        permissions: permissions,
        enabledActionIds: enabledActionIds,
      );

  /// Own attendance report — `my-attendance` on web, or anyone who can check in.
  bool get canViewMyAttendance =>
      canReadModule('my-attendance') || canRemoteCheckIn;

  EmployeeSession copyWith({
    String? employeeId,
    String? tenantId,
    String? email,
    String? accessToken,
    String? firstName,
    String? lastName,
    String? role,
    String? timeZone,
    Map<String, Map<String, bool>>? permissions,
    List<String>? enabledActionIds,
    String? avatar,
    String? companyName,
    String? companyId,
    String? department,
    String? managerId,
    String? profilePolicyId,
  }) {
    return EmployeeSession(
      employeeId: employeeId ?? this.employeeId,
      tenantId: tenantId ?? this.tenantId,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      timeZone: timeZone ?? this.timeZone,
      permissions: permissions ?? this.permissions,
      enabledActionIds: enabledActionIds ?? this.enabledActionIds,
      avatar: avatar ?? this.avatar,
      companyName: companyName ?? this.companyName,
      companyId: companyId ?? this.companyId,
      department: department ?? this.department,
      managerId: managerId ?? this.managerId,
      profilePolicyId: profilePolicyId ?? this.profilePolicyId,
    );
  }

  factory EmployeeSession.fromJson(Map<String, dynamic> json) {
    final perms = PermissionCodec.decompress(json['permissions']);
    List<String>? actionIds;
    final rawIds = json['enabled_action_ids'] ?? json['enabledActionIds'];
    if (rawIds is List) {
      actionIds = rawIds.map((e) => '$e').toList();
    }
    return EmployeeSession(
      employeeId: '${json['employee_id'] ?? json['employeeId'] ?? ''}',
      tenantId: '${json['tenant_id'] ?? json['tenantId'] ?? ''}',
      email: '${json['email'] ?? ''}',
      accessToken: '${json['accessToken'] ?? json['token'] ?? ''}',
      firstName: '${json['first_name'] ?? json['firstName'] ?? ''}',
      lastName: '${json['last_name'] ?? json['lastName'] ?? ''}',
      role: '${json['role'] ?? ''}',
      timeZone: '${json['timeZone'] ?? json['time_zone'] ?? 'UTC'}',
      permissions: perms,
      enabledActionIds: actionIds,
      avatar: json['avatar']?.toString(),
      companyName: json['companyName']?.toString(),
      companyId: json['company_id']?.toString(),
      department: json['department']?.toString(),
      managerId: json['manager_id']?.toString(),
      profilePolicyId: json['profile_policy_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'employee_id': employeeId,
        'tenant_id': tenantId,
        'email': email,
        'accessToken': accessToken,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'timeZone': timeZone,
        'permissions': permissions,
        if (enabledActionIds != null) 'enabled_action_ids': enabledActionIds,
        'avatar': avatar,
        'companyName': companyName,
        'company_id': companyId,
        'department': department,
        'manager_id': managerId,
        'profile_policy_id': profilePolicyId,
      };
}

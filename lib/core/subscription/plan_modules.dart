/// Modules the company's HR360 plan includes, from `/api/v2/mobile/entitlements`
/// (same rules as the web app). Legacy companies, and failures to load, allow
/// everything — the server still refuses what the plan doesn't include.
class PlanModules {
  const PlanModules({
    required this.legacyUnrestricted,
    required this.enabled,
    this.subscriptionStatus,
  });

  /// Used when the plan can't be read (offline, older server): nothing is hidden.
  const PlanModules.unrestricted()
      : legacyUnrestricted = true,
        enabled = const {},
        subscriptionStatus = null;

  final bool legacyUnrestricted;
  final Set<String> enabled;
  final String? subscriptionStatus;

  factory PlanModules.fromJson(Object? json) {
    if (json is! Map) return const PlanModules.unrestricted();
    final modules = json['modules'];
    final enabled = <String>{};
    if (modules is Map) {
      modules.forEach((key, value) {
        if (value is Map && value['enabled'] == true) enabled.add('$key');
      });
    }
    return PlanModules(
      legacyUnrestricted: json['legacyUnrestricted'] == true,
      enabled: enabled,
      subscriptionStatus: json['subscriptionStatus'] as String?,
    );
  }

  /// Whether [module] (attendance, leave, tasks, training, payroll…) is in the plan.
  bool has(String module) =>
      legacyUnrestricted || enabled.contains('full_hr360') || enabled.contains(module);
}

/// Module keys used by HR360 Go screens.
class PlanModuleKeys {
  static const attendance = 'attendance';
  static const leave = 'leave';
  static const tasks = 'tasks';
  static const training = 'training';
  static const payroll = 'payroll';
  static const performance = 'performance';
}

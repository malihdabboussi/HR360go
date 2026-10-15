import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'not_in_plan_view.dart';
import 'plan_modules.dart';

/// Shows [child] only when [module] is in the company's plan.
class PlanGate extends ConsumerWidget {
  const PlanGate({
    super.key,
    required this.module,
    required this.featureName,
    required this.child,
  });

  final String module;
  final String featureName;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planModulesProvider);
    if (plan.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final modules = plan.valueOrNull ?? const PlanModules.unrestricted();
    if (modules.has(module)) return child;
    return Scaffold(
      appBar: AppBar(),
      body: NotInPlanView(featureName: featureName),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/employee/presentation/leaves_screen.dart';
import '../features/employee/presentation/payroll_screen.dart';
import '../features/employee/presentation/profile_screen.dart';
import '../features/employee/presentation/tasks_screen.dart';
import '../features/employee/presentation/training_screen.dart';
import '../core/subscription/plan_gate.dart';
import '../core/subscription/plan_modules.dart';
import 'authenticated_scope.dart';
import 'main_shell.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final session = await ref.read(authRepositoryProvider).currentSession();
      final loggingIn = state.matchedLocation == '/';
      if (session == null && !loggingIn) return '/';
      if (session != null && loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/home',
        builder: (_, __) => const AuthenticatedScope(child: MainShell()),
      ),
      GoRoute(
        path: '/workspace/profile',
        builder: (_, __) =>
            const AuthenticatedScope(child: ProfileScreen()),
      ),
      GoRoute(
        path: '/workspace/leaves',
        builder: (_, __) => const AuthenticatedScope(child: PlanGate(module: PlanModuleKeys.leave, featureName: 'Leaves', child: LeavesScreen())),
      ),
      GoRoute(
        path: '/workspace/tasks',
        builder: (_, __) => const AuthenticatedScope(child: PlanGate(module: PlanModuleKeys.tasks, featureName: 'Tasks', child: TasksScreen())),
      ),
      GoRoute(
        path: '/workspace/training',
        builder: (_, __) =>
            const AuthenticatedScope(child: PlanGate(module: PlanModuleKeys.training, featureName: 'Training', child: TrainingScreen())),
      ),
      GoRoute(
        path: '/workspace/payroll',
        builder: (_, __) => const AuthenticatedScope(child: PlanGate(module: PlanModuleKeys.payroll, featureName: 'Payroll', child: PayrollScreen())),
      ),
    ],
  );
});

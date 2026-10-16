import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../app/theme_mode_provider.dart';
import '../../../core/layout/shell_layout.dart';
import '../../../core/permissions/mobile_permission_map.dart';
import '../../../core/subscription/plan_modules.dart';

class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    // Role permissions decide what a person may open; the company plan decides
    // which modules exist at all.
    final plan = ref.watch(planModulesProvider).valueOrNull ??
        const PlanModules.unrestricted();

    final items = <_NavItem>[
      if (session.canReadModule(MobilePermissionMap.profile))
        _NavItem('Profile', Icons.person, '/workspace/profile'),
      if (session.canViewMyAttendance && plan.has(PlanModuleKeys.attendance))
        _NavItem('My time', Icons.schedule, '/home'),
      if (session.canReadModule(MobilePermissionMap.leaves) && plan.has(PlanModuleKeys.leave))
        _NavItem('Leaves', Icons.beach_access, '/workspace/leaves'),
      if (session.canReadModule(MobilePermissionMap.tasks) && plan.has(PlanModuleKeys.tasks))
        _NavItem('Tasks', Icons.task_alt, '/workspace/tasks'),
      if (session.canReadModule(MobilePermissionMap.training) && plan.has(PlanModuleKeys.training))
        _NavItem('Training', Icons.school, '/workspace/training'),
      if ((session.canReadModule(MobilePermissionMap.salaryHistory) ||
              session.canReadModule(MobilePermissionMap.expenses)) &&
          plan.has(PlanModuleKeys.payroll))
        _NavItem('Payroll', Icons.payments, '/workspace/payroll'),
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        ShellLayout.scrollBottomPadding(context),
      ),
      children: [
        Text('My workspace', style: Theme.of(context).textTheme.headlineSmall),
        Text(session.companyName ?? session.displayName),
        const SizedBox(height: 12),
        _ThemeModeTile(
          current: ref.watch(themeModeProvider),
          onChanged: (mode) =>
              ref.read(themeModeProvider.notifier).state = mode,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nothing else is available for your role yet. Contact HR if you need access.'),
          ),
        ...items.map(
          (item) => Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(item.route),
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authRepositoryProvider).logout();
            ref.invalidate(sessionProvider);
            if (context.mounted) context.go('/');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.current,
    required this.onChanged,
  });

  final ThemeMode? current;
  final ValueChanged<ThemeMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effective = current ?? ThemeMode.system;
    final label = switch (effective) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    return Card(
      child: ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('Appearance'),
        subtitle: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final next = switch (effective) {
            ThemeMode.system => ThemeMode.light,
            ThemeMode.light => ThemeMode.dark,
            ThemeMode.dark => null,
          };
          onChanged(next);
        },
      ),
    );
  }
}

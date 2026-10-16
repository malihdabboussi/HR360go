import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../features/attendance/presentation/attendance_home_screen.dart';
import '../features/attendance/presentation/my_time_screen.dart';
import '../features/employee/presentation/workspace_screen.dart';
import '../core/subscription/plan_modules.dart';
import 'providers.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planModulesProvider);
    if (plan.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final modules = plan.valueOrNull ?? const PlanModules.unrestricted();
    // Check-in and My time are the Attendance module. Workspace (profile, leaves,
    // tasks, training, payroll) is always there; it lists only what the plan and
    // the role allow. Without Attendance the app opens on Workspace.
    final hasAttendance = modules.has(PlanModuleKeys.attendance);
    final tabs = <Widget>[
      if (hasAttendance) const AttendanceHomeScreen(),
      if (hasAttendance) const MyTimeScreen(),
      const SafeArea(bottom: false, child: WorkspaceScreen()),
    ];
    final destinations = <NavigationDestination>[
      if (hasAttendance)
        const NavigationDestination(
          icon: Icon(Icons.fingerprint_outlined, size: 22),
          selectedIcon: Icon(Icons.fingerprint, size: 22),
          label: 'Check-in',
        ),
      if (hasAttendance)
        const NavigationDestination(
          icon: Icon(Icons.schedule_outlined, size: 22),
          selectedIcon: Icon(Icons.schedule, size: 22),
          label: 'My time',
        ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined, size: 22),
        selectedIcon: Icon(Icons.grid_view, size: 22),
        label: 'Workspace',
      ),
    ];

    if (_index >= tabs.length) {
      _index = 0;
    }
    if (tabs.length == 1) {
      return Scaffold(body: tabs.first);
    }

    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: false,
      body: tabs[_index],
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 8 + bottom),
        child: DecoratedBox(
          decoration: AppDecorations.floatingNav(context),
          child: NavigationBar(
            height: 56,
            elevation: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            indicatorColor: AppColors.primary.withValues(alpha: 0.18),
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: destinations,
          ),
        ),
      ),
    );
  }
}

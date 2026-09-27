import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_decorations.dart';
import '../features/attendance/presentation/attendance_home_screen.dart';
import '../features/attendance/presentation/my_time_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    AttendanceHomeScreen(),
    MyTimeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (_index >= _tabs.length) {
      _index = 0;
    }

    return Scaffold(
      extendBody: false,
      body: _tabs[_index],
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
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.fingerprint_outlined, size: 22),
                selectedIcon: Icon(Icons.fingerprint, size: 22),
                label: 'Check-in',
              ),
              NavigationDestination(
                icon: Icon(Icons.schedule_outlined, size: 22),
                selectedIcon: Icon(Icons.schedule, size: 22),
                label: 'My time',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../core/permissions/mobile_permission_map.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  List<dynamic> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.tasks)) {
      setState(() => _loading = false);
      return;
    }
    final tasks = await ref.read(employeeRepositoryProvider).getMyTasks();
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.tasks)) {
      return const Center(child: Text('Tasks access denied'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final t = _tasks[index] as Map? ?? {};
          return Card(
            child: ListTile(
              title: Text('${t['title'] ?? t['name'] ?? 'Task'}'),
              subtitle: Text('${t['status'] ?? ''}'),
            ),
          );
        },
      ),
    );
  }
}

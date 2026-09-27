import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../core/permissions/mobile_permission_map.dart';

class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key});

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  List<dynamic> _trainings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.training)) {
      setState(() => _loading = false);
      return;
    }
    final data = await ref.read(employeeRepositoryProvider).getMyTrainings();
    if (mounted) {
      setState(() {
        _trainings = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.training)) {
      return const Center(child: Text('Training access denied'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trainings.length,
        itemBuilder: (context, index) {
          final t = _trainings[index] as Map? ?? {};
          return Card(
            child: ListTile(
              title: Text('${t['training_name'] ?? t['name'] ?? 'Training'}'),
              subtitle: Text('${t['status'] ?? ''}'),
            ),
          );
        },
      ),
    );
  }
}

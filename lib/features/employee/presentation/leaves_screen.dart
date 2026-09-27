import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../core/permissions/mobile_permission_map.dart';

class LeavesScreen extends ConsumerStatefulWidget {
  const LeavesScreen({super.key});

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends ConsumerState<LeavesScreen> {
  List<dynamic> _requests = [];
  dynamic _balance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.leaves)) {
      setState(() => _loading = false);
      return;
    }
    final repo = ref.read(employeeRepositoryProvider);
    final requests = await repo.getMyLeaveRequests();
    final balance = await repo.getMyLeaveBalance();
    if (mounted) {
      setState(() {
        _requests = requests;
        _balance = balance;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.leaves)) {
      return const Center(child: Text('Leaves access denied'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_balance != null)
            Card(child: ListTile(title: const Text('Balance'), subtitle: Text('$_balance'))),
          const Text('My requests', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._requests.map((r) {
            final map = r is Map ? r : <String, dynamic>{'data': r};
            return Card(
              child: ListTile(
                title: Text('${map['leave_type'] ?? map['type'] ?? 'Leave'}'),
                subtitle: Text('${map['status'] ?? ''} • ${map['start_date'] ?? ''}'),
              ),
            );
          }),
        ],
      ),
    );
  }
}

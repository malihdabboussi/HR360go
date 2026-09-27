import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../core/permissions/mobile_permission_map.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  dynamic _payroll;
  List<dynamic> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(currentSessionProvider);
    final repo = ref.read(employeeRepositoryProvider);
    dynamic payroll;
    List<dynamic> expenses = [];

    if (session.canReadModule(MobilePermissionMap.salaryHistory)) {
      payroll = await repo.getMyPayroll();
    }
    if (session.canReadModule(MobilePermissionMap.expenses)) {
      expenses = await repo.getMyExpenses();
    }

    if (mounted) {
      setState(() {
        _payroll = payroll;
        _expenses = expenses;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final allowed = session.canReadModule(MobilePermissionMap.salaryHistory) ||
        session.canReadModule(MobilePermissionMap.expenses);
    if (!allowed) {
      return const Center(child: Text('Payroll access denied'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_payroll != null)
            Card(
              child: ListTile(
                title: const Text('Payroll'),
                subtitle: Text('$_payroll'),
              ),
            ),
          const Text('Payment requests', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._expenses.map(
            (e) => Card(
              child: ListTile(
                title: Text('${(e as Map?)?['type'] ?? 'Expense'}'),
                subtitle: Text('${(e as Map?)?['status'] ?? ''}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

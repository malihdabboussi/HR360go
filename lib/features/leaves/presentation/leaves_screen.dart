import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../core/permissions/mobile_permission_map.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/leave_models.dart';
import 'leave_request_form_screen.dart';

/// Workspace → Leaves: balances, own requests (status, details, cancel pending),
/// and "Request leave". Permission `my-leaves` read / add / delete, like the web.
class LeavesScreen extends ConsumerStatefulWidget {
  const LeavesScreen({super.key});

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

enum _Filter { all, pending, approved, rejected }

class _LeavesScreenState extends ConsumerState<LeavesScreen> {
  List<LeaveBalance> _balances = [];
  List<LeaveRequestItem> _requests = [];
  bool _loading = true;
  String? _error;
  _Filter _filter = _Filter.all;

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
    setState(() => _error = null);
    final repo = ref.read(leaveRepositoryProvider);
    try {
      final results = await Future.wait([repo.getBalances(), repo.getMyRequests()]);
      if (!mounted) return;
      setState(() {
        _balances = results[0] as List<LeaveBalance>;
        _requests = results[1] as List<LeaveRequestItem>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your leaves. Pull down to try again.';
      });
    }
  }

  Future<void> _openForm() async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const LeaveRequestFormScreen(),
      ),
    );
    if (sent == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request sent for approval')),
        );
      }
      await _load();
    }
  }

  Future<void> _cancel(LeaveRequestItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text('${item.leaveType} · ${item.whenLabel}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(leaveRepositoryProvider).cancel(item.id);
      messenger.showSnackBar(const SnackBar(content: Text('Request cancelled')));
      await _load();
    } on DioException catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not cancel the request. Try again.')));
    }
  }

  void _showDetails(LeaveRequestItem item, {required bool canCancel}) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.leaveType, style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  _StatusChip(item: item),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(icon: Icons.event, text: item.whenLabel),
              _DetailRow(icon: Icons.timelapse, text: item.durationType.label),
              if (item.reason.isNotEmpty) _DetailRow(icon: Icons.notes, text: item.reason),
              if (item.createdAt != null)
                _DetailRow(icon: Icons.send, text: 'Requested on ${formatDay(item.createdAt!.toLocal())}'),
              if (item.isPending) ...[
                const SizedBox(height: 4),
                _DetailRow(
                  icon: Icons.how_to_reg_outlined,
                  text: item.approvedByManager == true
                      ? 'Approved by your manager, waiting for HR'
                      : 'Waiting for approval',
                ),
              ],
              if (canCancel && item.isPending) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _cancel(item);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel request'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<LeaveRequestItem> get _filtered {
    switch (_filter) {
      case _Filter.all:
        return _requests;
      case _Filter.pending:
        return _requests.where((r) => r.status == LeaveStatus.pending).toList();
      case _Filter.approved:
        return _requests.where((r) => r.status == LeaveStatus.approved).toList();
      case _Filter.rejected:
        return _requests.where((r) => r.status == LeaveStatus.rejected).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    final canRead = session.canReadModule(MobilePermissionMap.leaves);
    final canAdd = session.can(MobilePermissionMap.leaves, 'add');
    final canCancel = session.can(MobilePermissionMap.leaves, 'delete');

    return Scaffold(
      appBar: AppBar(title: const Text('Leaves')),
      floatingActionButton: canRead && canAdd
          ? FloatingActionButton.extended(
              onPressed: _openForm,
              icon: const Icon(Icons.add),
              label: const Text('Request leave'),
            )
          : null,
      body: !canRead
          ? const Center(child: Text('You do not have access to leaves.'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
                        ),
                      Text('Balance', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_balances.isEmpty)
                        const Text('No leave types are assigned to you yet.')
                      else
                        SizedBox(
                          height: 118,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _balances.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => _BalanceCard(balance: _balances[i]),
                          ),
                        ),
                      const SizedBox(height: 20),
                      Text('My requests', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in _Filter.values)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(end: 8),
                                child: ChoiceChip(
                                  label: Text(switch (f) {
                                    _Filter.all => 'All',
                                    _Filter.pending => 'Pending',
                                    _Filter.approved => 'Approved',
                                    _Filter.rejected => 'Rejected',
                                  }),
                                  selected: _filter == f,
                                  onSelected: (_) => setState(() => _filter = f),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No requests')),
                        )
                      else
                        for (final item in _filtered)
                          Card(
                            child: ListTile(
                              onTap: () => _showDetails(item, canCancel: canCancel),
                              title: Text(item.leaveType),
                              subtitle: Text(item.whenLabel),
                              trailing: _StatusChip(item: item),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final LeaveBalance balance;

  @override
  Widget build(BuildContext context) {
    final total = balance.total;
    final progress = total > 0 ? (balance.remaining / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(balance.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(formatDays(balance.remaining),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
          Text('left of ${formatDays(total)}', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 5),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});

  final LeaveRequestItem item;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.status) {
      LeaveStatus.approved => Colors.green,
      LeaveStatus.rejected => AppColors.danger,
      LeaveStatus.pending => Colors.orange,
      LeaveStatus.other => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(item.statusLabel,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).hintColor),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

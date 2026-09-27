import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/authenticated_scope.dart';
import '../../../app/providers.dart';
import '../../../core/permissions/mobile_permission_map.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.profile)) {
      setState(() => _loading = false);
      return;
    }
    final data = await ref
        .read(employeeRepositoryProvider)
        .getProfile(session.employeeId);
    if (mounted) {
      setState(() {
        _profile = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider);
    if (!session.canReadModule(MobilePermissionMap.profile)) {
      return const Center(child: Text('Profile access denied'));
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: Text(session.displayName),
          subtitle: Text(session.email),
        ),
        if (_profile != null)
          ..._profile!.entries.map(
            (e) => ListTile(
              title: Text(e.key),
              subtitle: Text('${e.value}'),
            ),
          ),
      ],
    );
  }
}

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/authenticated_scope.dart';
import 'app/hr360_go_app.dart';
import 'app/providers.dart';
import 'features/attendance/data/local_attendance_session_store.dart';
import 'features/attendance/data/pending_punch_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();

  final pendingPunchStore = PendingPunchStore();
  await pendingPunchStore.init();

  final localSessionStore = LocalAttendanceSessionStore();
  await localSessionStore.init();

  runApp(
    ProviderScope(
      overrides: [
        pendingPunchStoreProvider.overrideWithValue(pendingPunchStore),
        localAttendanceSessionStoreProvider.overrideWithValue(localSessionStore),
      ],
      child: const _Hr360GoBootstrap(),
    ),
  );
}

class _Hr360GoBootstrap extends ConsumerStatefulWidget {
  const _Hr360GoBootstrap();

  @override
  ConsumerState<_Hr360GoBootstrap> createState() => _Hr360GoBootstrapState();
}

class _Hr360GoBootstrapState extends ConsumerState<_Hr360GoBootstrap> {
  @override
  void initState() {
    super.initState();
    Connectivity().onConnectivityChanged.listen((_) async {
      try {
        final controller = ref.read(scopedAttendanceControllerProvider.notifier);
        await controller.onConnectivityRestored();
      } catch (_) {
        // Not logged in yet
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Hr360GoApp();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';
import 'theme_mode_provider.dart';

class Hr360GoApp extends ConsumerWidget {
  const Hr360GoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeOverride = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'HR360 Go',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeOverride ?? ThemeMode.system,
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

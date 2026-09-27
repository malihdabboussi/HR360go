import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this._strings);

  final Map<String, String> _strings;

  String t(String key, {String fallback = ''}) =>
      _strings[key] ?? fallback.ifEmpty(key);

  static const supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('fr'),
    Locale('zh'),
  ];

  static Future<AppLocalizations> load(Locale locale) async {
    final code = locale.languageCode;
    final path = 'assets/l10n/$code.json';
    try {
      final raw = await rootBundle.loadString(path);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final flat = <String, String>{};
      void walk(String prefix, Map<String, dynamic> node) {
        node.forEach((k, v) {
          final key = prefix.isEmpty ? k : '$prefix.$k';
          if (v is Map<String, dynamic>) {
            walk(key, v);
          } else {
            flat[key] = v.toString();
          }
        });
      }
      walk('', map);
      return AppLocalizations(flat);
    } catch (_) {
      return AppLocalizations({});
    }
  }
}

class AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      AppLocalizations.load(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

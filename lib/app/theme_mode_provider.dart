import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Override system theme: null = follow OS (light + dark both supported).
final themeModeProvider = StateProvider<ThemeMode?>((ref) => null);

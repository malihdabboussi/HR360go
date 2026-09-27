import 'package:flutter/material.dart';

/// HR360 brand and semantic colors — see docs/design-tokens.md.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFF01C3FF);
  static const Color secondary = Color(0xFFFF7132);
  static const Color darkBlue = Color(0xFF0077FF);
  static const Color navy = Color(0xFF00004F);

  // Semantic
  static const Color danger = Color(0xFFFF3D33);
  static const Color gold = Color(0xFFFFCC17);

  // Light
  static const Color lightBackground = Color(0xFFF4F4F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color label = Color(0xFF1E293B);
  static const Color lightMuted = Color(0xFF9A9A9A);
  static const Color lightBorder = Color(0xFFEAEAEA);

  // Dark
  static const Color darkBackground = Color(0xFF0D1621);
  static const Color darkSurface = Color(0xFF162633);
  static const Color darkBorder = Color(0xFF263B4D);

  // On-brand text on filled buttons
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
}

import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Premium surfaces — soft glass, minimal borders.
abstract final class AppDecorations {
  static const double premiumRadius = 16;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color muted(BuildContext context) =>
      isDark(context) ? AppColors.lightMuted : const Color(0xFF64748B);

  static Color surface(BuildContext context) =>
      isDark(context) ? AppColors.darkSurface : AppColors.lightSurface;

  static BoxDecoration glassCard(BuildContext context, {double? radius}) {
    final dark = isDark(context);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius ?? premiumRadius),
      color: surface(context).withValues(alpha: dark ? 0.72 : 0.95),
      border: Border.all(
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.lightBorder.withValues(alpha: 0.8),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.25 : 0.06),
          blurRadius: dark ? 16 : 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static Widget glass({
    required BuildContext context,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
    double? radius,
  }) {
    final r = radius ?? premiumRadius;
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: glassCard(context, radius: r),
          child: child,
        ),
      ),
    );
  }

  static BoxDecoration floatingNav(BuildContext context) {
    final dark = isDark(context);
    return BoxDecoration(
      color: surface(context),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.4 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// HR360 Material themes — Inter UI, brand check-in/out colors.
abstract final class AppTheme {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 16;
  static const double spaceLg = 24;

  static const double cardRadius = 16;
  static const double buttonRadius = 8;

  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ButtonStyle checkInButtonStyle() => FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm),
      );

  static ButtonStyle checkOutButtonStyle() => FilledButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.38),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceSm),
      );

  static TextStyle timerTextStyle(ThemeData theme) {
    final base = theme.textTheme.displaySmall ?? const TextStyle(fontSize: 36);
    return GoogleFonts.jetBrainsMono(
      textStyle: base.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final background =
        isLight ? AppColors.lightBackground : AppColors.darkBackground;
    final surface = isLight ? AppColors.lightSurface : AppColors.darkSurface;
    final border = isLight ? AppColors.lightBorder : AppColors.darkBorder;
    final onSurface = isLight ? AppColors.label : Colors.white;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      error: AppColors.danger,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
    );

    final baseInter = GoogleFonts.interTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    final inter = baseInter.copyWith(
      bodyLarge: baseInter.bodyLarge?.copyWith(fontSize: 17, height: 1.25),
      bodyMedium: baseInter.bodyMedium?.copyWith(fontSize: 16, height: 1.25),
      bodySmall: baseInter.bodySmall?.copyWith(fontSize: 14, height: 1.2),
      titleLarge: baseInter.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
      titleMedium: baseInter.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      titleSmall: baseInter.titleSmall?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      headlineSmall: baseInter.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      labelLarge: baseInter.labelLarge?.copyWith(fontSize: 15, height: 1.15),
      labelMedium: baseInter.labelMedium?.copyWith(fontSize: 14, height: 1.15),
      labelSmall: baseInter.labelSmall?.copyWith(fontSize: 12, height: 1.1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: inter,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return inter.labelMedium?.copyWith(
            color: selected ? AppColors.primary : AppColors.lightMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.lightMuted,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.lightSurface : AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.lightMuted),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? AppColors.label : AppColors.darkSurface,
        contentTextStyle: TextStyle(
          color: isLight ? Colors.white : Colors.white,
          fontSize: 15,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.primary),
        radius: const Radius.circular(6),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }
}

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'package:nudgee/app/theme/app_colors.dart';
import 'package:nudgee/app/theme/app_text_styles.dart';

/// Centralized theme configuration using FlexColorScheme.
///
/// Generates both light and dark [ThemeData] with consistent design tokens.
/// Font family is set to Inter via google_fonts.
class AppTheme {
  AppTheme._();

  /// Light theme.
  static final ThemeData light = FlexThemeData.light(
        scheme: FlexScheme.indigoM3,
        useMaterial3: true,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        appBarStyle: FlexAppBarStyle.surface,
        subThemesData: const FlexSubThemesData(
          interactionEffects: true,
          tintedDisabledControls: true,
          blendOnLevel: 8,
          blendOnColors: true,
          useM2StyleDividerInM3: true,
          outlinedButtonRadius: 12,
          filledButtonRadius: 12,
          elevatedButtonRadius: 12,
          textButtonRadius: 12,
          segmentedButtonRadius: 12,
          inputDecoratorRadius: 12,
          inputDecoratorUnfocusedBorderIsColored: false,
          inputDecoratorBorderSchemeColor: SchemeColor.primary,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          cardRadius: 12,
          chipRadius: 8,
          snackBarRadius: 8,
          snackBarElevation: 3,
          dialogRadius: 16,
          drawerRadius: 16,
          drawerIndicatorRadius: 10,
          bottomSheetRadius: 24,
          bottomSheetElevation: 4,
        ),
        keyColors: const FlexKeyColors(
          useSecondary: true,
          useTertiary: true,
          keepPrimary: true,
          keepSecondary: true,
          keepTertiary: true,
        ),
        visualDensity: VisualDensity.standard,
      ).copyWith(
        textTheme: _lightTextTheme,
        scaffoldBackgroundColor: AppColors.lightBackground,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          error: AppColors.error,
          surface: AppColors.lightSurface,
        ),
      );

  /// Dark theme.
  static final ThemeData dark = FlexThemeData.dark(
        scheme: FlexScheme.indigoM3,
        useMaterial3: true,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 10,
        appBarStyle: FlexAppBarStyle.surface,
        subThemesData: const FlexSubThemesData(
          interactionEffects: true,
          tintedDisabledControls: true,
          blendOnLevel: 12,
          blendOnColors: true,
          useM2StyleDividerInM3: true,
          outlinedButtonRadius: 12,
          filledButtonRadius: 12,
          elevatedButtonRadius: 12,
          textButtonRadius: 12,
          segmentedButtonRadius: 12,
          inputDecoratorRadius: 12,
          inputDecoratorUnfocusedBorderIsColored: false,
          inputDecoratorBorderSchemeColor: SchemeColor.primary,
          inputDecoratorBorderType: FlexInputBorderType.outline,
          cardRadius: 12,
          chipRadius: 8,
          snackBarRadius: 8,
          snackBarElevation: 3,
          dialogRadius: 16,
          drawerRadius: 16,
          drawerIndicatorRadius: 10,
          bottomSheetRadius: 24,
          bottomSheetElevation: 4,
        ),
        keyColors: const FlexKeyColors(
          useSecondary: true,
          useTertiary: true,
          keepPrimary: true,
          keepSecondary: true,
          keepTertiary: true,
        ),
        visualDensity: VisualDensity.standard,
      ).copyWith(
        textTheme: _darkTextTheme,
        scaffoldBackgroundColor: AppColors.darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryLight,
          secondary: AppColors.secondary,
          tertiary: AppColors.tertiary,
          error: AppColors.error,
          surface: AppColors.darkSurface,
        ),
      );

  // ── Text themes ──────────────────────────────────────────────────────

  static final TextTheme _lightTextTheme = TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.lightTextPrimary),
        displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.lightTextPrimary),
        headlineLarge: AppTextStyles.headlineLarge.copyWith(color: AppColors.lightTextPrimary),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(color: AppColors.lightTextPrimary),
        headlineSmall: AppTextStyles.headlineSmall.copyWith(color: AppColors.lightTextPrimary),
        titleLarge: AppTextStyles.headlineMedium.copyWith(color: AppColors.lightTextPrimary),
        titleMedium: AppTextStyles.labelLarge.copyWith(color: AppColors.lightTextPrimary),
        titleSmall: AppTextStyles.labelMedium.copyWith(color: AppColors.lightTextPrimary),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.lightTextPrimary),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.lightTextPrimary),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.lightTextSecondary),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.lightTextPrimary),
        labelMedium: AppTextStyles.labelMedium.copyWith(color: AppColors.lightTextSecondary),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.lightTextHint),
      );

  static final TextTheme _darkTextTheme = TextTheme(
        displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.darkTextPrimary),
        displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.darkTextPrimary),
        headlineLarge: AppTextStyles.headlineLarge.copyWith(color: AppColors.darkTextPrimary),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(color: AppColors.darkTextPrimary),
        headlineSmall: AppTextStyles.headlineSmall.copyWith(color: AppColors.darkTextPrimary),
        titleLarge: AppTextStyles.headlineMedium.copyWith(color: AppColors.darkTextPrimary),
        titleMedium: AppTextStyles.labelLarge.copyWith(color: AppColors.darkTextPrimary),
        titleSmall: AppTextStyles.labelMedium.copyWith(color: AppColors.darkTextPrimary),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.darkTextPrimary),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.darkTextPrimary),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.darkTextSecondary),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.darkTextPrimary),
        labelMedium: AppTextStyles.labelMedium.copyWith(color: AppColors.darkTextSecondary),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.darkTextHint),
      );
}

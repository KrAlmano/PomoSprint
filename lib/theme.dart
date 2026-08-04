import 'package:flutter/material.dart';

class AppColors {
  // Light Primary Palette
  static const primary = Color(0xFFB4261F);
  static const primaryContainer = Color(0xFFFF5C4D);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFF610002);
  static const primaryFixed = Color(0xFFFFDAD5);
  static const onPrimaryFixed = Color(0xFF410001);
  static const primaryFixedDim = Color(0xFFFFB4AA);

  // Secondary Palette
  static const secondary = Color(0xFF586062);
  static const secondaryContainer = Color(0xFFDAE1E3);
  static const onSecondaryContainer = Color(0xFF5D6466);
  static const secondaryFixed = Color(0xFFDDE4E6);
  static const onSecondaryFixed = Color(0xFF161D1F);

  // Tertiary Palette
  static const tertiary = Color(0xFF0055D4);
  static const tertiaryContainer = Color(0xFF638FFF);
  static const onTertiaryContainer = Color(0xFF00286C);
  static const tertiaryFixed = Color(0xFFDAE2FF);
  static const onTertiaryFixed = Color(0xFF001849);

  // Surfaces & Backgrounds
  static const surface = Color(0xFFF8F9FB);
  static const surfaceBright = Color(0xFFF8F9FB);
  static const surfaceDim = Color(0xFFD9DADC);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F4F6);
  static const surfaceContainer = Color(0xFFEDEEF0);
  static const surfaceContainerHigh = Color(0xFFE7E8EA);
  static const surfaceContainerHighest = Color(0xFFE1E2E4);

  // Text & Outlines
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF5A403D);
  static const outline = Color(0xFF8E706C);
  static const outlineVariant = Color(0xFFE2BEB9);

  // Custom Accents
  static const sand = Color(0xFFFF5C4D);
  static const frame = Color(0xFFFF5C4D);
  static const glassStroke = Color(0xFFE2BEB9);
  static const glassFill = Color(0x0D000000);

  // Dark Theme Palette (near-black with a warm bordo/maroon undertone,
  // matching the brand's red primary instead of a mismatched purple/orange).
  static const darkSurface = Color(0xFF130D0D);
  static const darkSurfaceBright = Color(0xFF2E2020);
  static const darkSurfaceDim = Color(0xFF0D0909);
  static const darkSurfaceContainerLowest = Color(0xFF0A0707);
  static const darkSurfaceContainerLow = Color(0xFF1B1414);
  static const darkSurfaceContainer = Color(0xFF221919);
  static const darkSurfaceContainerHigh = Color(0xFF2D2121);
  static const darkSurfaceContainerHighest = Color(0xFF382B2A);
  static const darkOnSurface = Color(0xFFF3E5E2);
  static const darkOnSurfaceVariant = Color(0xFFD9B9B4);
  static const darkOutline = Color(0xFF8F706C);
  static const darkOutlineVariant = Color(0xFF4A3634);
  static const darkPrimary = Color(0xFFFF7A68);
  static const darkPrimaryContainer = Color(0xFF7D2A22);
  static const darkOnPrimaryContainer = Color(0xFFFFDAD5);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
      ),
      fontFamily: 'Plus Jakarta Sans',
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkSurface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        primaryContainer: AppColors.darkPrimaryContainer,
        onPrimaryContainer: AppColors.darkOnPrimaryContainer,
        secondary: AppColors.secondary,
        tertiary: AppColors.tertiary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkOnSurface,
        onSurfaceVariant: AppColors.darkOnSurfaceVariant,
        outline: AppColors.darkOutline,
        outlineVariant: AppColors.darkOutlineVariant,
      ),
      fontFamily: 'Plus Jakarta Sans',
    );
  }
}

import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_colors.dart';
import 'package:surplus_marketplace/app/theme/app_typography.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Assembles the light and dark [ThemeData].
///
/// `ColorScheme` alone cannot express `feedback.*`, `financial.*`, or the
/// urgency scale, so the semantic tokens live in [ThemeExtension]s and
/// `ColorScheme` is populated only to keep Material's own widgets coherent
/// (§6.8).
abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light());

  static ThemeData dark() => _build(AppColors.dark());

  static ThemeData _build(AppColors colors) {
    final type = AppTypography.standard();
    final isDark = colors.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.surfaceBase,
      extensions: <ThemeExtension<dynamic>>[colors, type],

      // Populated so Material's built-in widgets inherit sensible colours. The
      // application's own components read from AppColors, never from here.
      colorScheme: ColorScheme(
        brightness: colors.brightness,
        primary: colors.actionPrimaryBg,
        onPrimary: colors.actionPrimaryFg,
        secondary: colors.actionSecondaryFg,
        onSecondary: colors.surfaceBase,
        error: colors.critical.fg,
        onError: isDark ? colors.textPrimary : colors.surfaceBase,
        surface: colors.surfaceRaised,
        onSurface: colors.textPrimary,
      ),

      textTheme:
          TextTheme(
            displaySmall: type.display,
            headlineMedium: type.headline,
            titleLarge: type.title,
            titleMedium: type.titleSmall,
            bodyLarge: type.bodyLarge,
            bodyMedium: type.body,
            bodySmall: type.caption,
            labelLarge: type.label,
          ).apply(
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          ),

      // Material's default 36 dp is below our floor.
      materialTapTargetSize: MaterialTapTargetSize.padded,

      dividerTheme: DividerThemeData(
        color: colors.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceOverlay,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.sheet),
          ),
        ),
        // §5b.4 — sheets must scroll rather than clip at high text scale.
        showDragHandle: true,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surfaceOverlay,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.lg)),
        ),
      ),
    );
  }
}

/// Ergonomic access to the semantic token sets.
///
/// `context.colors.action.primary` and `context.type.body` — feature code never
/// touches `Theme.of(context).extension<…>()` directly, and never touches
/// Layer 1 primitives at all (§6.1).
extension AppThemeContext on BuildContext {
  /// Semantic colour tokens for the active theme.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;

  /// Semantic type tokens.
  AppTypography get type => Theme.of(this).extension<AppTypography>()!;

  /// Active brightness — needed by the A22 dietary-mark chip rule and by
  /// [Elevation]'s shadow/surface split.
  Brightness get brightness => Theme.of(this).brightness;
}

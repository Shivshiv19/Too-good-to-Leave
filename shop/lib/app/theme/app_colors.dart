import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/tokens/primitives.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';

/// Tone for money-in-motion states (§6.2.7).
///
/// Separate from the general feedback roles because **pending money is not a
/// warning** — it is informational. A user watching a refund travel to their
/// bank should not be looking at an amber alert.
enum FinancialTone {
  /// Payment pending, verification in flight, refund processing.
  pending,

  /// Payment failed, refund failed.
  failed,

  /// Captured, refunded, collected.
  settled,
}

/// A feedback role's three colours.
final class FeedbackPalette {
  const FeedbackPalette({
    required this.fg,
    required this.bg,
    required this.border,
  });

  /// Text and icon colour.
  final Color fg;

  /// Container fill.
  final Color bg;

  /// Container outline.
  final Color border;

  static FeedbackPalette lerp(
    FeedbackPalette a,
    FeedbackPalette b,
    double t,
  ) => FeedbackPalette(
    fg: Color.lerp(a.fg, b.fg, t)!,
    bg: Color.lerp(a.bg, b.bg, t)!,
    border: Color.lerp(a.border, b.border, t)!,
  );
}

/// # LAYER 2 — Semantic colour tokens
///
/// The only colour surface feature code may touch. Access via
/// `context.colors` (see `app_theme.dart`).
///
/// Light and dark are **two complete token sets**, not one set with runtime
/// derivations (§6.8). Derived dark themes are how you ship an unreadable dark
/// mode.
@immutable
final class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.surfaceBase,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.surfaceOverlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAction,
    required this.borderSubtle,
    required this.borderStrong,
    required this.actionPrimaryBg,
    required this.actionPrimaryFg,
    required this.actionSecondaryFg,
    required this.actionSecondaryBorder,
    required this.actionDestructiveBg,
    required this.actionDestructiveFg,
    required this.scrim,
    required this.success,
    required this.critical,
    required this.info,
    required this.attention,
  });

  /// Light theme token set.
  factory AppColors.light() => const AppColors(
    brightness: Brightness.light,
    surfaceBase: Cream.c100,
    surfaceRaised: Neutral.c0,
    surfaceSunken: Cream.c200,
    surfaceOverlay: Neutral.c0,
    textPrimary: Neutral.c900,
    textSecondary: Neutral.c600,
    textTertiary: Neutral.c500,

    // `Green.c700`'s a dark fill, so the label goes light rather than dark —
    // the inverse of the old ember palette's near-black-on-vivid-orange
    // choice, which was tuned for a *light* vibrant fill (§6.2.3's original
    // reasoning doesn't transfer; re-verify contrast if the fill shade
    // changes again).
    textOnAction: Cream.c100,
    borderSubtle: Neutral.c200,
    borderStrong: Neutral.c300,
    actionPrimaryBg: Green.c700,
    actionPrimaryFg: Cream.c100,
    actionSecondaryFg: Green.c700,
    actionSecondaryBorder: Green.c700,
    actionDestructiveBg: FeedbackHues.criticalLight,
    actionDestructiveFg: Neutral.c0,
    scrim: Color(0x991A1614),
    success: FeedbackPalette(
      fg: FeedbackHues.successLight,
      bg: FeedbackHues.successBgLight,
      border: FeedbackHues.successLight,
    ),
    critical: FeedbackPalette(
      fg: FeedbackHues.criticalLight,
      bg: FeedbackHues.criticalBgLight,
      border: FeedbackHues.criticalLight,
    ),
    info: FeedbackPalette(
      fg: FeedbackHues.infoLight,
      bg: FeedbackHues.infoBgLight,
      border: FeedbackHues.infoLight,
    ),
    attention: FeedbackPalette(
      fg: FeedbackHues.attentionLight,
      bg: FeedbackHues.attentionBgLight,
      border: FeedbackHues.attentionLight,
    ),
  );

  /// Dark theme token set.
  factory AppColors.dark() => const AppColors(
    brightness: Brightness.dark,
    surfaceBase: DarkSurface.base,
    surfaceRaised: DarkSurface.raised,
    surfaceSunken: DarkSurface.base,
    surfaceOverlay: DarkSurface.overlay,
    textPrimary: DarkSurface.textPrimary,
    textSecondary: DarkSurface.textSecondary,
    textTertiary: DarkSurface.textTertiary,
    textOnAction: Neutral.c900,
    borderSubtle: DarkSurface.borderSubtle,
    borderStrong: DarkSurface.borderStrong,

    // Lightened to the lime/olive accent tone in dark mode — a fully
    // saturated deep-green fill vibrates against an already-dark-green
    // surface, the same reasoning the old ember palette applied one step up
    // its own ramp.
    actionPrimaryBg: Green.c400,
    actionPrimaryFg: Neutral.c900,
    actionSecondaryFg: Green.c300,
    actionSecondaryBorder: Green.c300,
    actionDestructiveBg: FeedbackHues.criticalDark,
    actionDestructiveFg: Neutral.c900,
    scrim: Color(0xB30F0D0C),
    success: FeedbackPalette(
      fg: FeedbackHues.successDark,
      bg: FeedbackHues.successBgDark,
      border: FeedbackHues.successDark,
    ),
    critical: FeedbackPalette(
      fg: FeedbackHues.criticalDark,
      bg: FeedbackHues.criticalBgDark,
      border: FeedbackHues.criticalDark,
    ),
    info: FeedbackPalette(
      fg: FeedbackHues.infoDark,
      bg: FeedbackHues.infoBgDark,
      border: FeedbackHues.infoDark,
    ),
    attention: FeedbackPalette(
      fg: FeedbackHues.attentionDark,
      bg: FeedbackHues.attentionBgDark,
      border: FeedbackHues.attentionDark,
    ),
  );

  final Brightness brightness;

  final Color surfaceBase;
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color surfaceOverlay;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Label colour on a filled primary action. See §6.2.3.
  final Color textOnAction;

  final Color borderSubtle;
  final Color borderStrong;

  final Color actionPrimaryBg;
  final Color actionPrimaryFg;
  final Color actionSecondaryFg;
  final Color actionSecondaryBorder;
  final Color actionDestructiveBg;
  final Color actionDestructiveFg;

  final Color scrim;

  final FeedbackPalette success;
  final FeedbackPalette critical;
  final FeedbackPalette info;
  final FeedbackPalette attention;

  /// Foreground colour for a pickup window's urgency (§6.2.7).
  ///
  /// The urgency scale deliberately **avoids the brand hue**. An amber or
  /// orange "attention" tier would be indistinguishable from ember chrome, so
  /// urgency is expressed semantically rather than as a heat ramp:
  ///
  /// * `upcoming`     — neutral; there is nothing to act on yet
  /// * `openNow`      — **success**; this is *good* news, the bag is collectable
  /// * `closingSoon`  — **critical**; genuine urgency, real money at risk
  /// * `closed`       — de-emphasised; terminal
  ///
  /// Three unmistakable hues, none competing with the brand, and the mapping is
  /// truthful — "collect now" should not look like a warning.
  Color urgencyForeground(WindowUrgency urgency) => switch (urgency) {
    WindowUrgency.upcoming => textSecondary,
    WindowUrgency.openNow => success.fg,
    WindowUrgency.closingSoon => critical.fg,
    WindowUrgency.closed => textTertiary,
  };

  /// Palette for a money-in-motion state (§6.2.7).
  ///
  /// Aliases existing feedback roles rather than introducing duplicate tokens —
  /// one fewer thing to keep consistent across two themes.
  FeedbackPalette financialPalette(FinancialTone tone) => switch (tone) {
    FinancialTone.pending => info,
    FinancialTone.failed => critical,
    FinancialTone.settled => success,
  };

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? surfaceBase,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? surfaceOverlay,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnAction,
    Color? borderSubtle,
    Color? borderStrong,
    Color? actionPrimaryBg,
    Color? actionPrimaryFg,
    Color? actionSecondaryFg,
    Color? actionSecondaryBorder,
    Color? actionDestructiveBg,
    Color? actionDestructiveFg,
    Color? scrim,
    FeedbackPalette? success,
    FeedbackPalette? critical,
    FeedbackPalette? info,
    FeedbackPalette? attention,
  }) => AppColors(
    brightness: brightness ?? this.brightness,
    surfaceBase: surfaceBase ?? this.surfaceBase,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    surfaceSunken: surfaceSunken ?? this.surfaceSunken,
    surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textTertiary: textTertiary ?? this.textTertiary,
    textOnAction: textOnAction ?? this.textOnAction,
    borderSubtle: borderSubtle ?? this.borderSubtle,
    borderStrong: borderStrong ?? this.borderStrong,
    actionPrimaryBg: actionPrimaryBg ?? this.actionPrimaryBg,
    actionPrimaryFg: actionPrimaryFg ?? this.actionPrimaryFg,
    actionSecondaryFg: actionSecondaryFg ?? this.actionSecondaryFg,
    actionSecondaryBorder: actionSecondaryBorder ?? this.actionSecondaryBorder,
    actionDestructiveBg: actionDestructiveBg ?? this.actionDestructiveBg,
    actionDestructiveFg: actionDestructiveFg ?? this.actionDestructiveFg,
    scrim: scrim ?? this.scrim,
    success: success ?? this.success,
    critical: critical ?? this.critical,
    info: info ?? this.info,
    attention: attention ?? this.attention,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      surfaceBase: Color.lerp(surfaceBase, other.surfaceBase, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnAction: Color.lerp(textOnAction, other.textOnAction, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      actionPrimaryBg: Color.lerp(actionPrimaryBg, other.actionPrimaryBg, t)!,
      actionPrimaryFg: Color.lerp(actionPrimaryFg, other.actionPrimaryFg, t)!,
      actionSecondaryFg: Color.lerp(
        actionSecondaryFg,
        other.actionSecondaryFg,
        t,
      )!,
      actionSecondaryBorder: Color.lerp(
        actionSecondaryBorder,
        other.actionSecondaryBorder,
        t,
      )!,
      actionDestructiveBg: Color.lerp(
        actionDestructiveBg,
        other.actionDestructiveBg,
        t,
      )!,
      actionDestructiveFg: Color.lerp(
        actionDestructiveFg,
        other.actionDestructiveFg,
        t,
      )!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      success: FeedbackPalette.lerp(success, other.success, t),
      critical: FeedbackPalette.lerp(critical, other.critical, t),
      info: FeedbackPalette.lerp(info, other.info, t),
      attention: FeedbackPalette.lerp(attention, other.attention, t),
    );
  }
}

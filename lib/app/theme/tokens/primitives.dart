/// # LAYER 1 — Primitives
///
/// Raw values with no meaning attached. **This is the only file in the
/// application permitted to hold literal colour values** (Phase 6 §6.1).
///
/// No widget, screen, or feature may import this file. Components consume
/// Layer 2 semantic tokens (`AppColors`) exclusively — that indirection is the
/// entire mechanism by which a brand palette swap, the dark theme, and any
/// future white-label become possible.
///
/// The `no_primitive_token_outside_theme` custom lint (§8.7) fails the build on
/// a reference from outside `lib/app/theme/`.
///
/// ## Status: placeholder
///
/// Brand identity is unresolved (Phase 1 open items). This palette is coherent,
/// contrast-checked, and shippable. Substituting a real brand means editing the
/// ramps here and the `action.*` mappings in the semantic files — no component
/// changes.
library;

import 'package:flutter/painting.dart';

/// Primary ramp — warm terracotta / ember.
///
/// **Deliberately not green** (§6.2.1), for three reasons in order of weight:
///
/// 1. Green is the vegetarian mark in India. A green primary action colour
///    beside a green dietary mark degrades a signal carrying religious and
///    ethical weight. Reserving green for that meaning is a safety decision,
///    not an aesthetic one.
/// 2. Green is the incumbent competitor's identity, and Phase 1 requires an
///    original visual identity.
/// 3. Green is the default of every sustainability brand, so it reads generic
///    in a category where the proposition is *good food, much cheaper*.
abstract final class Ember {
  static const c50 = Color(0xFFFFF4ED);
  static const c100 = Color(0xFFFFE4D3);
  static const c200 = Color(0xFFFFC7A8);
  static const c300 = Color(0xFFFFA271);
  static const c400 = Color(0xFFFF7A3D);
  static const c500 = Color(0xFFF25C18);
  static const c600 = Color(0xFFD14509);
  static const c700 = Color(0xFFA9350A);
  static const c800 = Color(0xFF872D0F);
  static const c900 = Color(0xFF6E2810);
}

/// Neutral ramp — **warm-tinted, not blue-grey**.
///
/// Warm neutrals harmonise with the ember primary and read as more appetising
/// in a food context; cool greys read clinical.
abstract final class Neutral {
  static const c0 = Color(0xFFFFFFFF);
  static const c50 = Color(0xFFFAF8F7);
  static const c100 = Color(0xFFF4F1EF);
  static const c200 = Color(0xFFE7E2DF);
  static const c300 = Color(0xFFD3CCC7);
  static const c400 = Color(0xFFA89F99);
  static const c500 = Color(0xFF7D746E);
  static const c600 = Color(0xFF5C544F);
  static const c700 = Color(0xFF423C38);
  static const c800 = Color(0xFF2A2522);
  static const c900 = Color(0xFF1A1614);
  static const c950 = Color(0xFF0F0D0C);
}

/// Dark-mode surface tiers.
///
/// **Never `#000000`.** Pure black smears on OLED during scroll and produces
/// harsh contrast at high brightness — which is exactly the condition of the
/// pickup screen (§5d.3), where brightness is deliberately maximised.
///
/// In dark mode, elevation is conveyed by stepping *up* these tiers rather than
/// by shadow (§6.5). Shadows are invisible on dark surfaces; a dark theme that
/// relies on them is a flat theme.
abstract final class DarkSurface {
  static const base = Color(0xFF14110F);
  static const raised = Color(0xFF1C1917);
  static const overlay = Color(0xFF24201D);
  static const menu = Color(0xFF2C2724);
  static const highest = Color(0xFF35302C);

  static const borderSubtle = Color(0xFF332E2A);
  static const borderStrong = Color(0xFF4A443F);

  /// Never pure white. Pure white on a dark surface produces halation that
  /// makes body text harder to read, not easier.
  static const textPrimary = Color(0xFFF0EBE8);
  static const textSecondary = Color(0xFFB8B0AB);
  static const textTertiary = Color(0xFF8F8781);
}

/// Semantic feedback hues.
///
/// Two greens exist here and that is intentional: [successLight] / [successDark]
/// belong to the theme, while the vegetarian mark's green is fixed and lives
/// outside the theme entirely (amendment A22, `dietary_marks.dart`).
///
/// Named `FeedbackHues` rather than `Feedback` because Flutter's Material
/// library already exports a `Feedback` class (the haptic/acoustic helper).
/// The collision is invisible until a file imports both, at which point every
/// reference becomes an ambiguous-import error.
abstract final class FeedbackHues {
  static const successLight = Color(0xFF136F45);
  static const successDark = Color(0xFF4ECB8A);
  static const successBgLight = Color(0xFFE6F4EC);
  static const successBgDark = Color(0xFF10291D);

  static const criticalLight = Color(0xFFB3261E);
  static const criticalDark = Color(0xFFFF8A80);
  static const criticalBgLight = Color(0xFFFDECEA);
  static const criticalBgDark = Color(0xFF2E1614);

  static const infoLight = Color(0xFF0F5EA8);
  static const infoDark = Color(0xFF7FB6EE);
  static const infoBgLight = Color(0xFFE8F1FA);
  static const infoBgDark = Color(0xFF12212E);

  static const attentionLight = Color(0xFF8A5A00);
  static const attentionDark = Color(0xFFE8B84B);
  static const attentionBgLight = Color(0xFFFBF2E0);
  static const attentionBgDark = Color(0xFF2A2110);
}

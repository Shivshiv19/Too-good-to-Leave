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
/// ## Status: rebrand — "Too Good To Leave"
///
/// Deep forest green + warm cream, replacing the original ember/terracotta
/// palette. The original palette's own doc comment flagged green as
/// deliberately avoided (vegetarian-mark collision, and reads as "the
/// incumbent's identity") — both concerns still apply and are handled
/// elsewhere rather than by picking a different brand hue: the vegetarian
/// mark (`dietary_marks.dart`, amendment A22) is fixed independently of this
/// palette and stays visually distinct (a brighter, more saturated green than
/// any shade used here), and green is used here deliberately, at the user's
/// direction, as this brand's own identity rather than as an homage to any
/// other one.
library;

import 'package:flutter/painting.dart';

/// Primary ramp — deep forest green.
abstract final class Green {
  static const c950 = Color(0xFF182615);
  static const c900 = Color(0xFF20331B);
  static const c800 = Color(0xFF2B4423);
  static const c700 = Color(0xFF3C5C2C);
  static const c600 = Color(0xFF4F7434);
  static const c500 = Color(0xFF6B8F3D);
  static const c400 = Color(0xFF8FB33F);
  static const c300 = Color(0xFFB3D16B);
  static const c200 = Color(0xFFD7E8AD);
  static const c100 = Color(0xFFEEF5DA);
}

/// Warm cream — the canvas, and light-mode card surfaces sit above it in
/// white.
abstract final class Cream {
  static const c100 = Color(0xFFFAF8F0);
  static const c200 = Color(0xFFF4F0E2);
  static const c300 = Color(0xFFECE5D0);
}

/// Rewards / points accent. Used sparingly — never as a general UI colour.
abstract final class Gold {
  static const c500 = Color(0xFFC99A3F);
}

/// Neutral ramp — warm, faintly green-tinted (harmonises with the brand
/// green rather than reading as a cold, unrelated grey).
abstract final class Neutral {
  static const c0 = Color(0xFFFFFFFF);
  static const c50 = Color(0xFFFAF8F0);
  static const c100 = Color(0xFFF0EEE2);
  static const c200 = Color(0xFFDCDCCD);
  static const c300 = Color(0xFFA7AC9C);
  static const c400 = Color(0xFF8B917E);
  static const c500 = Color(0xFF6E7566);
  static const c600 = Color(0xFF596051);
  static const c700 = Color(0xFF454B3E);
  static const c800 = Color(0xFF2F3529);
  static const c900 = Color(0xFF1E2119);
  static const c950 = Color(0xFF14160F);
}

/// Dark-mode surface tiers — stepped through the brand green ramp itself
/// (§6.5's "elevation via lightness, not shadow" still applies; the steps
/// now come from [Green] rather than a neutral ramp).
///
/// **Never `#000000`.** Pure black smears on OLED during scroll and produces
/// harsh contrast at high brightness — which is exactly the condition of the
/// pickup screen (§5d.3), where brightness is deliberately maximised.
abstract final class DarkSurface {
  static const base = Green.c950;
  static const raised = Green.c900;
  static const overlay = Green.c800;
  static const menu = Green.c700;
  static const highest = Green.c600;

  static const borderSubtle = Color(0xFF2B3527);
  static const borderStrong = Color(0xFF445238);

  /// Never pure white. Pure white on a dark surface produces halation that
  /// makes body text harder to read, not easier.
  static const textPrimary = Cream.c100;
  static const textSecondary = Green.c200;
  static const textTertiary = Green.c300;
}

/// Semantic feedback hues.
///
/// Two greens exist across this theme and that is intentional: [successLight]
/// / [successDark] belong to the theme, while the vegetarian mark's green is
/// fixed and lives outside the theme entirely (amendment A22,
/// `dietary_marks.dart`) — chosen to sit visibly apart from both this feedback
/// green and the brand green in [Green] above.
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

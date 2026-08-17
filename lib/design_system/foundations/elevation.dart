import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:surplus_marketplace/app/theme/tokens/primitives.dart';

/// Elevation levels (Phase 6 §6.5).
///
/// **Light mode uses shadow; dark mode uses surface lightness.** Shadows are
/// invisible on dark surfaces, so a dark theme that relies on them for
/// hierarchy is a flat theme. [shadowsFor] returns an empty list in dark mode —
/// depth there comes from the `DarkSurface` tiers instead.
enum Elevation {
  /// Flat surfaces.
  flat(0),

  /// Cards.
  card(1),

  /// App bar on scroll, sticky action bar.
  sticky(2),

  /// Bottom sheets, dialogs.
  overlay(3),

  /// Snackbars, menus.
  highest(4);

  const Elevation(this.level);

  final int level;

  /// Shadows for this level, or none in dark mode.
  ///
  /// Shadow colour is derived from the **warm** neutral ramp rather than pure
  /// black — a cold shadow against warm neutrals reads as a rendering artefact.
  ///
  /// Softer and more diffuse since the "Too Good To Leave" rebrand — larger
  /// blur radii relative to spread/offset (Airbnb-style: shadows read as
  /// ambient warmth around a surface, not a hard-edged drop shadow), tinted
  /// from the brand green rather than the old warm-neutral near-black.
  ///
  /// **Two layers per level** (Starbucks-inspired rebrand) — a tight,
  /// near-zero-blur "contact" shadow directly under the surface, stacked
  /// with the original wider "ambient" shadow. Real light does both at
  /// once: a crisp near shadow where a surface actually touches the one
  /// below it, and a soft diffuse one further out — a single shadow can
  /// only approximate one or the other.
  List<BoxShadow> shadowsFor(Brightness brightness) {
    if (brightness == Brightness.dark) return const [];
    return switch (this) {
      Elevation.flat => const [],
      Elevation.card => const [
        BoxShadow(
          color: Color(0x1F1E2119),
          blurRadius: 1,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0F1E2119),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
      Elevation.sticky => const [
        BoxShadow(
          color: Color(0x1F1E2119),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x121E2119),
          blurRadius: 24,
          offset: Offset(0, 8),
        ),
      ],
      Elevation.overlay => const [
        BoxShadow(
          color: Color(0x241E2119),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x1A1E2119),
          blurRadius: 40,
          offset: Offset(0, 16),
        ),
      ],
      Elevation.highest => const [
        BoxShadow(
          color: Color(0x281E2119),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x231E2119),
          blurRadius: 56,
          offset: Offset(0, 20),
        ),
      ],
    };
  }

  /// The surface colour for this level in dark mode.
  ///
  /// Light mode returns `null` — the caller keeps its normal surface token and
  /// applies [shadowsFor] instead.
  Color? darkSurfaceFor(Brightness brightness) {
    if (brightness == Brightness.light) return null;
    return switch (this) {
      Elevation.flat => DarkSurface.base,
      Elevation.card => DarkSurface.raised,
      Elevation.sticky => DarkSurface.raised,
      Elevation.overlay => DarkSurface.overlay,
      Elevation.highest => DarkSurface.highest,
    };
  }
}

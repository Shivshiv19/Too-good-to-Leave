import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';

/// # Amendment A22 — dietary marks sit OUTSIDE the theme system
///
/// These values are **fixed and non-themeable**. They are not brand tokens and
/// they are not semantic tokens.
///
/// The Indian convention — a green mark for vegetarian, a brown/maroon mark for
/// non-vegetarian — is what users actually recognise, and it must look identical
/// in light mode, in dark mode, and under any future brand palette. Theming
/// these would break recognition of a signal carrying religious and ethical
/// weight, which is a materially worse failure than a slight visual
/// inconsistency with the rest of the surface.
///
/// This file is therefore a deliberate, documented exception to §6.1's
/// "no literal colours outside the primitives file" rule.
///
/// ## Two hard requirements
///
/// 1. **A text label is always mandatory** (§C6). These marks are conventional,
///    not universal; they are not accessible on their own; and a non-Indian user
///    will not know them. Colour and shape alone are never sufficient.
/// 2. **In dark mode the mark renders on a light chip.** `#007A3D` against
///    `#14110F` is low contrast. The *mark* keeps its fixed colour; the chip
///    supplies the contrast. See [needsLightChip].
abstract final class DietaryMarks {
  /// Conventional vegetarian green — filled circle in a squared outline.
  static const veg = Color(0xFF007A3D);

  /// Conventional non-vegetarian maroon — filled triangle in a squared outline.
  static const nonVeg = Color(0xFF8B1A1A);

  /// Egg-containing.
  ///
  /// **No regulatory standard exists for an egg mark in India**, so this one is
  /// our own design. That is precisely why its text label is mandatory rather
  /// than merely recommended: there is no convention for a user to fall back on.
  static const containsEgg = Color(0xFFC98A00);

  /// Chip behind the mark in dark mode.
  static const darkModeChip = Color(0xFFF0EBE8);

  /// The fixed mark colour for [envelope].
  ///
  /// Jain uses the vegetarian mark — it is visually a subset of vegetarian, and
  /// the distinction is carried entirely by the label.
  static Color colorFor(DietaryEnvelope envelope) => switch (envelope) {
    DietaryEnvelope.pureVeg => veg,
    DietaryEnvelope.jain => veg,
    DietaryEnvelope.containsEgg => containsEgg,
    DietaryEnvelope.nonVeg => nonVeg,
  };

  /// The geometric form of the mark, which carries meaning independently of
  /// colour — necessary for users with colour vision deficiency.
  static DietaryMarkShape shapeFor(DietaryEnvelope envelope) =>
      switch (envelope) {
        DietaryEnvelope.pureVeg => DietaryMarkShape.circle,
        DietaryEnvelope.jain => DietaryMarkShape.circle,
        DietaryEnvelope.containsEgg => DietaryMarkShape.square,
        DietaryEnvelope.nonVeg => DietaryMarkShape.triangle,
      };

  /// Whether the mark needs a light chip behind it on the current surface.
  static bool needsLightChip(Brightness brightness) =>
      brightness == Brightness.dark;
}

/// Mark geometry. Distinguishes envelopes without relying on colour.
enum DietaryMarkShape { circle, triangle, square }

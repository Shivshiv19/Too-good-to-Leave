import 'package:flutter/widgets.dart';

/// Motion tokens (Phase 6 §6.6).
abstract final class Motion {
  /// State toggles, chip selection.
  static const instant = Duration(milliseconds: 100);

  /// Buttons, small transitions.
  static const quick = Duration(milliseconds: 200);

  /// Sheets, dialogs, page transitions.
  static const standard = Duration(milliseconds: 300);

  /// Success affirmation and other deliberate moments.
  static const deliberate = Duration(milliseconds: 500);

  /// The delay before any loading indicator appears (§C1).
  ///
  /// An indicator that flashes for 150 ms reads as a glitch. Enforced inside
  /// the progress and button components rather than left to call sites.
  static const indicatorDelay = Duration(milliseconds: 400);

  /// Point at which a wait is acknowledged as unusual (§C2).
  static const slowThreshold = Duration(seconds: 8);

  static const easeStandard = Curves.easeInOutCubic;

  /// "Too Good To Leave" rebrand — Airbnb-style restrained easing
  /// (`cubic-bezier(0.16, 1, 0.3, 1)`), used for enter transitions in place
  /// of the old `easeOutCubic`. No bounce, no spring overshoot.
  static const easeEnter = Cubic(0.16, 1, 0.3, 1);
  static const easeExit = Curves.easeInCubic;
}

/// Reduced-motion helpers.
///
/// Reduced motion is a **first-class variant, not "animations off"** (§6.6).
/// Every animated affordance has an authored substitute:
///
/// | Default | Substitute |
/// |---|---|
/// | Animated success check | Static mark + text (§5c.8) |
/// | Error shake | Colour + text + announcement (§5a.7) |
/// | Page slide | Cross-fade (§5a.2) |
/// | Skeleton shimmer | Static placeholder (§C1) |
/// | Critical countdown pulse | Static critical treatment (§5d.3) |
///
/// No state in the application is communicated by motion alone (§C6).
extension ReducedMotion on BuildContext {
  /// Whether the platform has requested reduced motion.
  bool get prefersReducedMotion => MediaQuery.disableAnimationsOf(this);

  /// [duration], or [Duration.zero] when reduced motion is requested.
  ///
  /// Use for decorative transitions. For anything that *communicates* — a
  /// status change, an error — substitute an authored static treatment rather
  /// than merely zeroing the duration.
  Duration motion(Duration duration) =>
      prefersReducedMotion ? Duration.zero : duration;
}

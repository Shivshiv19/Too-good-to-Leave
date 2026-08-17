/// Spacing scale — base unit 4 dp, rhythm of 8 (Phase 6 §6.4).
///
/// Feature code must never use a numeric literal for padding, margin, or gap.
/// The `no_hardcoded_style` lint (§8.7) enforces this.
abstract final class Space {
  static const none = 0.0;
  static const x1 = 4.0;
  static const x2 = 8.0;
  static const x3 = 12.0;
  static const x4 = 16.0;
  static const x5 = 20.0;
  static const x6 = 24.0;
  static const x8 = 32.0;
  static const x10 = 40.0;
  static const x12 = 48.0;
  static const x16 = 64.0;

  /// Screen horizontal margin.
  static const screenMargin = x4;

  /// Standard card internal padding.
  static const cardPadding = x4;

  /// Gap between items in a vertical list.
  static const listGap = x3;

  /// Gap between major sections.
  static const sectionGap = x6;
}

/// Corner radii (§6.4). Larger and softer since the "Too Good To Leave"
/// rebrand — pill is the default for anything tappable and horizontal
/// (buttons, search, chips, nav), everything else uses generous rounding.
abstract final class Radii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const full = 999.0;

  /// Cards. `12px` exactly, matching the reference palette's card radius —
  /// its own value, not an alias of [md], since [md] is still used
  /// elsewhere for non-card rounding that isn't part of this swap.
  static const card = 12.0;

  /// Bottom sheets — top corners only.
  static const sheet = xl;

  /// Chips and pills.
  static const chip = full;
}

/// Layout constraints (§6.4).
abstract final class Layout {
  /// Minimum interactive target, per §C6 / WCAG 2.5.8.
  ///
  /// Applies to the *touch* target regardless of the control's visual height —
  /// a 36 dp chip still needs 48 dp of tappable area.
  static const minTouchTarget = 48.0;

  /// Minimum gap between adjacent touch targets.
  static const minTouchGap = 8.0;

  /// Maximum width for body content, centred beyond it.
  ///
  /// Flutter applications run on tablets and unfolded foldables. Without this
  /// cap, body text stretches to unreadable line lengths and the bag list
  /// becomes a sparse grid of full-width rows.
  static const contentMaxWidth = 600.0;

  /// Height of the primary sticky action bar (§5b.9, §5c.2). Excludes the
  /// bottom safe-area inset, which is added on top.
  static const stickyActionBarHeight = 72.0;

  /// Floor for the pickup QR's rendered size (§5d.3, amendment A21).
  ///
  /// At high text scale the page **scrolls** rather than shrinking the QR. An
  /// unscannable QR is a total failure of that screen, so text scaling must
  /// never compete with it for space.
  static const qrMinSize = 220.0;
}

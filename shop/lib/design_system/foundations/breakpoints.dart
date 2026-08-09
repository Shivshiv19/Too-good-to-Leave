import 'package:flutter/widgets.dart';

/// Responsive breakpoints — this is a SaaS-style web platform first, with a
/// mobile layout as the narrow case, not the other way around. One
/// breakpoint is enough for a shop-management tool (no tablet-specific
/// layout needed beyond "wide enough for a sidebar or not").
abstract final class Breakpoints {
  /// Below this: the mobile shell (floating bottom nav, single-column
  /// content). At or above: the desktop shell (persistent sidebar,
  /// multi-column content where it helps).
  static const desktop = 900.0;

  /// Content's own reading-width cap on wide screens — prevents a form or
  /// a page of text stretching edge-to-edge on an ultrawide monitor, the
  /// same reasoning the customer app's own `Layout.contentMaxWidth` uses.
  static const contentMaxWidth = 1100.0;

  /// A narrower cap for single-column content like forms, where full
  /// content width would make fields uncomfortably wide to scan.
  static const formMaxWidth = 640.0;
}

extension ResponsiveContext on BuildContext {
  bool get isDesktopWidth =>
      MediaQuery.sizeOf(this).width >= Breakpoints.desktop;
}

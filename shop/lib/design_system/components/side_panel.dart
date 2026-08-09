import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';

/// Opens [builder] as a right-side slide-in panel on desktop-width screens
/// (the SaaS "inspector" pattern — drilling into one record doesn't lose
/// the list behind it), or as an ordinary full-page push below that
/// breakpoint, where a fixed-width panel wouldn't fit.
Future<T?> openDetail<T>(
  BuildContext context,
  WidgetBuilder builder, {
  double panelWidth = 480,
}) {
  if (context.isDesktopWidth) {
    return showSidePanel<T>(context, builder: builder, width: panelWidth);
  }
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: builder));
}

/// The panel itself — a scrim over the current screen with a fixed-width
/// sheet sliding in from the right edge. Dismissible by tapping the scrim,
/// same as any modal; the content inside still calls `Navigator.pop`
/// (e.g. via its own AppBar back button) to close it, since this is a
/// route like any other.
Future<T?> showSidePanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 480,
}) {
  final colors = context.colors;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: colors.scrim,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: colors.surfaceBase,
        elevation: 8,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: builder(context),
        ),
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

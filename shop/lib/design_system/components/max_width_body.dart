import 'package:flutter/widgets.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/breakpoints.dart';

/// Caps content width and centers it on wide screens — otherwise a page
/// built for a phone stretches edge-to-edge on a desktop monitor, which is
/// the exact "looks like a mobile app in a browser tab" problem this
/// wrapper exists to fix. Below the cap (including the whole mobile
/// breakpoint) this is a no-op — the child just fills the available width
/// as it always did.
class MaxWidthBody extends StatelessWidget {
  const MaxWidthBody({
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
    super.key,
  });

  /// Use [Breakpoints.formMaxWidth] for single-column forms, where full
  /// content width reads as uncomfortably wide fields rather than a page
  /// of content worth spreading out.
  final double maxWidth;

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

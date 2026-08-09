import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// An icon on a soft, rounded tinted backdrop — the small badge that
/// precedes a fact row (pickup window, address, rating) rather than a bare
/// icon glyph sitting directly on the page background.
class IconBadge extends StatelessWidget {
  const IconBadge({required this.icon, this.size = 20, super.key});

  /// Glyph drawn in `actionPrimaryBg`.
  final IconData icon;

  /// Icon glyph size. The badge itself is always sized to keep generous
  /// padding around it, independent of this.
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: Space.x8,
      height: Space.x8,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Icon(icon, size: size, color: colors.actionPrimaryBg),
    );
  }
}

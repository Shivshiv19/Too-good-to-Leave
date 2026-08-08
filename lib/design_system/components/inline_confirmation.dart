import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/design_system/foundations/motion.dart';

/// §5e.3's `submitted` state — states the *value* of the contribution, not
/// just "thanks", because that's what makes a user review a second time.
/// Fades in; skips the animation under reduced motion.
class InlineConfirmation extends StatelessWidget {
  const InlineConfirmation({
    required this.title,
    required this.body,
    this.reducedMotion = false,
    super.key,
  });

  final String title;
  final String body;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content = Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.x5),
        decoration: BoxDecoration(
          color: colors.success.bg,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: colors.success.fg),
                const SizedBox(width: Space.x2),
                Text(
                  title,
                  style: context.type.title.copyWith(color: colors.success.fg),
                ),
              ],
            ),
            const SizedBox(height: Space.x1),
            Text(
              body,
              style: context.type.body.copyWith(color: colors.success.fg),
            ),
          ],
        ),
      ),
    );

    if (reducedMotion) return content;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.standard,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: content,
    );
  }
}

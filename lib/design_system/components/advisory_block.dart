import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Amendment A16 — deliberately distinct from `error` and `info` treatments
/// (§5d.6's hand-off to Phase 6).
///
/// Used for exactly one thing today: the food-safety consumption advisory
/// shown **before** the report form. It reads as neither a system error nor
/// routine information — it's an urgent, blunt instruction, which is why it
/// gets `critical` tone rather than `attention`'s softer amber.
class AdvisoryBlock extends StatelessWidget {
  const AdvisoryBlock({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Space.x4),
        decoration: BoxDecoration(
          color: colors.critical.bg,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: colors.critical.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.critical.fg),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.type.title.copyWith(
                      color: colors.critical.fg,
                    ),
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    body,
                    style: context.type.body.copyWith(
                      color: colors.critical.fg,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

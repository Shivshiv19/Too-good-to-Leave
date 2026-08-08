import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §5f.4's always-on transactional preference row — **must not render as a
/// disabled switch.** A greyed-out toggle reads as a bug and invites
/// repeated tapping; this uses a distinct visual (a static "Always on"
/// pill) and a distinct semantic (announced with the reason as text, via
/// [semanticLabel]), never `Switch(value: true, onChanged: null)`.
class AlwaysOnPreferenceRow extends StatelessWidget {
  const AlwaysOnPreferenceRow({
    required this.title,
    required this.alwaysOnLabel,
    required this.semanticLabel,
    super.key,
  });

  final String title;
  final String alwaysOnLabel;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        child: Row(
          children: [
            Expanded(child: Text(title, style: context.type.body)),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.x2,
                vertical: Space.x1,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceSunken,
                borderRadius: BorderRadius.circular(Radii.chip),
              ),
              child: Text(
                alwaysOnLabel,
                style: context.type.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

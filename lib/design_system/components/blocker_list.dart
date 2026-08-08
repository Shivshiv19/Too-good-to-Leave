import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// One deletion blocker (§5f.11) — stated with a route to resolution, never
/// a flat refusal.
class BlockerItem {
  const BlockerItem({
    required this.label,
    required this.actionLabel,
    required this.onTap,
  });

  final String label;
  final String actionLabel;
  final VoidCallback onTap;
}

/// §5f.11's blocker list — announced on entry (the caller wraps this in a
/// live-region `Semantics`, since the announcement policy is screen-level).
class BlockerList extends StatelessWidget {
  const BlockerList({required this.blockers, super.key});

  final List<BlockerItem> blockers;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        for (final blocker in blockers)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: Space.listGap),
            padding: const EdgeInsets.all(Space.x4),
            decoration: BoxDecoration(
              color: colors.critical.bg,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: colors.critical.border),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: colors.critical.fg),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Text(
                    blocker.label,
                    style: context.type.body.copyWith(
                      color: colors.critical.fg,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: blocker.onTap,
                  child: Text(blocker.actionLabel),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// A single facet or count affordance in the Discover facet bar and filter
/// sheet (§5b.1, §5b.4).
///
/// Active state and count are announced, not just shown visually — a
/// screen-reader user must be able to tell that results are narrowed and by
/// how much (§4.5 accessibility requirement).
class FacetChip extends StatelessWidget {
  const FacetChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = active ? colors.actionSecondaryFg : colors.textSecondary;
    final bg = active ? colors.info.bg : colors.surfaceRaised;
    final border = active ? colors.actionSecondaryBorder : colors.borderSubtle;

    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.chip),
          child: Container(
            constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x3,
              vertical: Space.x2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.chip),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: fg),
                  const SizedBox(width: Space.x1),
                ],
                Text(
                  label,
                  style: context.type.caption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

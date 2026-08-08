import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// A single choice inside a mutually-exclusive group of large option cards
/// (Phase 5a §5a.5's dietary-preset picker; general-purpose beyond it).
///
/// **Radio semantics, not button semantics.** A screen reader must announce
/// the selected state and the group relationship, so this uses
/// `Semantics(inMutuallyExclusiveGroup: true, checked: …)` rather than
/// `Semantics(button: true)`.
///
/// **Selection is never colour alone.** Checkmark, border weight, and label
/// weight all change together — a colour-only difference is invisible under
/// colour vision deficiency and to a screen reader.
///
/// **No fixed height.** The label wraps and the card grows with it, which is
/// what lets this survive `textScaleFactor` 2.0 (§C6) instead of clipping.
class SelectableCard extends StatelessWidget {
  const SelectableCard({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String label;

  final String? subtitle;

  final IconData? icon;

  final bool selected;

  /// Null disables the card.
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final borderColor = selected
        ? colors.actionSecondaryBorder
        : colors.borderSubtle;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onSelected != null,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
        child: Material(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.card),
          child: InkWell(
            onTap: onSelected,
            borderRadius: BorderRadius.circular(Radii.card),
            child: Container(
              padding: const EdgeInsets.all(Space.cardPadding),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: colors.textPrimary, size: 28),
                    const SizedBox(width: Space.x4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: context.type.title.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                          softWrap: true,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: Space.x1),
                          Text(
                            subtitle!,
                            style: context.type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                            softWrap: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? colors.success.fg : colors.borderStrong,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_colors.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_query.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_sort.dart';

/// §5b.5 — bottom sheet, no route. Radio list, exactly one selection.
class SortSheet extends StatelessWidget {
  const SortSheet({required this.initial, super.key});

  final DiscoverQuery initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    final options = <(DiscoverSort, String)>[
      (DiscoverSort.urgencyThenDistance, l10n.sortUrgencyThenDistance),
      (DiscoverSort.distance, l10n.sortByDistance),
      (DiscoverSort.pickupTime, l10n.sortByPickupTime),
      (DiscoverSort.priceAsc, l10n.sortByPriceAsc),
      (DiscoverSort.discountDesc, l10n.sortByDiscountDesc),
      (DiscoverSort.rating, l10n.sortByRating),
    ];
    final defaultBadge = l10n.sortDefaultBadge;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sortSheetTitle, style: context.type.title),
            const SizedBox(height: Space.x2),
            for (final (sort, label) in options)
              _SortOptionRow(
                label: label,
                defaultBadge: sort == DiscoverSort.urgencyThenDistance
                    ? defaultBadge
                    : null,
                selected: initial.sort == sort,
                onTap: () =>
                    Navigator.of(context).pop(initial.copyWith(sort: sort)),
                colors: colors,
              ),
          ],
        ),
      ),
    );
  }
}

class _SortOptionRow extends StatelessWidget {
  const _SortOptionRow({
    required this.label,
    required this.defaultBadge,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;

  /// Non-null (and rendered) only for the default option.
  final String? defaultBadge;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    label: defaultBadge != null ? '$label ($defaultBadge)' : label,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? colors.actionSecondaryFg
                    : colors.borderStrong,
              ),
              const SizedBox(width: Space.x3),
              Text(label, style: context.type.body),
              if (defaultBadge != null) ...[
                const SizedBox(width: Space.x2),
                Text(
                  defaultBadge!,
                  style: context.type.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

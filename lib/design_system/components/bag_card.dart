import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/components/dietary_mark_chip.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/scarcity.dart';

/// The most-repeated composite in the app (§5b.1) — reused by Discover,
/// Category browse, and Merchant profile.
///
/// **One merged semantic node, front-loaded by what decides the tap**: name,
/// dietary, price, distance, window, scarcity — in that order, matching
/// §5b.1's own example label exactly. A screen reader user should not have
/// to traverse the whole card to learn the one fact ("can I eat this?")
/// that gates everything else.
class BagCard extends StatelessWidget {
  const BagCard({
    required this.bag,
    required this.dietaryLabel,
    required this.clock,
    required this.onTap,
    super.key,
  });

  final BagSummary bag;

  /// Localised label for [BagSummary.dietaryEnvelope] — supplied by the
  /// caller so this component stays free of an `AppLocalizations` lookup
  /// for a single field (mirrors `DietaryMarkChip`'s own required `label`).
  final String dietaryLabel;

  final Clock clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semanticLabel =
        '${bag.merchant.displayName}, ${bag.title}. $dietaryLabel. '
        '${Fmt.money(bag.price)}, ${Fmt.wasPriceSemantics(bag.statedRetailValue)}, '
        '${bag.discountPercent}% off. ${Fmt.distance(bag.distanceMetres)}. '
        'Collect ${Fmt.pickupWindow(bag.pickupWindow, clock)}.'
        '${bag.scarcity == Scarcity.few ? ' Only a few left.' : ''}';

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: colors.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image-forward — a full-width photo with the pickup window
                // as a pill badge over it, rather than a small thumbnail
                // beside the text.
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: CachedNetworkImage(
                        imageUrl: bag.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: colors.surfaceSunken),
                        errorWidget: (context, url, error) => Container(
                          color: colors.surfaceSunken,
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: Space.x2,
                      bottom: Space.x2,
                      child: _PickupBadge(
                        text: Fmt.pickupWindowCompact(bag.pickupWindow),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bag.merchant.displayName.toUpperCase(),
                              style: context.type.labelSmall.copyWith(
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            Fmt.distance(bag.distanceMetres),
                            style: context.type.caption.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.x1),
                      Text(
                        bag.title,
                        style: context.type.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Space.x2),
                      DietaryMarkChip(
                        envelope: bag.dietaryEnvelope,
                        label: dietaryLabel,
                        compact: true,
                      ),
                      const SizedBox(height: Space.x2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Space.x2,
                        children: [
                          Text(
                            Fmt.money(bag.price),
                            style: context.type.priceMedium.copyWith(
                              color: colors.actionPrimaryBg,
                            ),
                          ),
                          Text(
                            Fmt.money(bag.statedRetailValue),
                            style: context.type.caption.copyWith(
                              color: colors.textTertiary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          if (bag.scarcity == Scarcity.few)
                            Text(
                              'Only a few left',
                              style: context.type.caption.copyWith(
                                color: colors.attention.fg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
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

/// The pickup-window pill overlaid on a [BagCard]'s photo. Purely
/// decorative alongside the card's own merged semantic label — excluded
/// from the tree so a screen reader doesn't hit it as a second node.
class _PickupBadge extends StatelessWidget {
  const _PickupBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x2,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          // `surfaceRaised` rather than a literal white — this pill sits
          // over an arbitrary photo, not a themed surface, but every
          // colour here still has to route through a token (§6.1).
          color: colors.surfaceRaised.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Text(
          'Pickup $text',
          style: context.type.caption.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

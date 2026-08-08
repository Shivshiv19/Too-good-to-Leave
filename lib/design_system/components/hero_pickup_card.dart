import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/countdown_text.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// The next imminent pickup, promoted out of the `/orders` list (§5d.1).
///
/// **The common case is exactly one active order** — a user in that case
/// should not have to parse a list to find the one thing they need. Carries
/// the countdown, Directions, and Show pickup code as its primary actions —
/// the three things a user opens the Orders tab to get.
class HeroPickupCard extends StatelessWidget {
  const HeroPickupCard({
    required this.merchantName,
    required this.bagTitle,
    required this.thumbnailUrl,
    required this.pickupWindow,
    required this.clock,
    required this.stateLabel,
    required this.onShowCode,
    required this.onDirections,
    required this.semanticLabel,
    required this.showCodeLabel,
    required this.showCodeSemanticLabel,
    required this.directionsLabel,
    super.key,
  });

  final String merchantName;
  final String bagTitle;
  final String thumbnailUrl;
  final PickupWindow pickupWindow;
  final Clock clock;

  /// Resolved copy for the current [PickupWindow.urgencyAt] state — e.g.
  /// *"Opens in 45 min"* / *"Collect now — closes in 1h 12m"* — supplied by
  /// the caller so this component stays free of l10n (mirrors
  /// `RefundTimeline`'s boundary).
  final String stateLabel;

  final VoidCallback onShowCode;
  final VoidCallback onDirections;

  final String semanticLabel;

  /// *"Show pickup code for order SV-7K2M"* (§5d.1) — the primary action's
  /// effect-labelled semantic, distinct from its short visible label.
  final String showCodeSemanticLabel;

  final String showCodeLabel;
  final String directionsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final urgency = pickupWindow.urgencyAt(clock);

    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.all(Space.x4),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: colors.actionSecondaryBorder, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: CachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: colors.surfaceSunken),
                    errorWidget: (context, url, error) =>
                        Container(color: colors.surfaceSunken),
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchantName,
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        bagTitle,
                        style: context.type.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.x3),
            Row(
              children: [
                ExcludeSemantics(
                  child: Text(
                    stateLabel,
                    style: context.type.body.copyWith(
                      color: colors.urgencyForeground(urgency),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (urgency == WindowUrgency.upcoming ||
                    urgency == WindowUrgency.openNow ||
                    urgency == WindowUrgency.closingSoon)
                  CountdownText(
                    target: urgency == WindowUrgency.upcoming
                        ? pickupWindow.startAt
                        : pickupWindow.endAt,
                    clock: clock,
                    urgency: urgency,
                  ),
              ],
            ),
            const SizedBox(height: Space.x4),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: directionsLabel,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.medium,
                    onPressed: onDirections,
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  flex: 2,
                  child: Semantics(
                    label: showCodeSemanticLabel,
                    excludeSemantics: true,
                    child: AppButton(
                      label: showCodeLabel,
                      size: AppButtonSize.medium,
                      onPressed: onShowCode,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

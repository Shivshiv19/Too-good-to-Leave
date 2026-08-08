import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/components/availability_state_badge.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// One row on `/saved` (§5e.2) — photo, name, category, distance, rating,
/// **live availability**, and an inline bell toggle. Unsave lives in the
/// overflow menu, not a swipe gesture — swipe-only destructive actions are
/// unreachable by screen reader and by users with motor impairments
/// (§5e.2's own accessibility requirement).
class SavedMerchantCard extends StatelessWidget {
  const SavedMerchantCard({
    required this.logoUrl,
    required this.name,
    required this.subtitle,
    required this.availabilityKind,
    required this.availabilityLabel,
    required this.watching,
    required this.watchSemanticLabel,
    required this.onTap,
    required this.onToggleWatch,
    required this.onUnsave,
    required this.unsaveLabel,
    super.key,
  });

  final String logoUrl;
  final String name;
  final String subtitle;
  final AvailabilityKind availabilityKind;
  final String availabilityLabel;
  final bool watching;
  final String watchSemanticLabel;
  final VoidCallback onTap;
  final VoidCallback onToggleWatch;
  final VoidCallback onUnsave;
  final String unsaveLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      child: Material(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Container(
            padding: const EdgeInsets.all(Space.x3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.sm),
                  child: CachedNetworkImage(
                    imageUrl: logoUrl,
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
                        name,
                        style: context.type.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: context.type.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Space.x1),
                      AvailabilityStateBadge(
                        kind: availabilityKind,
                        label: availabilityLabel,
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: watchSemanticLabel,
                  excludeSemantics: true,
                  child: IconButton(
                    icon: Icon(
                      watching
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      color: watching
                          ? colors.actionSecondaryFg
                          : colors.textSecondary,
                    ),
                    onPressed: onToggleWatch,
                  ),
                ),
                PopupMenuButton<void>(
                  icon: Icon(Icons.more_vert, color: colors.textSecondary),
                  itemBuilder: (context) => [
                    PopupMenuItem<void>(
                      onTap: onUnsave,
                      child: Text(unsaveLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

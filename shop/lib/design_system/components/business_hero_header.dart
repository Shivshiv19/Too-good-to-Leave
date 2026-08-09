import 'package:flutter/material.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/design_system/foundations/dimens.dart';

/// Full-bleed, brand-coloured header for the top of the account screen — a
/// large circular icon badge over a solid `actionPrimaryBg` field, in place
/// of an in-page light card. Shop profiles have no photo, so the badge is
/// always the storefront glyph rather than an avatar image.
class BusinessHeroHeader extends StatelessWidget {
  const BusinessHeroHeader({
    required this.businessName,
    required this.categoryLabel,
    super.key,
  });

  final String businessName;
  final String categoryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      color: colors.actionPrimaryBg,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x4,
        vertical: Space.x8,
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.textOnAction.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.storefront,
              size: 44,
              color: colors.textOnAction,
            ),
          ),
          const SizedBox(height: Space.x3),
          Text(
            businessName,
            style: context.type.headline.copyWith(color: colors.textOnAction),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.x1),
          Text(
            categoryLabel,
            style: context.type.body.copyWith(
              color: colors.textOnAction.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

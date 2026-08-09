import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/components/avatar_image.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// Full-bleed, brand-coloured header for the top of an account/profile
/// screen — a large centred avatar over a solid `actionPrimaryBg` field,
/// rather than `ProfileHeader`'s light in-page card. Meant to sit directly
/// under the status bar as the screen's own top section, not inside a
/// scrolling list of cards.
class AccountHeroHeader extends StatelessWidget {
  const AccountHeroHeader({
    required this.name,
    required this.subtitle,
    this.avatarUrl,
    this.onTap,
    super.key,
  });

  /// Display name, shown large and centred.
  final String name;

  /// Secondary line under the name — typically a masked phone number.
  final String subtitle;

  /// Passed straight through to [AvatarImage]; null falls back to initials.
  final String? avatarUrl;

  /// Null makes the header non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: onTap != null,
      label: '$name, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: colors.actionPrimaryBg,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.x4,
              vertical: Space.x8,
            ),
            child: Column(
              children: [
                AvatarImage(avatarUrl: avatarUrl, name: name, size: 88),
                const SizedBox(height: Space.x3),
                Text(
                  name,
                  style: context.type.headline.copyWith(
                    color: colors.textOnAction,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.x1),
                Text(
                  subtitle,
                  style: context.type.body.copyWith(
                    color: colors.textOnAction.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

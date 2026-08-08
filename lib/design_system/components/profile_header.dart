import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/components/avatar_image.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// `/account`'s identity block (§5f.1) — has a distinct **anonymous
/// variant** (amendment A18): a Sign-in prompt rather than a blank/broken
/// profile, since the Account root is public.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.name,
    required this.maskedPhone,
    required this.avatarUrl,
    required this.onTap,
    super.key,
  }) : anonymous = false,
       signInLabel = null,
       signInBody = null,
       onSignIn = null;

  const ProfileHeader.anonymous({
    required String this.signInLabel,
    required String this.signInBody,
    required VoidCallback this.onSignIn,
    super.key,
  }) : anonymous = true,
       name = null,
       maskedPhone = null,
       avatarUrl = null,
       onTap = null;

  final bool anonymous;
  final String? name;
  final String? maskedPhone;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final String? signInLabel;
  final String? signInBody;
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (anonymous) {
      return Container(
        padding: const EdgeInsets.all(Space.x4),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              signInBody!,
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: Space.x3),
            AppButton(label: signInLabel!, onPressed: onSignIn, expand: false),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: '$name, $maskedPhone',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Padding(
          padding: const EdgeInsets.all(Space.x4),
          child: Row(
            children: [
              AvatarImage(avatarUrl: avatarUrl, name: name, size: 56),
              const SizedBox(width: Space.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name ?? '', style: context.type.title),
                    Text(
                      maskedPhone ?? '',
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

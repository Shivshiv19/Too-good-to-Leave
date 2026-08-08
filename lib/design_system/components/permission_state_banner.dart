import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/components/app_button.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §5f.4's OS-permission banner — shown **first**, because in-app toggles
/// are meaningless while system permission is denied; presenting them as
/// effective would be a lie the user acts on.
class PermissionStateBanner extends StatelessWidget {
  const PermissionStateBanner({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: colors.attention.bg,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.attention.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.type.title.copyWith(color: colors.attention.fg),
          ),
          const SizedBox(height: Space.x1),
          Text(
            body,
            style: context.type.body.copyWith(color: colors.attention.fg),
          ),
          const SizedBox(height: Space.x3),
          AppButton(
            label: actionLabel,
            variant: AppButtonVariant.secondary,
            expand: false,
            onPressed: onAction,
          ),
        ],
      ),
    );
  }
}

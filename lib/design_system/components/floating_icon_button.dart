import 'package:flutter/material.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// A circular icon button meant to float directly on top of a photo — the
/// back/close button on a hero image, for instance. Always a translucent
/// dark scrim regardless of theme brightness, since it must stay legible
/// against whatever photo is underneath it rather than the surrounding
/// surface colour.
class FloatingIconButton extends StatelessWidget {
  const FloatingIconButton({
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
    super.key,
  });

  /// Icon drawn in white.
  final IconData icon;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Accessible name and tooltip text.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black45,
    shape: const CircleBorder(),
    child: SizedBox(
      width: Layout.minTouchTarget,
      height: Layout.minTouchTarget,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: semanticLabel,
        onPressed: onPressed,
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §5e.2's three availability variants — *"2 bags now"* / *"usually lists
/// around 8 pm"* / *"closed today"*.
///
/// **This is the entire point of the Saved screen** (§5e.2's own framing):
/// a saved list that doesn't say which of the three applies is a bookmark
/// folder, not a retention surface. Text, never colour alone.
enum AvailabilityKind { availableNow, expectedLater, closedToday }

class AvailabilityStateBadge extends StatelessWidget {
  const AvailabilityStateBadge({
    required this.kind,
    required this.label,
    super.key,
  });

  final AvailabilityKind kind;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (fg, bg) = switch (kind) {
      AvailabilityKind.availableNow => (colors.success.fg, colors.success.bg),
      AvailabilityKind.expectedLater => (
        colors.textSecondary,
        colors.surfaceSunken,
      ),
      AvailabilityKind.closedToday => (
        colors.textTertiary,
        colors.surfaceSunken,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x2,
        vertical: Space.x1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.chip),
      ),
      child: Text(
        label,
        style: context.type.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

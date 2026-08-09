import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// A pill-shaped -/count/+ control (Phase 6's generous-rounding language
/// applied to the quantity stepper, replacing a bare pair of `IconButton`s).
///
/// Decrementing below [min] and incrementing past [max] both disable their
/// half of the pill rather than hiding it — a missing control reads as a
/// bug, a disabled one reads as a limit.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.value,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.min = 1,
    this.max,
    super.key,
  });

  /// Current count, shown between the two step buttons.
  final int value;

  /// Called with the new value on either step button's tap.
  final ValueChanged<int> onChanged;

  /// Tooltip and accessible label for the decrement button.
  final String decreaseLabel;

  /// Tooltip and accessible label for the increment button.
  final String increaseLabel;

  /// Floor — decrementing disables once [value] reaches this.
  final int min;

  /// Ceiling — incrementing disables once [value] reaches this. Null means
  /// unbounded.
  final int? max;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final atMin = value <= min;
    final atMax = max != null && value >= max!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            label: decreaseLabel,
            onPressed: atMin ? null : () => onChanged(value - 1),
          ),
          SizedBox(
            width: Space.x8,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.type.title,
            ),
          ),
          _StepButton(
            icon: Icons.add,
            label: increaseLabel,
            onPressed: atMax ? null : () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: label,
          child: SizedBox(
            width: Layout.minTouchTarget,
            height: Layout.minTouchTarget,
            child: Icon(
              icon,
              size: 20,
              color: enabled ? colors.actionPrimaryBg : colors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

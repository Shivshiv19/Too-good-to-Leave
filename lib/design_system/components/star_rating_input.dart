import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §5e.3's star rating — **five discrete buttons of >= 48 dp, not a drag
/// target.** Drag-based star widgets are the single most common
/// accessibility failure in review UIs: unusable by screen reader and
/// unreliable for users with motor impairments.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    required this.value,
    required this.onChanged,
    required this.semanticLabelFor,
    super.key,
  });

  /// 0 means no rating chosen yet.
  final int value;
  final ValueChanged<int> onChanged;

  /// `(star) -> "Rate {star} of 5 stars"`, resolved by the caller.
  final String Function(int star) semanticLabelFor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var star = 1; star <= 5; star++)
          Semantics(
            button: true,
            selected: star <= value,
            label: semanticLabelFor(star),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => onChanged(star),
              customBorder: const CircleBorder(),
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: Layout.minTouchTarget,
                  minHeight: Layout.minTouchTarget,
                ),
                alignment: Alignment.center,
                child: Icon(
                  star <= value ? Icons.star : Icons.star_border,
                  size: 32,
                  color: star <= value
                      ? colors.actionPrimaryBg
                      : colors.borderStrong,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

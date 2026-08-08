import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_colors.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// One rendered step for [RefundTimeline] — presentation constructs these
/// from `RefundStep`, resolving the label/state to localised strings so
/// this component stays free of l10n (§5d.4's own component boundary).
class RefundTimelineStep {
  const RefundTimelineStep({
    required this.label,
    required this.completed,
    this.timestamp,
  });

  final String label;
  final bool completed;

  /// Formatted timestamp/expected-date text, shown under the label.
  final String? timestamp;
}

/// §5d.4's three-step timeline — *Refund started → Sent to your bank →
/// Credited*.
///
/// **An ordered list, each step's state announced** — *"Step 2 of 3, sent
/// to your bank, completed 26 July"* (§5d.4's own accessibility
/// requirement) — composed here from [RefundTimelineStep.label] plus
/// [semanticStateFor], which the caller supplies pre-formatted so this
/// component never needs its own l10n dependency.
class RefundTimeline extends StatelessWidget {
  const RefundTimeline({
    required this.steps,
    required this.semanticLabelFor,
    super.key,
  });

  final List<RefundTimelineStep> steps;

  /// `(step, index) -> full semantic label for that step`.
  final String Function(RefundTimelineStep step, int index) semanticLabelFor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // The first incomplete step is "current"; later ones are upcoming.
    final currentIndex = steps.indexWhere((s) => !s.completed);

    return Semantics(
      container: true,
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Semantics(
              label: semanticLabelFor(steps[i], i),
              excludeSemantics: true,
              child: _StepRow(
                step: steps[i],
                isLast: i == steps.length - 1,
                isCurrent: i == currentIndex,
                colors: colors,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isLast,
    required this.isCurrent,
    required this.colors,
  });

  final RefundTimelineStep step;
  final bool isLast;
  final bool isCurrent;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final dotColor = step.completed
        ? colors.success.fg
        : isCurrent
        ? colors.info.fg
        : colors.borderStrong;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                step.completed ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: dotColor,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: colors.borderSubtle),
                ),
            ],
          ),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: context.type.body.copyWith(
                      fontWeight: step.completed || isCurrent
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: step.completed || isCurrent
                          ? colors.textPrimary
                          : colors.textTertiary,
                    ),
                  ),
                  if (step.timestamp != null)
                    Text(
                      step.timestamp!,
                      style: context.type.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

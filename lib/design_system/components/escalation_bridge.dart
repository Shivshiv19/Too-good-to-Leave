import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// §5e.3's escalation bridge — **visually distinct from both an error
/// treatment and an ordinary CTA.** Not a courtesy: a low rating must not
/// merely become public text, it has to reach the §5d.6/A16 issue path, so
/// this needs to read as "we noticed something's wrong" rather than either
/// "something failed" (error tone) or "you might also like" (CTA tone).
class EscalationBridge extends StatelessWidget {
  const EscalationBridge({
    required this.prompt,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String prompt;
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
            prompt,
            style: context.type.body.copyWith(color: colors.attention.fg),
          ),
          const SizedBox(height: Space.x3),
          Semantics(
            button: true,
            label: actionLabel,
            excludeSemantics: true,
            child: InkWell(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: context.type.body.copyWith(
                  color: colors.attention.fg,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

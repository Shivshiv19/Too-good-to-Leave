import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';

/// Merchant legal name · FSSAI licence · grievance officer — the Consumer
/// Protection (E-commerce) Rules 2020 disclosure duty.
///
/// **Shared between merchant profile (§5b.8) and order detail (§5d.2)** —
/// the same three facts, disclosed at the point of discovery and again at
/// the point of purchase, so this exists once rather than twice risking
/// drift between the two renderings.
///
/// Deliberately plain text, not a card — a compliance disclosure reads as
/// more credible when it looks like print, not a promotional callout (a
/// distinction from `_TrustBlock`'s bordered container on the merchant
/// profile screen, which holds the *marketing* trust signals — verified
/// badge, halal certification — that this block does not).
class LegalDisclosureBlock extends StatelessWidget {
  const LegalDisclosureBlock({
    required this.legalName,
    required this.fssaiLine,
    required this.fssaiValidUntilLine,
    required this.grievanceLine,
    super.key,
  });

  final String legalName;

  /// e.g. `"FSSAI: 12345678901234"` — pre-composed by the caller.
  final String fssaiLine;

  /// e.g. `"Valid until by 2 Aug 2027"` — pre-composed by the caller.
  final String fssaiValidUntilLine;

  /// e.g. `"Grievance officer: grievance@merchant.example"` — pre-composed
  /// by the caller.
  final String grievanceLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.type.caption.copyWith(color: colors.textTertiary);
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(legalName, style: style),
          Text(fssaiLine, style: style),
          Text(fssaiValidUntilLine, style: style),
          Text(grievanceLine, style: style),
        ],
      ),
    );
  }
}

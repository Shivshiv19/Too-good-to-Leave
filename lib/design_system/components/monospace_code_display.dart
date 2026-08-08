import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// A code meant to be read aloud or transcribed by a stranger — the pickup
/// fallback code (§5d.3), an order code (§5d.2/§5c.8), or a refund bank
/// reference (§5d.4).
///
/// **Character-by-character semantics** — a screen reader announcing
/// `"SV7K2M"` as one word is useless to whoever is reading it aloud across a
/// shop counter; spacing the semantic label out is what makes it usable.
/// [copyable] adds a copy action for the bank-reference use case, where the
/// code is quoted into a bank's own support form rather than read aloud.
class MonospaceCodeDisplay extends StatelessWidget {
  const MonospaceCodeDisplay({
    required this.code,
    this.style,
    this.copyable = false,
    super.key,
  });

  final String code;
  final TextStyle? style;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final content = Semantics(
      label: code.split('').join(' '),
      excludeSemantics: true,
      child: Text(
        code,
        style: style ?? context.type.codeMono,
      ),
    );

    if (!copyable) return content;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const SizedBox(width: Space.x2),
        Semantics(
          button: true,
          label: 'Copy $code',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => Clipboard.setData(ClipboardData(text: code)),
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Padding(
              padding: const EdgeInsets.all(Space.x1),
              child: Icon(
                Icons.copy_outlined,
                size: 18,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

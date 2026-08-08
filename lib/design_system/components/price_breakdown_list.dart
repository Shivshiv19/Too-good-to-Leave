import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/price_breakdown.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/core/utils/formatters.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';

/// The authoritative price, rendered exactly as the server returned it
/// (§5c.1/§5c.2, Rule R1) — **a semantic label–value list, not a visual
/// two-column layout.** A right-aligned column of bare numbers is
/// meaningless to a screen reader; each row here is one merged node
/// pairing its label with its value.
///
/// [isStale] shows [PriceBreakdown]'s last-known-good values while a
/// re-quote (A11) is in flight, dimmed, with [priceRequoting] text —
/// **never a client-computed total, not even transiently.**
class PriceBreakdownList extends StatelessWidget {
  const PriceBreakdownList({
    required this.breakdown,
    this.isRequoting = false,
    super.key,
  });

  final PriceBreakdown breakdown;
  final bool isRequoting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);

    return Opacity(
      opacity: isRequoting ? 0.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Row(
            label: l10n.priceSubtotal,
            value: Fmt.money(breakdown.bagSubtotal),
          ),
          _Row(
            label: l10n.pricePlatformFee,
            value: Fmt.money(breakdown.platformFee),
          ),
          for (final tax in breakdown.taxes)
            _Row(label: tax.label, value: Fmt.money(tax.amount)),
          if (breakdown.discount != null)
            _Row(
              label: l10n.priceDiscount,
              value: '-${Fmt.money(breakdown.discount!)}',
            ),
          const Divider(),
          Semantics(
            label: l10n.priceTotalSemantic(Fmt.money(breakdown.total)),
            excludeSemantics: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.priceTotal, style: context.type.title),
                Text(
                  Fmt.money(breakdown.total),
                  style: context.type.title.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.x1),
          Text(
            l10n.priceTotalInclusive,
            style: context.type.caption.copyWith(color: colors.textSecondary),
          ),
          if (isRequoting) ...[
            const SizedBox(height: Space.x2),
            Text(
              l10n.priceRequoting,
              style: context.type.caption.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.x1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
            Text(value, style: context.type.body),
          ],
        ),
      ),
    );
  }
}

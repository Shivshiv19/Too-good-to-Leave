import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_colors.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_method.dart';

/// §5c.3 — bottom sheet, no route. UPI (Recommended) · Cards · Net banking
/// · Wallets.
///
/// **D-c1.** Selecting Cards or Net banking hands off entirely to the
/// gateway's own PCI-compliant flow — this app renders no card fields and
/// holds no PAN.
class PaymentMethodSheet extends StatelessWidget {
  const PaymentMethodSheet({required this.selected, super.key});

  final PaymentMethod selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;

    final methods = <(PaymentMethod, String, bool)>[
      (PaymentMethod.upi, l10n.checkoutMethodUpi, true),
      (PaymentMethod.card, l10n.checkoutMethodCard, true),
      (PaymentMethod.netBanking, l10n.checkoutMethodNetBanking, true),
      (PaymentMethod.wallet, l10n.checkoutMethodWallet, false),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (method, label, available) in methods)
              _MethodRow(
                label: label,
                recommended: method == PaymentMethod.upi,
                available: available,
                selected: selected == method,
                colors: colors,
                l10n: l10n,
                onTap: available
                    ? () => Navigator.of(context).pop(method)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.label,
    required this.recommended,
    required this.available,
    required this.selected,
    required this.colors,
    required this.l10n,
    required this.onTap,
  });

  final String label;
  final bool recommended;
  final bool available;
  final bool selected;
  final AppColors colors;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    enabled: available,
    label: available ? label : '$label, ${l10n.checkoutMethodUnavailable}',
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: Layout.minTouchTarget),
          padding: const EdgeInsets.symmetric(vertical: Space.x2),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: available
                    ? (selected
                          ? colors.actionSecondaryFg
                          : colors.borderStrong)
                    : colors.borderSubtle,
              ),
              const SizedBox(width: Space.x3),
              Text(
                label,
                style: context.type.body.copyWith(
                  color: available ? colors.textPrimary : colors.textTertiary,
                ),
              ),
              const SizedBox(width: Space.x2),
              if (recommended && available)
                Text(
                  l10n.checkoutMethodRecommended,
                  style: context.type.caption.copyWith(
                    color: colors.success.fg,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else if (!available)
                Text(
                  l10n.checkoutMethodUnavailable,
                  style: context.type.caption.copyWith(
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

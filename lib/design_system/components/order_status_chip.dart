import 'package:flutter/material.dart';
import 'package:surplus_marketplace/app/theme/app_colors.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';

/// One chip per [OrderStatus] (§5d.1's hand-off to Phase 6) — **icon and
/// text together**, never colour alone (§5d.1's own accessibility
/// requirement).
///
/// Colour comes from [AppColors.financialPalette] rather than a bespoke
/// per-status ramp — every [OrderStatus] is fundamentally a money-in-motion
/// state (pending / settled / failed), so this reuses the same three-tone
/// vocabulary as the rest of the app instead of inventing an eight-colour
/// scale that would fight it.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({required this.status, required this.label, super.key});

  final OrderStatus status;

  /// Localised label — resolved by the caller (l10n lives in
  /// presentation, never inside a design-system component).
  final String label;

  FinancialTone get _tone => switch (status) {
    OrderStatus.pendingPayment ||
    OrderStatus.readyForPickup => FinancialTone.pending,
    OrderStatus.confirmed || OrderStatus.collected => FinancialTone.settled,
    OrderStatus.paymentFailed ||
    OrderStatus.cancelledByCustomer ||
    OrderStatus.cancelledByMerchant ||
    OrderStatus.expiredUncollected => FinancialTone.failed,
  };

  IconData get _icon => switch (status) {
    OrderStatus.pendingPayment => Icons.hourglass_empty,
    OrderStatus.confirmed => Icons.check_circle_outline,
    OrderStatus.readyForPickup => Icons.storefront_outlined,
    OrderStatus.collected => Icons.task_alt,
    OrderStatus.paymentFailed => Icons.error_outline,
    OrderStatus.cancelledByCustomer ||
    OrderStatus.cancelledByMerchant => Icons.cancel_outlined,
    OrderStatus.expiredUncollected => Icons.timer_off_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.colors.financialPalette(_tone);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x1,
        ),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 14, color: palette.fg),
            const SizedBox(width: Space.x1),
            Text(
              label,
              style: context.type.caption.copyWith(
                color: palette.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

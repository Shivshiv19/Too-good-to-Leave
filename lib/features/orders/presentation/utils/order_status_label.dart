import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';

/// Localised label for [OrderStatusChip] — kept alongside the other
/// presentation-boundary label helpers in this feature.
String orderStatusLabel(OrderStatus status, AppLocalizations l10n) =>
    switch (status) {
      OrderStatus.pendingPayment => l10n.orderStatusPendingPayment,
      OrderStatus.confirmed => l10n.orderStatusConfirmed,
      OrderStatus.paymentFailed => l10n.orderStatusPaymentFailed,
      OrderStatus.readyForPickup => l10n.orderStatusReadyForPickup,
      OrderStatus.collected => l10n.orderStatusCollected,
      OrderStatus.cancelledByCustomer => l10n.orderStatusCancelledByCustomer,
      OrderStatus.cancelledByMerchant => l10n.orderStatusCancelledByMerchant,
      OrderStatus.expiredUncollected => l10n.orderStatusExpiredUncollected,
    };

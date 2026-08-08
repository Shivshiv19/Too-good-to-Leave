import 'package:surplus_marketplace/core/l10n/generated/app_localizations.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';

/// Localised label for [PaymentMethod] — order detail and refund status
/// both need this; `checkout`'s own mapping lives inline in a private
/// sheet widget, so this is a small, deliberate duplication rather than
/// reaching into that file (§8.3.1 — barrels only).
String paymentMethodLabel(PaymentMethod method, AppLocalizations l10n) =>
    switch (method) {
      PaymentMethod.upi => l10n.checkoutMethodUpi,
      PaymentMethod.card => l10n.checkoutMethodCard,
      PaymentMethod.netBanking => l10n.checkoutMethodNetBanking,
      PaymentMethod.wallet => l10n.checkoutMethodWallet,
    };

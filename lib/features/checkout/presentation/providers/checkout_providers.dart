import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/core/payment/payment_gateway.dart';
import 'package:surplus_marketplace/features/checkout/domain/repositories/checkout_repository.dart';

part 'checkout_providers.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`.
@riverpod
CheckoutRepository checkoutRepository(Ref ref) => throw UnimplementedError(
  'checkoutRepositoryProvider has no override — set one in bootstrap.dart.',
);

/// The gateway-SDK capability wrapper — see `PaymentGateway`'s class doc
/// for why this is distinct from [checkoutRepository] (R3: a gateway
/// callback never determines payment outcome, only the repository's
/// server-equivalent `verifyPayment` does).
@riverpod
PaymentGateway paymentGateway(Ref ref) => throw UnimplementedError(
  'paymentGatewayProvider has no override — set one in bootstrap.dart.',
);

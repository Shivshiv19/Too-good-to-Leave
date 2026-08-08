import 'package:surplus_marketplace/core/payment/payment_gateway.dart';

/// Stands in for the gateway SDK in the `dev` flavour (Phase 1 locked
/// decision). Simulates the round-trip delay of an app-switch to a UPI app
/// and back; the fixed gateway payloads it recognises never fail to
/// initiate, since a real "gateway down" scenario has nothing behind it to
/// simulate meaningfully yet.
final class PaymentGatewayFake implements PaymentGateway {
  const PaymentGatewayFake();

  @override
  Future<void> launch(String gatewayPayload) =>
      Future<void>.delayed(const Duration(seconds: 2));
}

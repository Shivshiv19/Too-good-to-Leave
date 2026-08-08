/// Thrown when the gateway fails to initiate **before** any app-switch —
/// the one case the processing screen (§5c.5) can still exit from by
/// redirecting to the payment-method screen, since no ambiguous in-flight
/// state exists yet.
final class GatewayInitiationException implements Exception {
  const GatewayInitiationException();
}

/// Platform capability (Phase 8 §8.6) abstracting the payment gateway SDK —
/// **no gateway type may reach `domain` or `presentation`.** Defined now
/// against the §7.5 contract so choosing a real gateway later touches this
/// one file.
///
/// **Deliberately narrow.** `launch` only ever reports "the hand-off to the
/// UPI app (or card/net-banking flow) happened" — never a payment outcome.
/// Rule R3 forbids a client callback from ever determining success or
/// failure; that stays the server's job via `CheckoutRepository.
/// verifyPayment`, polled after `launch` returns. A gateway SDK's own
/// "success" callback is exactly the trap R3 exists to prevent.
abstract interface class PaymentGateway {
  /// Hands off to the gateway using the server-supplied opaque
  /// `gatewayPayload` (§7.5's `POST /v1/orders` response). Completes once
  /// the app-switch-and-return cycle finishes — **not** once payment is
  /// known to have succeeded.
  ///
  /// Throws [GatewayInitiationException] if the hand-off itself could not
  /// begin (gateway down, no UPI app installed and no fallback available).
  Future<void> launch(String gatewayPayload);
}

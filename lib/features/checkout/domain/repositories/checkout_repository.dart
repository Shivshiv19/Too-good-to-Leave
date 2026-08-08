import 'package:surplus_marketplace/core/domain/price_breakdown.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/hold.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_method.dart';

/// A payment/order pair, the shape `POST /v1/orders` returns (Phase 7 §7.5).
final class OrderCreationResult {
  const OrderCreationResult({
    required this.order,
    required this.payment,
    required this.gatewayPayload,
  });

  final Order order;
  final Payment payment;

  /// Opaque, single-use input to `PaymentGateway.launch` — **not** part of
  /// the persisted [Payment] record, unlike [Payment.gatewayRef], which is
  /// a stored reference for later reference/support.
  final String gatewayPayload;
}

/// A payment in flight when the app was killed mid-app-switch (amendment
/// A3) — `GET /v1/orders/unresolved`'s `204` becomes `null` here.
final class UnresolvedPayment {
  const UnresolvedPayment({required this.orderId, required this.paymentId});

  final String orderId;
  final String paymentId;
}

/// Server stand-in (Phase 1 locked decision) for the highest-risk area in
/// the app (Phase 5c, Phase 7 §7.5) — every method here exists because R1,
/// R2, or R3 forbids the client from deciding the answer itself.
abstract interface class CheckoutRepository {
  /// `POST /v1/holds` (idem) — revalidates availability (R2) and enforces
  /// the per-customer cap (A9). May throw `BagSoldOutException`,
  /// `BagWithdrawnException`, `BagWindowClosedException`, or
  /// `PurchaseCapExceededException`.
  Future<Hold> createHold({required String bagId, required int quantity});

  /// A passive read of the current hold state — not in §7.5's own literal
  /// endpoint list, but needed so `/checkout/pay` can resolve from a cold
  /// start (§4.8) using only `holdId` from the URL, the same way every
  /// other route in this app resolves without in-memory navigation state.
  /// Throws `HoldExpiredException` if the hold is gone or has expired.
  Future<Hold> getHold(String holdId);

  /// `POST /v1/checkout/quote` — **A11**. Repeatable, no side effects on
  /// the hold; this is what makes R1 practical, since the client asks for
  /// a total rather than computing one.
  Future<PriceBreakdown> quote({
    required String holdId,
    required int quantity,
  });

  /// `PATCH /v1/holds/{holdId}` — adjusts quantity and returns a fresh
  /// hold (with a fresh breakdown, per A11).
  Future<Hold> adjustHold({required String holdId, required int quantity});

  /// `DELETE /v1/holds/{holdId}` — explicit release.
  Future<void> releaseHold(String holdId);

  /// `POST /v1/orders` (idem). **A2: creating the order freezes the
  /// hold** — it cannot expire while payment is `pending` or
  /// `pendingVerification`. May throw `BagSoldOutException` or
  /// `HoldExpiredException`.
  Future<OrderCreationResult> createOrder({
    required String holdId,
    required String customerId,
    required PaymentMethod method,
    String? upiApp,
  });

  /// `POST /v1/payments/{id}/verify` (idem) — **R3**, the only authority
  /// on payment outcome. Never inferred from a gateway callback.
  Future<Payment> verifyPayment(String paymentId);

  /// `GET /v1/payments/{id}`, `no-store` — the poll target for §5c.6.
  Future<Payment> getPayment(String paymentId);

  /// `GET /v1/orders/unresolved` — **A3**. Splash-equivalent check: lets a
  /// cold start after a kill mid-app-switch resume at `/checkout/verifying`
  /// instead of losing track of an in-flight debit. `null` means `204`.
  Future<UnresolvedPayment?> getUnresolvedOrder();

  /// `GET /v1/orders/{id}` — needed by the verifying/confirmed screens to
  /// resolve full order details independently of in-memory navigation
  /// state (in particular, on the A3 cold-start resume path, where
  /// nothing was passed via navigation `extra`).
  Future<Order> getOrder(String orderId);
}

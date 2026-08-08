/// Phase 2 §2.2 state machine (full aggregate — `checkout` only produces
/// and consumes the pre-collection states; `readyForPickup`/`collected`/
/// the cancellation states are `orders`' concern, Phase 8 §8.12 step 7, but
/// the enum is shared and complete since it's one state machine, not two).
///
/// Terminal: [collected], [expiredUncollected], [cancelledByCustomer],
/// [cancelledByMerchant].
enum OrderStatus {
  pendingPayment,
  confirmed,
  paymentFailed,
  readyForPickup,
  collected,
  cancelledByCustomer,
  cancelledByMerchant,
  expiredUncollected;

  /// Tolerant decoder (Phase 7 §7.1.4). Falls back to [pendingPayment] —
  /// the conservative reading: an order in an unrecognised state is safer
  /// treated as still resolving than as any of the terminal outcomes.
  static OrderStatus fromWire(String value) => switch (value) {
    'confirmed' => OrderStatus.confirmed,
    'paymentFailed' => OrderStatus.paymentFailed,
    'readyForPickup' => OrderStatus.readyForPickup,
    'collected' => OrderStatus.collected,
    'cancelledByCustomer' => OrderStatus.cancelledByCustomer,
    'cancelledByMerchant' => OrderStatus.cancelledByMerchant,
    'expiredUncollected' => OrderStatus.expiredUncollected,
    _ => OrderStatus.pendingPayment,
  };
}

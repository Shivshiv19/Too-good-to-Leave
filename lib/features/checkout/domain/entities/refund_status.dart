/// Phase 2 §2.1 — `Refund`'s own status, distinct from [PaymentStatus]'s
/// `refundInitiated`/`refunded`/`refundFailed` values (those describe the
/// *payment*; this describes the *refund* hanging off it).
enum RefundStatus {
  initiated,
  refunded,
  failed;

  /// Tolerant decoder (Phase 7 §7.1.4). Falls back to [initiated] — never
  /// silently claim a refund completed or failed on an unrecognised value;
  /// §5d.4 requires an honest, dated status, not an optimistic guess.
  static RefundStatus fromWire(String value) => switch (value) {
    'refunded' => RefundStatus.refunded,
    'failed' => RefundStatus.failed,
    _ => RefundStatus.initiated,
  };
}

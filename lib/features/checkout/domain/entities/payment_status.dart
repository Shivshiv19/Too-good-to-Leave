/// Phase 2 §2.2 state machine:
///
/// ```
/// created ─► pending ─► pendingVerification ─► captured   (terminal success)
///                             ├─► failed              (retryable)
///                             └─► cancelled           (user abandoned)
///
/// captured ─► refundInitiated ─► refunded | refundFailed
/// ```
///
/// **`pendingVerification` is the most important state in the system**
/// (§5c.6) — Indian UPI intent flows app-switch and frequently return an
/// indeterminate result. The client enters this state on return from
/// app-switch and polls a server-side verification endpoint; a
/// client-reported success never confirms an order (R3).
enum PaymentStatus {
  created,
  pending,
  pendingVerification,
  captured,
  failed,
  cancelled,
  refundInitiated,
  refunded,
  refundFailed;

  /// Tolerant decoder (Phase 7 §7.1.4). Falls back to [pendingVerification]
  /// — the conservative reading for a status this client doesn't
  /// recognise: keep polling and showing the "don't pay again, we're
  /// checking" copy rather than silently treating an unknown state as
  /// resolved either way.
  static PaymentStatus fromWire(String value) => switch (value) {
    'created' => PaymentStatus.created,
    'pending' => PaymentStatus.pending,
    'captured' => PaymentStatus.captured,
    'failed' => PaymentStatus.failed,
    'cancelled' => PaymentStatus.cancelled,
    'refundInitiated' => PaymentStatus.refundInitiated,
    'refunded' => PaymentStatus.refunded,
    'refundFailed' => PaymentStatus.refundFailed,
    _ => PaymentStatus.pendingVerification,
  };
}

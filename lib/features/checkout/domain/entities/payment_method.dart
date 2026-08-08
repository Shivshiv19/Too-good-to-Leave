/// Phase 2 §2.1. UPI is pre-selected by default (Phase 1 mandate, §5c.2) —
/// not expressed here since default-selection is a screen concern, not a
/// property of the enum.
enum PaymentMethod {
  upi,
  card,
  netBanking,
  wallet;

  /// Tolerant decoder (Phase 7 §7.1.4). Falls back to [upi] — the
  /// server-mandated default rail, so an unrecognised method never leaves
  /// the UI with nothing pre-selectable.
  static PaymentMethod fromWire(String value) => switch (value) {
    'upi' => PaymentMethod.upi,
    'card' => PaymentMethod.card,
    'netBanking' => PaymentMethod.netBanking,
    'wallet' => PaymentMethod.wallet,
    _ => PaymentMethod.upi,
  };
}

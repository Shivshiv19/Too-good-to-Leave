/// Phase 2 §2.2 state machine: `draft → live → {soldOut, windowClosed,
/// withdrawnByMerchant}`.
enum BagStatus {
  draft,
  live,
  soldOut,
  windowClosed,
  withdrawnByMerchant;

  /// An unknown value falls back to [windowClosed] — the conservative
  /// reading for a bag this client's enum doesn't recognise: treat it as
  /// uncollectable rather than risk offering something a newer server
  /// considers unavailable for a reason this build can't express.
  static BagStatus fromWire(String value) => switch (value) {
    'draft' => BagStatus.draft,
    'live' => BagStatus.live,
    'soldOut' => BagStatus.soldOut,
    'withdrawnByMerchant' => BagStatus.withdrawnByMerchant,
    _ => BagStatus.windowClosed,
  };
}

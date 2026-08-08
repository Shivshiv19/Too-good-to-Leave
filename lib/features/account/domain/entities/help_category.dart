/// §5f.6's topic categories.
enum HelpCategory {
  reservations,
  pickup,
  paymentsRefunds,
  account,

  /// Its own category — food safety is a distinct risk class, not a
  /// sub-case of "pickup" or "account" (Phase 1 risk 6).
  foodSafety,
}

/// Business category, selected at registration.
///
/// A small fixed set for this standalone MVP rather than the customer app's
/// server-driven `Taxonomy` (Phase 2 §2.3) — that system exists so a new
/// category doesn't need a client release; this app has no server to drive
/// it from yet, and the fixed set is easy to widen later without changing
/// anything that reads it (a `String` `label` either way).
enum ShopCategory {
  bakery('Bakery'),
  restaurant('Restaurant'),
  cafe('Cafe'),
  grocery('Grocery'),
  sweetsShop('Sweets shop'),
  cloudKitchen('Cloud kitchen'),
  other('Other');

  const ShopCategory(this.label);

  final String label;
}

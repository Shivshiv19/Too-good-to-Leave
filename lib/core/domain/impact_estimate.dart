/// Environmental-impact estimates from collected bags.
///
/// **Both figures below are illustrative assumptions, not measured data** —
/// mirrors the shop app's own `domain/impact_estimate.dart` exactly (same
/// "modelled, not measured" honesty this app's docs already apply to unit
/// economics), computed here from one customer's own collected orders
/// instead of one shop's.
///
/// - **~0.4 kg per bag** — roughly a single meal's worth of surplus food.
/// - **~2.5 kg CO2e avoided per kg of food waste** — a commonly cited
///   figure for the emissions of food production, transport, and landfill
///   decomposition combined; treat as an order-of-magnitude estimate, not
///   a precise carbon accounting figure.
abstract final class ImpactEstimate {
  static const kgPerBag = 0.4;
  static const co2eKgPerKgFood = 2.5;

  /// One collected bag ≈ one meal, by construction (Phase 1's single-bag,
  /// single-portion model).
  static int mealsSaved(int collectedBagCount) => collectedBagCount;

  static double kgSaved(int collectedBagCount) => collectedBagCount * kgPerBag;

  static double co2eKgAvoided(int collectedBagCount) =>
      kgSaved(collectedBagCount) * co2eKgPerKgFood;
}

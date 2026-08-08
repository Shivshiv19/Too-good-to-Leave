/// Environmental-impact estimates from collected bags.
///
/// **Both figures below are illustrative assumptions, not measured data** —
/// the same "modelled, not measured" honesty the customer app's own docs
/// apply to unit economics (Phase 1 §1.2). No source in this project states
/// an actual average surprise-bag weight or a CO2e-per-kg-of-food-waste
/// figure, so these are reasonable, commonly-cited approximations rather
/// than invented-to-look-good numbers:
///
/// - **~0.4 kg per bag** — roughly a single meal's worth of surplus food,
///   consistent with this product's own bag-size framing (Phase 1's
///   ₹120-bag / single-portion positioning).
/// - **~2.5 kg CO2e avoided per kg of food waste** — a commonly cited
///   figure for the emissions of food production, transport, and landfill
///   decomposition combined; treat as an order-of-magnitude estimate, not
///   a precise carbon accounting figure.
abstract final class ImpactEstimate {
  static const kgPerBag = 0.4;
  static const co2eKgPerKgFood = 2.5;

  /// One collected bag ≈ one meal, by construction (Phase 1's single-bag,
  /// single-portion model — see A6, "one reservation = one merchant").
  static int mealsSaved(int collectedBagCount) => collectedBagCount;

  static double kgSaved(int collectedBagCount) => collectedBagCount * kgPerBag;

  static double co2eKgAvoided(int collectedBagCount) =>
      kgSaved(collectedBagCount) * co2eKgPerKgFood;
}

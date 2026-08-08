/// §5d.6 — scoped to the order's status. Outbound-only (chosen by the
/// customer, never returned by the server), so this carries a [wireValue]
/// getter but deliberately no tolerant `fromWire` — nothing ever decodes it.
enum IssueType {
  // `confirmed` / `readyForPickup`
  merchantClosed('merchant_closed'),
  noBagReady('no_bag_ready'),
  wrongLocation('wrong_location'),
  cantMakeIt('cant_make_it'),

  // `collected`
  notAsDescribed('not_as_described'),
  qualityProblem('quality_problem'),
  quantityWrong('quantity_wrong'),

  /// Amendment A16 — escalated, not queued. See [isFoodSafety].
  foodSafety('food_safety'),

  // `expiredUncollected`
  wasThereCouldntCollect('was_there_couldnt_collect'),
  merchantRefused('merchant_refused');

  const IssueType(this.wireValue);

  final String wireValue;

  bool get isFoodSafety => this == IssueType.foodSafety;
}

/// §5e.3's two rating-conditional tag sets.
enum ReviewTag {
  // 4–5 stars
  greatValue('great_value'),
  fresh('fresh'),
  generousPortion('generous_portion'),
  easyPickup('easy_pickup'),
  friendlyStaff('friendly_staff'),

  // 1–3 stars
  notFresh('not_fresh'),
  tooLittle('too_little'),
  hardToFind('hard_to_find'),
  longWait('long_wait'),
  notAsDescribed('not_as_described');

  const ReviewTag(this.wireValue);

  final String wireValue;

  /// Whether this tag belongs to the low-rating (1–3 star) set — asking a
  /// delighted user "what went wrong?" is jarring, and vice versa (§5e.3),
  /// so the picker only ever shows one set at a time.
  bool get isNegative => switch (this) {
    ReviewTag.notFresh ||
    ReviewTag.tooLittle ||
    ReviewTag.hardToFind ||
    ReviewTag.longWait ||
    ReviewTag.notAsDescribed => true,
    _ => false,
  };
}

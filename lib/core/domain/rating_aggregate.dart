/// A merchant or bag's aggregate rating (Phase 2 §2.1).
///
/// Hand-written per D-1 — [histogramPercent] is real behavioural logic, not
/// a plain data holder.
final class RatingAggregate {
  const RatingAggregate({
    required this.average,
    required this.count,
    required this.histogram,
  });

  /// Empty aggregate for a merchant with no reviews yet (§5b.11) — an
  /// absence of reviews must not read as a negative signal.
  factory RatingAggregate.empty() => const RatingAggregate(
    average: 0,
    count: 0,
    histogram: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
  );

  final double average;
  final int count;

  /// Star (1..5) → review count at that star.
  final Map<int, int> histogram;

  bool get hasReviews => count > 0;

  /// Percentage of reviews at [star], for the histogram's text-equivalent
  /// bars (§5b.11 accessibility requirement — a bar chart alone is
  /// inaccessible).
  double histogramPercent(int star) {
    if (count == 0) return 0;
    return (histogram[star] ?? 0) / count * 100;
  }

  @override
  bool operator ==(Object other) =>
      other is RatingAggregate &&
      other.average == average &&
      other.count == count &&
      _mapEquals(other.histogram, histogram);

  @override
  int get hashCode => Object.hash(
    average,
    count,
    // `MapEntry` has no value-based `==`/`hashCode` of its own, so hashing
    // `histogram.entries` directly would hash by identity — two equal maps
    // built separately would then hash differently. `hashAllUnordered`
    // combines the key/value pairs' own hashes instead, and does so
    // order-independently, matching what `_mapEquals` considers equal.
    Object.hashAllUnordered(
      histogram.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  static bool _mapEquals(Map<int, int> a, Map<int, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// §5b.5 sort sheet options. `urgencyThenDistance` is the default (D-b1) —
/// pickup time is the dominant decision axis in a time-boxed marketplace.
enum DiscoverSort {
  urgencyThenDistance,
  distance,
  pickupTime,
  priceAsc,
  discountDesc,
  rating,
}

/// §2.3's "Pickup time" facet — single-select, not the same axis as
/// [DiscoverSort.pickupTime] (a sort has no cutoff; this facet excludes).
enum PickupTimeFacet { availableNow, laterToday, tomorrow }

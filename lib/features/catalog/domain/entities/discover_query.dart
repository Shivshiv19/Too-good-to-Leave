import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_sort.dart';

/// The URL-addressable facet state behind `/discover?<facets>` (§4.5) —
/// carried as a plain value object between the router, the filter/sort
/// sheets, and the repository, rather than each owning its own shape.
final class DiscoverQuery {
  const DiscoverQuery({
    required this.anchor,
    this.radiusKm = 5,
    this.acceptedEnvelopes = const {},
    this.categories = const {},
    this.foodTypes = const {},
    this.priceMinPaise,
    this.priceMaxPaise,
    this.minRating,
    this.pickupTimeFacet,
    this.sort = DiscoverSort.urgencyThenDistance,
  });

  final LatLng anchor;

  /// A11 — default ~5 km, user-adjustable.
  final int radiusKm;

  /// A7 — an acceptance **set**, not a single envelope. Empty means "use the
  /// customer's stored acceptance set", resolved by the caller before this
  /// reaches the repository.
  final Set<DietaryEnvelope> acceptedEnvelopes;

  /// Taxonomy-tag IDs.
  final Set<String> categories;

  /// Taxonomy-tag IDs.
  final Set<String> foodTypes;
  final int? priceMinPaise;
  final int? priceMaxPaise;
  final int? minRating;
  final PickupTimeFacet? pickupTimeFacet;
  final DiscoverSort sort;

  DiscoverQuery copyWith({
    LatLng? anchor,
    int? radiusKm,
    Set<DietaryEnvelope>? acceptedEnvelopes,
    Set<String>? categories,
    Set<String>? foodTypes,
    int? priceMinPaise,
    int? priceMaxPaise,
    int? minRating,
    PickupTimeFacet? pickupTimeFacet,
    bool clearPickupTimeFacet = false,
    DiscoverSort? sort,
  }) => DiscoverQuery(
    anchor: anchor ?? this.anchor,
    radiusKm: radiusKm ?? this.radiusKm,
    acceptedEnvelopes: acceptedEnvelopes ?? this.acceptedEnvelopes,
    categories: categories ?? this.categories,
    foodTypes: foodTypes ?? this.foodTypes,
    priceMinPaise: priceMinPaise ?? this.priceMinPaise,
    priceMaxPaise: priceMaxPaise ?? this.priceMaxPaise,
    minRating: minRating ?? this.minRating,
    pickupTimeFacet: clearPickupTimeFacet
        ? null
        : (pickupTimeFacet ?? this.pickupTimeFacet),
    sort: sort ?? this.sort,
  );

  /// Whether any facet narrows results beyond dietary/radius/sort defaults —
  /// drives the facet bar's active-chip display (§4.5) and the "Clear
  /// filters" empty-state action (A10).
  bool get hasActiveFacets =>
      categories.isNotEmpty ||
      foodTypes.isNotEmpty ||
      priceMinPaise != null ||
      priceMaxPaise != null ||
      minRating != null ||
      pickupTimeFacet != null;
}

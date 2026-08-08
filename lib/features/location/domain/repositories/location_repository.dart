import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/features/location/domain/entities/locality_suggestion.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';

/// Server stand-in (Phase 1 locked decision) for search/geocoding/serviceable
/// -bounds — the parts of §5a.4 that would hit a backend. Raw GPS acquisition
/// itself is a device fact, not modelled here — see `LocationCapability`.
abstract interface class LocationRepository {
  /// Locality/pincode autocomplete (§5a.4). Empty results are a valid,
  /// expected answer — the screen renders `noResults`, not an error.
  Future<List<LocalitySuggestion>> search(String query);

  /// Recent locations, then popular localities in the launch city — the
  /// screen's fallback content for an empty search field (§5a.4 empty-state
  /// table), never a blank field with no starting point.
  Future<List<LocalitySuggestion>> popularLocalities();

  /// Most-recently-confirmed locations, most recent first.
  Future<List<ResolvedLocation>> recentLocations();

  /// Turns a raw coordinate into a [ResolvedLocation]. [precision] is
  /// supplied by the caller (from [LocationCapability]'s permission
  /// outcome) — display text must never claim more precision than the
  /// device actually granted (§5a.4).
  Future<ResolvedLocation> reverseGeocode(
    LatLng latLng, {
    required LocationPrecision precision,
    required LocationSource source,
  });

  /// Whether [latLng] falls inside the launch city's service area (§5a.4 —
  /// `Confirm` stays disabled outside it).
  Future<bool> isWithinServiceableBounds(LatLng latLng);

  /// Persists [location] as the active discovery anchor and records it in
  /// [recentLocations].
  Future<void> confirmLocation(ResolvedLocation location);

  /// The last confirmed location, if any — read once at Splash (§4.1) and
  /// again by the setup screen's offline fallback (§5a.4).
  Future<ResolvedLocation?> cachedLocation();
}

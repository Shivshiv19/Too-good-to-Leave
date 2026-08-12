import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/platform/geocoding_service.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/location/data/repositories/location_repository_fake.dart';
import 'package:surplus_marketplace/features/location/domain/entities/locality_suggestion.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';
import 'package:surplus_marketplace/features/location/domain/repositories/location_repository.dart';

/// Real geocoding via MapTiler, replacing [LocationRepositoryFake]'s
/// Bengaluru-only fixture search/reverse-geocode now that shops (and the
/// real Supabase-backed bags they list) can register in any city — the
/// Phase-1 "single launch city" assumption the fixture data was built
/// against no longer holds once a real backend is in the loop.
///
/// Purely local concerns (recents/popular/cached/confirm, all
/// `Prefs`-backed with nothing to fake) still delegate to a
/// [LocationRepositoryFake] instance rather than duplicating that storage
/// code — only the two methods that actually talked to fixture data
/// (`search`, `reverseGeocode`) and the launch-city radius gate
/// (`isWithinServiceableBounds`) are overridden here.
final class LocationRepositoryMaptiler implements LocationRepository {
  /// [apiKey] is the shared MapTiler project key.
  LocationRepositoryMaptiler(Prefs prefs, {required String apiKey})
    : _geocoding = MapTilerGeocodingService(apiKey: apiKey),
      _local = LocationRepositoryFake(prefs);

  final MapTilerGeocodingService _geocoding;

  /// Backs the purely local methods — see class doc.
  final LocationRepositoryFake _local;

  @override
  Future<List<LocalitySuggestion>> search(String query) async {
    final places = await _geocoding.search(query);
    return [
      for (final place in places)
        LocalitySuggestion(
          id: 'geo_${place.latLng.latitude}_${place.latLng.longitude}',
          locality: place.locality,
          city: place.city,
          pincode: place.pincode,
          latLng: place.latLng,
        ),
    ];
  }

  @override
  Future<List<LocalitySuggestion>> popularLocalities() =>
      _local.popularLocalities();

  @override
  Future<List<ResolvedLocation>> recentLocations() => _local.recentLocations();

  @override
  Future<ResolvedLocation> reverseGeocode(
    LatLng latLng, {
    required LocationPrecision precision,
    required LocationSource source,
  }) async {
    final place = await _geocoding.reverseGeocode(latLng);
    if (place == null) {
      // MapTiler unreachable — degrade to the fixture's nearest-name
      // labelling rather than leaving the resolved card with no label at
      // all. The coordinate itself (what discovery actually filters on)
      // is unaffected either way.
      return _local.reverseGeocode(
        latLng,
        precision: precision,
        source: source,
      );
    }
    return ResolvedLocation(
      latLng: latLng,
      locality: place.locality,
      city: place.city,
      pincode: place.pincode,
      precision: precision,
      source: source,
    );
  }

  @override
  Future<bool> isWithinServiceableBounds(LatLng latLng) async =>
      // No single launch city anymore — a real shop registered anywhere
      // already has real bags in Supabase, so gating "Confirm location" to
      // a Bengaluru radius would make those shops permanently undiscoverable
      // from the customer app.
      true;

  @override
  Future<void> confirmLocation(ResolvedLocation location) =>
      _local.confirmLocation(location);

  @override
  Future<ResolvedLocation?> cachedLocation() => _local.cachedLocation();
}

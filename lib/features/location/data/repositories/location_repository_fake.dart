import 'dart:convert';

import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/location/domain/entities/locality_suggestion.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';
import 'package:surplus_marketplace/features/location/domain/repositories/location_repository.dart';

class _Fixture {
  const _Fixture(this.locality, this.pincode, this.latLng);

  final String locality;
  final String pincode;
  final LatLng latLng;
}

/// Stands in for the server (Phase 1 locked decision) using the launch
/// city's fixture data.
///
/// **Launch city: Bengaluru.** Unconfirmed by product as of Phase 9 (see
/// implementation log's open items, same status as D-23's placeholder bag
/// price) — chosen only because Phase 8 §8.9's own directory sketch already
/// names `bags_bengaluru.json` as the illustrative fixture file. Changing
/// city is a fixture-data change, not an architecture change.
final class LocationRepositoryFake implements LocationRepository {
  LocationRepositoryFake(this._prefs);

  final Prefs _prefs;

  static const _cachedLocationKey = 'location.cached';
  static const _recentLocationsKey = 'location.recent';
  static const _maxRecents = 5;

  static const _city = 'Bengaluru';
  static const _cityCenter = LatLng(latitude: 12.9716, longitude: 77.5946);

  /// Roughly the Bengaluru urban agglomeration. Broad on purpose — the
  /// service-area question here is "is this the launch city at all", not
  /// A11's ~5 km discovery radius (a separate, tunable config value).
  static const _serviceableRadiusMeters = 40000.0;

  static const _fixtures = [
    _Fixture(
      'Indiranagar',
      '560038',
      LatLng(latitude: 12.9719, longitude: 77.6412),
    ),
    _Fixture(
      'Koramangala',
      '560034',
      LatLng(latitude: 12.9352, longitude: 77.6245),
    ),
    _Fixture(
      'HSR Layout',
      '560102',
      LatLng(latitude: 12.9121, longitude: 77.6446),
    ),
    _Fixture(
      'Whitefield',
      '560066',
      LatLng(latitude: 12.9698, longitude: 77.7500),
    ),
    _Fixture(
      'Jayanagar',
      '560041',
      LatLng(latitude: 12.9250, longitude: 77.5938),
    ),
    _Fixture(
      'JP Nagar',
      '560078',
      LatLng(latitude: 12.9077, longitude: 77.5851),
    ),
    _Fixture(
      'Marathahalli',
      '560037',
      LatLng(latitude: 12.9591, longitude: 77.6974),
    ),
    _Fixture(
      'BTM Layout',
      '560068',
      LatLng(latitude: 12.9166, longitude: 77.6101),
    ),
    _Fixture(
      'Malleswaram',
      '560003',
      LatLng(latitude: 13.0027, longitude: 77.5697),
    ),
    _Fixture(
      'Rajajinagar',
      '560010',
      LatLng(latitude: 12.9915, longitude: 77.5551),
    ),
  ];

  /// Shown first, before any search, per §5a.4's empty-state table.
  static const _popularOrder = [
    'Indiranagar',
    'Koramangala',
    'HSR Layout',
    'Whitefield',
  ];

  @override
  Future<List<LocalitySuggestion>> search(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return [];
    return _fixtures
        .where(
          (f) =>
              f.locality.toLowerCase().contains(needle) ||
              f.pincode.startsWith(needle),
        )
        .map(_toSuggestion)
        .toList();
  }

  @override
  Future<List<LocalitySuggestion>> popularLocalities() async => [
    for (final name in _popularOrder)
      _toSuggestion(_fixtures.firstWhere((f) => f.locality == name)),
  ];

  @override
  Future<List<ResolvedLocation>> recentLocations() async {
    final raw = _prefs.getString(_recentLocationsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<Object?>;
    return list
        .map((e) => _decodeLocation(e! as Map<String, Object?>))
        .toList();
  }

  @override
  Future<ResolvedLocation> reverseGeocode(
    LatLng latLng, {
    required LocationPrecision precision,
    required LocationSource source,
  }) async {
    // The fixture data is local, so unlike a real geocoder it cannot go
    // down — the "geocoding service down" branch (§5a.4) has no meaning
    // until an HTTP LocationRepository exists to actually fail.
    final nearest = _fixtures.reduce(
      (a, b) =>
          latLng.distanceInMetersTo(a.latLng) <=
              latLng.distanceInMetersTo(b.latLng)
          ? a
          : b,
    );
    return ResolvedLocation(
      latLng: latLng,
      locality: nearest.locality,
      city: _city,
      pincode: precision == LocationPrecision.precise ? nearest.pincode : null,
      precision: precision,
      source: source,
    );
  }

  @override
  Future<bool> isWithinServiceableBounds(LatLng latLng) async =>
      latLng.distanceInMetersTo(_cityCenter) <= _serviceableRadiusMeters;

  @override
  Future<void> confirmLocation(ResolvedLocation location) async {
    await _prefs.setString(
      _cachedLocationKey,
      jsonEncode(_encodeLocation(location)),
    );
    final recents = await recentLocations();
    final deduped = [
      location,
      ...recents.where((r) => r.locality != location.locality),
    ].take(_maxRecents).toList();
    await _prefs.setString(
      _recentLocationsKey,
      jsonEncode(deduped.map(_encodeLocation).toList()),
    );
  }

  @override
  Future<ResolvedLocation?> cachedLocation() async {
    final raw = _prefs.getString(_cachedLocationKey);
    if (raw == null) return null;
    return _decodeLocation(jsonDecode(raw) as Map<String, Object?>);
  }

  LocalitySuggestion _toSuggestion(_Fixture f) => LocalitySuggestion(
    id: 'loc_${f.locality.toLowerCase().replaceAll(' ', '_')}',
    locality: f.locality,
    city: _city,
    pincode: f.pincode,
    latLng: f.latLng,
  );

  Map<String, Object?> _encodeLocation(ResolvedLocation location) => {
    'lat': location.latLng.latitude,
    'lng': location.latLng.longitude,
    'locality': location.locality,
    'city': location.city,
    'pincode': location.pincode,
    'precision': location.precision.name,
    'source': location.source.name,
  };

  ResolvedLocation _decodeLocation(Map<String, Object?> map) =>
      ResolvedLocation(
        latLng: LatLng(
          latitude: (map['lat']! as num).toDouble(),
          longitude: (map['lng']! as num).toDouble(),
        ),
        locality: map['locality']! as String,
        city: map['city']! as String,
        pincode: map['pincode'] as String?,
        // A value written by a future app version this build doesn't recognise
        // falls back conservatively to `approximate`/`cached`, the same
        // tolerant-decoding convention as `DietaryEnvelope.fromWire`.
        precision: LocationPrecision.values.firstWhere(
          (p) => p.name == map['precision'],
          orElse: () => LocationPrecision.approximate,
        ),
        source: LocationSource.values.firstWhere(
          (s) => s.name == map['source'],
          orElse: () => LocationSource.cached,
        ),
      );
}

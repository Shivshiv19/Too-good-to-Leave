import 'package:dio/dio.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';

/// One address match — either a forward-search hit or a reverse-geocode of
/// a coordinate. Deliberately shaped around what `ResolvedLocation`/
/// `LocalitySuggestion` need (`locality`/`city`/`pincode`), not a raw
/// passthrough of MapTiler's response.
class GeocodedPlace {
  /// See the individual field docs below for what each parameter means.
  const GeocodedPlace({
    required this.latLng,
    required this.locality,
    required this.city,
    this.pincode,
  });

  /// The matched coordinate.
  final LatLng latLng;

  /// Neighbourhood/area-level name — falls back to the feature's own name
  /// when the match itself is city-level (see
  /// [MapTilerGeocodingService._parseFeature]).
  final String locality;

  /// City/municipality-level name — falls back to [locality] when the
  /// match has no finer or broader admin-area context.
  final String city;

  /// Indian PIN code, when the match resolved to one.
  final String? pincode;

  /// `"$locality, $city"` — the same display shape `ResolvedLocation
  /// .displayLabel` uses.
  String get label => '$locality, $city';
}

/// [MapTiler's Geocoding API](https://docs.maptiler.com/cloud/api/geocoding/)
/// — same project/key as the tile layer (`MapTileConfig`). Replaces
/// `LocationRepositoryFake`'s Bengaluru-only fixture search now that shops
/// (and their real Supabase-backed bags) can register anywhere; biased to
/// India (`country=in`) since that's the only market this product serves.
class MapTilerGeocodingService {
  /// [apiKey] is the shared MapTiler project key — see `MapTileConfig`'s
  /// own doc for how it's supplied.
  MapTilerGeocodingService({required this.apiKey}) : _dio = Dio();

  /// The shared MapTiler project key.
  final String apiKey;

  final Dio _dio;

  static const _base = 'https://api.maptiler.com/geocoding';
  static const _timeout = Duration(seconds: 6);

  /// Forward search — e.g. a locality name typed into `/location-setup`'s
  /// search field. Empty results (network failure or a genuine no-match)
  /// are both a valid, silent empty list — the caller renders its own
  /// no-results state either way.
  Future<List<GeocodedPlace>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '$_base/${Uri.encodeComponent(trimmed)}.json',
        queryParameters: {
          'key': apiKey,
          'country': 'in',
          'limit': '8',
          'autocomplete': 'true',
        },
        options: Options(sendTimeout: _timeout, receiveTimeout: _timeout),
      );
      final features = response.data?['features'] as List<Object?>? ?? [];
      return features
          .map((f) => _parseFeature(f! as Map<String, Object?>))
          .whereType<GeocodedPlace>()
          .toList();
    } on Object {
      return [];
    }
  }

  /// Turns a coordinate (GPS fix or dropped pin) back into a locality/city
  /// label — used both for "Use current location" and the map pin picker.
  Future<GeocodedPlace?> reverseGeocode(LatLng point) async {
    try {
      final response = await _dio.get<Map<String, Object?>>(
        '$_base/${point.longitude},${point.latitude}.json',
        queryParameters: {'key': apiKey},
        options: Options(sendTimeout: _timeout, receiveTimeout: _timeout),
      );
      final features = response.data?['features'] as List<Object?>? ?? [];
      if (features.isEmpty) return null;
      return _parseFeature(features.first! as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  GeocodedPlace? _parseFeature(Map<String, Object?> feature) {
    final center = feature['center'] as List<Object?>?;
    if (center == null || center.length != 2) return null;
    final lng = (center[0]! as num).toDouble();
    final lat = (center[1]! as num).toDouble();

    final context = (feature['context'] as List<Object?>? ?? [])
        .cast<Map<String, Object?>>();
    String? contextText(String prefix) {
      for (final entry in context) {
        final id = entry['id'] as String?;
        if (id != null && id.startsWith(prefix)) {
          return entry['text'] as String?;
        }
      }
      return null;
    }

    // `municipality` is inconsistently named across OSM data — in
    // Bengaluru it's the clean city name ("Bengaluru"), but in Hyderabad
    // it's a ward-level body ("Greater Hyderabad Municipal Corporation
    // Central Zone"). Wherever a context entry is explicitly tagged
    // `place_designation: "city"` (regardless of its id prefix), trust
    // that over the id-prefix guess.
    String? explicitCity() {
      for (final entry in context) {
        if (entry['place_designation'] == 'city') {
          return entry['text'] as String?;
        }
      }
      return null;
    }

    final text = feature['text'] as String?;
    // Neighbourhood-level match (e.g. a street/POI search) gets its own
    // named locality from context; a city-level match (searching
    // "Hyderabad" itself) has no finer-grained context entry, so the
    // feature's own name *is* the locality.
    final locality =
        contextText('neighbourhood') ??
        contextText('subneighbourhood') ??
        contextText('place') ??
        text;
    if (locality == null) return null;
    final city =
        explicitCity() ??
        // `subregion` tends to hold the clean city name when nothing is
        // explicitly designated a city (as seen for Hyderabad, where
        // `municipality` is a ward-level body but `subregion` is just
        // "Hyderabad") — tried before the noisier `municipality` fallback.
        contextText('subregion') ??
        contextText('municipality') ??
        contextText('municipal_district') ??
        contextText('region') ??
        locality;

    return GeocodedPlace(
      latLng: LatLng(latitude: lat, longitude: lng),
      locality: locality,
      city: city,
      pincode: contextText('postal_code'),
    );
  }
}

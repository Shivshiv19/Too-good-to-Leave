import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One address match — either a forward-search hit or a reverse-geocode of
/// a dropped pin. `addressLine`/`locality` are best-effort splits of the
/// provider's formatted address, good enough to prefill the registration
/// form's fields (the owner can still edit them by hand).
class GeocodingResult {
  const GeocodingResult({
    required this.position,
    required this.label,
    this.addressLine,
    this.locality,
  });

  final LatLng position;
  final String label;
  final String? addressLine;
  final String? locality;
}

/// [MapTiler's Geocoding API](https://docs.maptiler.com/cloud/api/geocoding/)
/// — same project/key as the tile layer (`MapTilerTileConfig`), so no extra
/// credential to configure. Search is biased to India (`country=in`) since
/// the rest of this form — FSSAI licence, IFSC code, UPI ID — is India-only
/// anyway.
class MapTilerGeocodingService {
  const MapTilerGeocodingService({required this.apiKey});

  final String apiKey;

  static const _base = 'https://api.maptiler.com/geocoding';

  Future<List<GeocodingResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final uri = Uri.parse('$_base/${Uri.encodeComponent(trimmed)}.json')
        .replace(
          queryParameters: {
            'key': apiKey,
            'country': 'in',
            'limit': '6',
            'autocomplete': 'true',
          },
        );
    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final features = body['features'] as List<Object?>? ?? [];
      return features
          .map((f) => _parseFeature(f! as Map<String, Object?>))
          .whereType<GeocodingResult>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Turns a dropped pin back into an address — used when confirming the
  /// map picker, regardless of whether the pin got there via search or a
  /// manual drag.
  Future<GeocodingResult?> reverseGeocode(LatLng point) async {
    final uri =
        Uri.parse(
          '$_base/${point.longitude},${point.latitude}.json',
        ).replace(queryParameters: {'key': apiKey});
    try {
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final features = body['features'] as List<Object?>? ?? [];
      if (features.isEmpty) return null;
      return _parseFeature(features.first! as Map<String, Object?>);
    } catch (_) {
      return null;
    }
  }

  GeocodingResult? _parseFeature(Map<String, Object?> feature) {
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

    final placeName = feature['place_name'] as String?;
    final text = feature['text'] as String?;
    // `address` is a top-level field on the feature (not nested under
    // `properties`) with the actual street-level line (house/building
    // number, street) when present — `text` is often a duplicated
    // place/neighbourhood label (e.g. "Koramangala Koramangala 4th Block"),
    // which reads badly dropped straight into the Address field.
    final streetAddress = (feature['address'] as String?)
        ?.trim()
        .replaceAll(RegExp(r',\s*$'), '');

    return GeocodingResult(
      position: LatLng(lat, lng),
      label: placeName ?? text ?? '$lat, $lng',
      addressLine: (streetAddress != null && streetAddress.isNotEmpty)
          ? streetAddress
          : (text ?? placeName?.split(',').first.trim()),
      locality:
          contextText('neighbourhood') ??
          contextText('subneighbourhood') ??
          contextText('place'),
    );
  }
}

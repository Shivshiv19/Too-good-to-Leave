import 'package:surplus_marketplace/core/domain/lat_lng.dart';

/// One row of a search/autocomplete or "popular in the launch city" result
/// (§5a.4). Resolving a suggestion into a [ResolvedLocation] is a repository
/// call (reverse-lookup is not needed — the fixture/server already knows the
/// coordinate), not a client-side computation.
final class LocalitySuggestion {
  const LocalitySuggestion({
    required this.id,
    required this.locality,
    required this.city,
    required this.latLng,
    this.pincode,
  });

  final String id;
  final String locality;
  final String city;
  final String? pincode;
  final LatLng latLng;

  String get label => '$locality, $city';
}

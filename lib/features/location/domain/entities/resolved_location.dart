import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';

/// A discovery anchor (§5a.4) — deliberately lighter than the full postal
/// `Address` (§2.1, `landmark` required): this is "where to look for food",
/// not a pickup-precise address, so it never asks for a landmark or a
/// house/floor number.
final class ResolvedLocation {
  const ResolvedLocation({
    required this.latLng,
    required this.locality,
    required this.city,
    required this.precision,
    required this.source,
    this.pincode,
  });

  final LatLng latLng;
  final String locality;
  final String city;
  final String? pincode;
  final LocationPrecision precision;
  final LocationSource source;

  /// What to render (§5a.4's validation rule): street-level text is never
  /// shown for an approximate fix, since reverse-geocoding a coarse
  /// coordinate into a confident address is a lie the user will act on.
  String get displayLabel => '$locality, $city';
}

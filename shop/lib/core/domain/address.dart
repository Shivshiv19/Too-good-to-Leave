import 'package:too_good_to_leave_shop/core/domain/lat_lng.dart';

/// A merchant's (or, later, a pickup point's) postal address (Phase 2 §2.1).
///
/// Hand-written per D-1. **`landmark` is required** — Indian addressing is
/// landmark-based, and pickup-only makes "find the shop" the whole
/// experience, so a listing without one is unconstructable rather than
/// silently shipping an address a customer can't actually use to find the
/// place.
final class Address {
  const Address({
    required this.line1,
    required this.landmark,
    required this.locality,
    required this.city,
    required this.state,
    required this.pincode,
    required this.geo,
    this.line2,
    this.floorOrShopNo,
  });

  final String line1;
  final String? line2;
  final String? floorOrShopNo;
  final String landmark;
  final String locality;
  final String city;
  final String state;
  final String pincode;
  final LatLng geo;

  /// A single line suitable for a detail screen — floor/shop and landmark
  /// first, since those are what a person standing outside actually needs
  /// (§5b.8/§5b.9).
  String get displayLine {
    final parts = [
      if (floorOrShopNo != null) floorOrShopNo,
      line1,
      if (line2 != null) line2,
      'near $landmark',
      locality,
      city,
    ];
    return parts.join(', ');
  }

  @override
  bool operator ==(Object other) =>
      other is Address &&
      other.line1 == line1 &&
      other.line2 == line2 &&
      other.floorOrShopNo == floorOrShopNo &&
      other.landmark == landmark &&
      other.locality == locality &&
      other.city == city &&
      other.state == state &&
      other.pincode == pincode &&
      other.geo == geo;

  @override
  int get hashCode => Object.hash(
    line1,
    line2,
    floorOrShopNo,
    landmark,
    locality,
    city,
    state,
    pincode,
    geo,
  );
}

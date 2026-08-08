import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A WGS-84 coordinate pair (Phase 2 §2.1). Hand-written per D-1 — no
/// behaviour here needs `freezed`'s generated `copyWith`.
@immutable
final class LatLng {
  const LatLng({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  static const _earthRadiusMeters = 6371000.0;

  /// Great-circle distance to [other], in meters (haversine formula).
  ///
  /// Used for the serviceable-bounds check (§5a.4) rather than a flat
  /// lat/lng delta — India spans enough latitude that a naive delta would
  /// misjudge distance by a meaningful margin.
  double distanceInMetersTo(LatLng other) {
    final dLat = _radians(other.latitude - latitude);
    final dLng = _radians(other.longitude - longitude);
    final lat1 = _radians(latitude);
    final lat2 = _radians(other.latitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is LatLng &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

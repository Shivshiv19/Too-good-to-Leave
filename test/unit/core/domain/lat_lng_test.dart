import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';

void main() {
  group('LatLng', () {
    test('distanceInMetersTo is zero for the same point', () {
      const point = LatLng(latitude: 12.9716, longitude: 77.5946);
      expect(point.distanceInMetersTo(point), 0);
    });

    test('distanceInMetersTo matches a known great-circle distance', () {
      // Bengaluru city centre to Indiranagar — a well-known ~7.5 km hop,
      // used here as a sanity check on the haversine implementation rather
      // than an exact-match assertion.
      const bengaluru = LatLng(latitude: 12.9716, longitude: 77.5946);
      const indiranagar = LatLng(latitude: 12.9719, longitude: 77.6412);
      final distance = bengaluru.distanceInMetersTo(indiranagar);
      expect(distance, greaterThan(4000));
      expect(distance, lessThan(6000));
    });

    test('distanceInMetersTo is symmetric', () {
      const a = LatLng(latitude: 12.9716, longitude: 77.5946);
      const b = LatLng(latitude: 13.0827, longitude: 80.2707); // Chennai
      expect(a.distanceInMetersTo(b), a.distanceInMetersTo(b));
    });

    test('equality is value-based', () {
      const a = LatLng(latitude: 1, longitude: 2);
      const b = LatLng(latitude: 1, longitude: 2);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}

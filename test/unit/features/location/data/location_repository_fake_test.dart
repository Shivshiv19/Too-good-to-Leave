import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/location/data/repositories/location_repository_fake.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';

Future<LocationRepositoryFake> _repository() async {
  SharedPreferences.setMockInitialValues({});
  return LocationRepositoryFake(await Prefs.open());
}

void main() {
  group('LocationRepositoryFake — search', () {
    test('matches a locality name case-insensitively', () async {
      final repo = await _repository();
      final results = await repo.search('koramangala');
      expect(results, hasLength(1));
      expect(results.single.locality, 'Koramangala');
    });

    test('matches a pincode prefix', () async {
      final repo = await _repository();
      final results = await repo.search('56000');
      expect(results.map((r) => r.locality), contains('Malleswaram'));
    });

    test(
      "an empty query returns no results (never a blank starting point "
      "is the screen's job, not search's)",
      () async {
        final repo = await _repository();
        expect(await repo.search(''), isEmpty);
      },
    );

    test('an unmatched query returns an empty list, not an error', () async {
      final repo = await _repository();
      expect(await repo.search('Timbuktu'), isEmpty);
    });
  });

  group('LocationRepositoryFake — popular localities', () {
    test('returns a non-empty, stable-ordered fallback list', () async {
      final repo = await _repository();
      final popular = await repo.popularLocalities();
      expect(popular, isNotEmpty);
      expect(popular.first.locality, 'Indiranagar');
    });
  });

  group('LocationRepositoryFake — serviceable bounds', () {
    test('a point inside the launch city is serviceable', () async {
      final repo = await _repository();
      const koramangala = LatLng(latitude: 12.9352, longitude: 77.6245);
      expect(await repo.isWithinServiceableBounds(koramangala), isTrue);
    });

    test('a point in a different city is not serviceable', () async {
      final repo = await _repository();
      const mumbai = LatLng(latitude: 19.0760, longitude: 72.8777);
      expect(await repo.isWithinServiceableBounds(mumbai), isFalse);
    });
  });

  group('LocationRepositoryFake — reverse geocoding', () {
    test('a precise fix carries a pincode', () async {
      final repo = await _repository();
      const nearIndiranagar = LatLng(latitude: 12.972, longitude: 77.641);
      final resolved = await repo.reverseGeocode(
        nearIndiranagar,
        precision: LocationPrecision.precise,
        source: LocationSource.gps,
      );
      expect(resolved.locality, 'Indiranagar');
      expect(resolved.pincode, isNotNull);
    });

    test(
      'an approximate fix never claims a street-level pincode (§5a.4 — '
      'display precision must not exceed granted precision)',
      () async {
        final repo = await _repository();
        const nearIndiranagar = LatLng(latitude: 12.972, longitude: 77.641);
        final resolved = await repo.reverseGeocode(
          nearIndiranagar,
          precision: LocationPrecision.approximate,
          source: LocationSource.gps,
        );
        expect(resolved.pincode, isNull);
      },
    );
  });

  group('LocationRepositoryFake — confirm/cache/recents', () {
    test('cachedLocation is null before any confirmation', () async {
      final repo = await _repository();
      expect(await repo.cachedLocation(), isNull);
    });

    test('confirmLocation persists the cached location', () async {
      final repo = await _repository();
      final location = ResolvedLocation(
        latLng: const LatLng(latitude: 12.9352, longitude: 77.6245),
        locality: 'Koramangala',
        city: 'Bengaluru',
        pincode: '560034',
        precision: LocationPrecision.precise,
        source: LocationSource.search,
      );
      await repo.confirmLocation(location);
      final cached = await repo.cachedLocation();
      expect(cached, isNotNull);
      expect(cached!.locality, 'Koramangala');
    });

    test('confirmLocation adds to recents, most recent first, deduped by '
        'locality', () async {
      final repo = await _repository();
      final koramangala = ResolvedLocation(
        latLng: const LatLng(latitude: 12.9352, longitude: 77.6245),
        locality: 'Koramangala',
        city: 'Bengaluru',
        precision: LocationPrecision.precise,
        source: LocationSource.search,
      );
      final indiranagar = ResolvedLocation(
        latLng: const LatLng(latitude: 12.9719, longitude: 77.6412),
        locality: 'Indiranagar',
        city: 'Bengaluru',
        precision: LocationPrecision.precise,
        source: LocationSource.search,
      );

      await repo.confirmLocation(koramangala);
      await repo.confirmLocation(indiranagar);
      await repo.confirmLocation(koramangala);

      final recents = await repo.recentLocations();
      expect(recents.map((r) => r.locality), ['Koramangala', 'Indiranagar']);
    });

    test(
      'a confirmed location survives a fresh Prefs instance (simulates app '
      'restart)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final first = LocationRepositoryFake(await Prefs.open());
        await first.confirmLocation(
          ResolvedLocation(
            latLng: const LatLng(latitude: 12.9352, longitude: 77.6245),
            locality: 'Koramangala',
            city: 'Bengaluru',
            precision: LocationPrecision.precise,
            source: LocationSource.search,
          ),
        );

        final second = LocationRepositoryFake(await Prefs.open());
        final cached = await second.cachedLocation();
        expect(cached, isNotNull);
        expect(cached!.locality, 'Koramangala');
      },
    );
  });
}

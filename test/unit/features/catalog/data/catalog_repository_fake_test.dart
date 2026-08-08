import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/catalog/data/repositories/catalog_repository_fake.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/coverage_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_query.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_sort.dart';

const _bengaluru = LatLng(latitude: 12.9716, longitude: 77.5946);
const _mumbai = LatLng(latitude: 19.0760, longitude: 72.8777);

Future<CatalogRepositoryFake> _repository({
  Clock clock = const FixedClock2(),
}) async {
  SharedPreferences.setMockInitialValues({});
  return CatalogRepositoryFake(prefs: await Prefs.open(), clock: clock);
}

/// A clock fixed inside every fixture bag's pickup window, so urgency-
/// dependent behaviour (sections, `availableNow`) is deterministic.
class FixedClock2 implements Clock {
  const FixedClock2();

  @override
  DateTime now() => DateTime.now().copyWith(hour: 20, minute: 30);
}

extension on DateTime {
  DateTime copyWith({int? hour, int? minute}) =>
      DateTime(year, month, day, hour ?? this.hour, minute ?? this.minute);
}

void main() {
  group('CatalogRepositoryFake — discoverBags', () {
    test('returns only live bags within the default 5 km radius', () async {
      final repo = await _repository();
      final page = await repo.discoverBags(
        DiscoverQuery(anchor: _bengaluru),
      );
      expect(page.items, isNotEmpty);
      expect(page.items.every((b) => b.distanceMetres <= 5000), isTrue);
    });

    test('filters by accepted dietary envelopes (A7)', () async {
      final repo = await _repository();
      final page = await repo.discoverBags(
        DiscoverQuery(
          anchor: _bengaluru,
          radiusKm: 20,
          acceptedEnvelopes: const {DietaryEnvelope.jain},
        ),
      );
      expect(
        page.items.every((b) => b.dietaryEnvelope == DietaryEnvelope.jain),
        isTrue,
      );
    });

    test('filters by category', () async {
      final repo = await _repository();
      final page = await repo.discoverBags(
        DiscoverQuery(
          anchor: _bengaluru,
          radiusKm: 20,
          categories: const {'cat_bakery'},
        ),
      );
      expect(
        page.items.every((b) => b.merchant.category == 'cat_bakery'),
        isTrue,
      );
    });

    test('filters by minimum rating', () async {
      final repo = await _repository();
      final page = await repo.discoverBags(
        DiscoverQuery(anchor: _bengaluru, radiusKm: 20, minRating: 5),
      );
      expect(page.items, isEmpty);
    });

    test('an empty result is a valid page, not an error', () async {
      final repo = await _repository();
      final page = await repo.discoverBags(
        DiscoverQuery(anchor: _mumbai, radiusKm: 5),
      );
      expect(page.items, isEmpty);
    });

    test('sort by priceAsc orders ascending', () async {
      final repo = await _repository();
      final page = await repo.discoverBags(
        DiscoverQuery(
          anchor: _bengaluru,
          radiusKm: 20,
          sort: DiscoverSort.priceAsc,
        ),
      );
      final prices = page.items.map((b) => b.price.amountInPaise).toList();
      expect(prices, [...prices]..sort());
    });
  });

  group('CatalogRepositoryFake — bag/merchant lookups', () {
    test('bag() returns the exact fixture bag by id', () async {
      final repo = await _repository();
      final bag = await repo.bag('bag_sc_1');
      expect(bag.merchantId, 'mer_sweetcrumb');
    });

    test('bag() throws NotFoundException for an unknown id', () async {
      final repo = await _repository();
      await expectLater(
        repo.bag('bag_does_not_exist'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('merchant() throws NotFoundException for an unknown id', () async {
      final repo = await _repository();
      await expectLater(
        repo.merchant('mer_does_not_exist'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test("merchantBags() returns only that merchant's live bags", () async {
      final repo = await _repository();
      final bags = await repo.merchantBags('mer_sweetcrumb', _bengaluru);
      expect(bags, isNotEmpty);
      expect(bags.every((b) => b.merchant.id == 'mer_sweetcrumb'), isTrue);
    });
  });

  group('CatalogRepositoryFake — coverage (A10)', () {
    test('a point far outside the launch city is noCoverage', () async {
      final repo = await _repository();
      final status = await repo.coverage(_mumbai);
      expect(status, isA<CoverageNoCoverage>());
    });

    test('a point inside the launch city with nearby bags is live', () async {
      final repo = await _repository();
      final status = await repo.coverage(_bengaluru);
      expect(status, isA<CoverageLive>());
    });
  });

  group('CatalogRepositoryFake — search (D-b4)', () {
    test('matches a merchant by name', () async {
      final repo = await _repository();
      final results = await repo.search('Sweet Crumb', _bengaluru);
      expect(
        results.merchants.map((m) => m.merchant.id),
        contains('mer_sweetcrumb'),
      );
    });

    test('an empty query returns no merchants', () async {
      final repo = await _repository();
      final results = await repo.search('', _bengaluru);
      expect(results.merchants, isEmpty);
    });
  });

  group('CatalogRepositoryFake — saved/watch toggles', () {
    test('a merchant is not saved or watched by default', () async {
      final repo = await _repository();
      expect(await repo.isMerchantSaved('mer_sweetcrumb'), isFalse);
      expect(await repo.isMerchantWatched('mer_sweetcrumb'), isFalse);
    });

    test('setMerchantSaved persists true then false', () async {
      final repo = await _repository();
      await repo.setMerchantSaved('mer_sweetcrumb', saved: true);
      expect(await repo.isMerchantSaved('mer_sweetcrumb'), isTrue);
      await repo.setMerchantSaved('mer_sweetcrumb', saved: false);
      expect(await repo.isMerchantSaved('mer_sweetcrumb'), isFalse);
    });

    test('setMerchantWatched persists true then false', () async {
      final repo = await _repository();
      await repo.setMerchantWatched('mer_sweetcrumb', watched: true);
      expect(await repo.isMerchantWatched('mer_sweetcrumb'), isTrue);
      await repo.setMerchantWatched('mer_sweetcrumb', watched: false);
      expect(await repo.isMerchantWatched('mer_sweetcrumb'), isFalse);
    });

    test(
      'amendment A17 — watching an unsaved merchant saves it too',
      () async {
        final repo = await _repository();
        expect(await repo.isMerchantSaved('mer_sweetcrumb'), isFalse);
        await repo.setMerchantWatched('mer_sweetcrumb', watched: true);
        expect(await repo.isMerchantSaved('mer_sweetcrumb'), isTrue);
      },
    );

    test('amendment A17 — unsaving clears the watch too', () async {
      final repo = await _repository();
      await repo.setMerchantWatched('mer_sweetcrumb', watched: true);
      expect(await repo.isMerchantWatched('mer_sweetcrumb'), isTrue);
      await repo.setMerchantSaved('mer_sweetcrumb', saved: false);
      expect(await repo.isMerchantWatched('mer_sweetcrumb'), isFalse);
    });

    test('savedMerchants returns every merchant currently saved', () async {
      final repo = await _repository();
      expect(await repo.savedMerchants(), isEmpty);
      await repo.setMerchantSaved('mer_sweetcrumb', saved: true);
      final saved = await repo.savedMerchants();
      expect(saved.map((m) => m.id), contains('mer_sweetcrumb'));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/features/config/data/repositories/config_repository_fake.dart';

void main() {
  final repository = ConfigRepositoryFake();

  group('ConfigRepositoryFake', () {
    test('fetchConfig decodes the fixture through the DTO pipeline', () async {
      final config = await repository.fetchConfig();

      expect(config.minSupportedAppVersion, '0.0.1');
      expect(config.maintenance.active, isFalse);
      expect(config.policyValues.purchaseCapPerListing, 2);
      expect(config.policyValues.holdTtl, const Duration(seconds: 540));
    });

    test('fetchTaxonomy decodes categories and food types', () async {
      final taxonomy = await repository.fetchTaxonomy();

      expect(taxonomy.categories, isNotEmpty);
      expect(taxonomy.foodTypes, isNotEmpty);
      expect(
        taxonomy.categories.map((c) => c.id),
        contains('cat_bakery'),
      );
    });

    test('bundledFallbackTaxonomy matches fetchTaxonomy (§7.3)', () async {
      final fetched = await repository.fetchTaxonomy();
      final fallback = repository.bundledFallbackTaxonomy;

      expect(fallback.categories.length, fetched.categories.length);
      expect(fallback.foodTypes.length, fetched.foodTypes.length);
    });
  });
}

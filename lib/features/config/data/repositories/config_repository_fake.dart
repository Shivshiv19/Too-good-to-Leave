import 'package:surplus_marketplace/features/config/data/dto/remote_config_dto.dart';
import 'package:surplus_marketplace/features/config/data/dto/taxonomy_dto.dart';
import 'package:surplus_marketplace/features/config/data/mappers/config_mapper.dart';
import 'package:surplus_marketplace/features/config/domain/entities/remote_config.dart';
import 'package:surplus_marketplace/features/config/domain/entities/taxonomy.dart';
import 'package:surplus_marketplace/features/config/domain/repositories/config_repository.dart';

/// Stands in for the server in the `dev` flavour (Phase 1 locked decision;
/// Phase 8 §8.6).
///
/// Fixtures are authored as raw JSON [Map]s run through the same
/// `fromJson` → [ConfigMapper] pipeline the HTTP binding will use, rather
/// than constructed as domain objects directly. A fake that skipped decoding
/// would stop exercising the DTOs the moment a real backend existed to
/// exercise them against, which defeats the point of building against fakes
/// first.
final class ConfigRepositoryFake implements ConfigRepository {
  @override
  Future<RemoteConfig> fetchConfig() async {
    final dto = RemoteConfigDto.fromJson(_configJson);
    return ConfigMapper.remoteConfigFromDto(dto);
  }

  @override
  Future<Taxonomy> fetchTaxonomy() async {
    final dto = TaxonomyDto.fromJson(_taxonomyJson);
    return ConfigMapper.taxonomyFromDto(dto);
  }

  /// The bundled fallback taxonomy shipped for a cold first launch on a dead
  /// network (§7.3). Identical to [fetchTaxonomy] here because the fake has
  /// no network to be dead; the HTTP binding is where this fixture earns its
  /// name.
  Taxonomy get bundledFallbackTaxonomy =>
      ConfigMapper.taxonomyFromDto(TaxonomyDto.fromJson(_taxonomyJson));

  static final Map<String, dynamic> _configJson = {
    // Deliberately far below pubspec.yaml's current version (0.1.0) — a dev
    // fixture that force-updates the app against its own fake data on every
    // normal run is a self-inflicted bug, not a test of the force-update
    // path. Bump this only to deliberately exercise that path.
    'minSupportedAppVersion': '0.0.1',
    'maintenance': {'active': false, 'etaAt': null},
    'featureFlags': <String, bool>{},
    'policyValues': {
      'cancellationCutoffMinutesBeforeWindow': 60,
      'noShowRefundPolicy': 'none',
      'refundSlaWorkingDays': {'min': 3, 'max': 7},
      'grievanceSlaHours': 48,
      'purchaseCapPerListing': 2,
      'holdTtlSeconds': 540,
      'grievanceOfficer': {
        'name': 'Priya Sharma',
        'designation': 'Grievance Officer',
        'email': 'grievance@surplusmarketplace.example',
        'phone': '+91 80 4567 8900',
        'address': '4th Floor, Prestige Tech Park, Bengaluru, Karnataka 560103',
      },
    },
    'taxonomyEtag': '"tx_44f1"',
  };

  static final Map<String, dynamic> _taxonomyJson = {
    'categories': [
      {
        'id': 'cat_bakery',
        'label': 'Bakery',
        'iconKey': 'bakery',
        'sortOrder': 0,
      },
      {'id': 'cat_cafe', 'label': 'Cafe', 'iconKey': 'cafe', 'sortOrder': 1},
      {
        'id': 'cat_restaurant',
        'label': 'Restaurant',
        'iconKey': 'restaurant',
        'sortOrder': 2,
      },
    ],
    'foodTypes': [
      {'id': 'food_meals', 'label': 'Meals', 'iconKey': 'meal', 'sortOrder': 0},
      {
        'id': 'food_bakery',
        'label': 'Bakery items',
        'iconKey': 'bakery',
        'sortOrder': 1,
      },
      {
        'id': 'food_groceries',
        'label': 'Groceries',
        'iconKey': 'groceries',
        'sortOrder': 2,
      },
    ],
  };
}

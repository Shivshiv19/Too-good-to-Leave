import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/features/config/data/dto/policy_values_dto.dart';
import 'package:surplus_marketplace/features/config/data/dto/remote_config_dto.dart';
import 'package:surplus_marketplace/features/config/data/dto/taxonomy_dto.dart';
import 'package:surplus_marketplace/features/config/data/mappers/config_mapper.dart';

void main() {
  group('ConfigMapper.remoteConfigFromDto (Phase 7 §7.3 sample payload)', () {
    final dto = RemoteConfigDto.fromJson({
      'minSupportedAppVersion': '1.0.0',
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
          'email': 'grievance@example.com',
          'phone': '+91 80 4567 8900',
          'address': 'Bengaluru, Karnataka',
        },
      },
      'taxonomyEtag': '"tx_44f1"',
    });

    final config = ConfigMapper.remoteConfigFromDto(dto);

    test('converts every policy unit to its Duration/range', () {
      expect(
        config.policyValues.cancellationCutoffBeforeWindow,
        const Duration(minutes: 60),
      );
      expect(config.policyValues.refundSlaWorkingDays, (min: 3, max: 7));
      expect(config.policyValues.grievanceSla, const Duration(hours: 48));
      expect(config.policyValues.holdTtl, const Duration(seconds: 540));
      expect(config.policyValues.purchaseCapPerListing, 2);
      expect(config.policyValues.noShowRefundPolicy, 'none');
    });

    test('passes through version, flags, and taxonomy etag unchanged', () {
      expect(config.minSupportedAppVersion, '1.0.0');
      expect(config.featureFlags, isEmpty);
      expect(config.taxonomyEtag, '"tx_44f1"');
    });

    test('maps a null maintenance ETA to null, not a parse error', () {
      expect(config.maintenance.active, isFalse);
      expect(config.maintenance.etaAt, isNull);
    });

    test('parses a present maintenance ETA', () {
      final withEta = ConfigMapper.remoteConfigFromDto(
        RemoteConfigDto.fromJson({
          'minSupportedAppVersion': '1.0.0',
          'maintenance': {
            'active': true,
            'etaAt': '2026-08-01T09:00:00.000Z',
          },
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
              'email': 'grievance@example.com',
              'phone': '+91 80 4567 8900',
              'address': 'Bengaluru, Karnataka',
            },
          },
          'taxonomyEtag': '"tx_1"',
        }),
      );
      expect(withEta.maintenance.active, isTrue);
      expect(
        withEta.maintenance.etaAt,
        DateTime.parse('2026-08-01T09:00:00.000Z'),
      );
    });
  });

  group('ConfigMapper.taxonomyFromDto', () {
    test('maps categories and food types independently', () {
      final dto = TaxonomyDto.fromJson({
        'categories': [
          {
            'id': 'cat_bakery',
            'label': 'Bakery',
            'iconKey': 'bakery',
            'sortOrder': 0,
          },
        ],
        'foodTypes': [
          {
            'id': 'food_meals',
            'label': 'Meals',
            'iconKey': 'meal',
            'sortOrder': 0,
          },
        ],
      });

      final taxonomy = ConfigMapper.taxonomyFromDto(dto);

      expect(taxonomy.categories, hasLength(1));
      expect(taxonomy.categories.single.id, 'cat_bakery');
      expect(taxonomy.foodTypes, hasLength(1));
      expect(taxonomy.foodTypes.single.id, 'food_meals');
    });
  });

  test('PolicyValuesDto round-trips through fromJson', () {
    final dto = PolicyValuesDto.fromJson({
      'cancellationCutoffMinutesBeforeWindow': 60,
      'noShowRefundPolicy': 'none',
      'refundSlaWorkingDays': {'min': 3, 'max': 7},
      'grievanceSlaHours': 48,
      'purchaseCapPerListing': 2,
      'holdTtlSeconds': 540,
      'grievanceOfficer': {
        'name': 'Priya Sharma',
        'designation': 'Grievance Officer',
        'email': 'grievance@example.com',
        'phone': '+91 80 4567 8900',
        'address': 'Bengaluru, Karnataka',
      },
    });
    expect(dto.holdTtlSeconds, 540);
    expect(dto.refundSlaWorkingDays.min, 3);
  });
}

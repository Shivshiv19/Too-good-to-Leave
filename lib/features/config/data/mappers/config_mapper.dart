import 'package:surplus_marketplace/core/domain/grievance_officer.dart';
import 'package:surplus_marketplace/features/config/data/dto/policy_values_dto.dart';
import 'package:surplus_marketplace/features/config/data/dto/remote_config_dto.dart';
import 'package:surplus_marketplace/features/config/data/dto/taxonomy_dto.dart';
import 'package:surplus_marketplace/features/config/domain/entities/maintenance_status.dart';
import 'package:surplus_marketplace/features/config/domain/entities/policy_values.dart';
import 'package:surplus_marketplace/features/config/domain/entities/remote_config.dart';
import 'package:surplus_marketplace/features/config/domain/entities/taxonomy.dart';

/// DTO → domain conversion for the `config` feature.
///
/// Pure functions, unit-tested independently of any repository. Every wire
/// unit (minutes, hours, seconds) is converted to a [Duration] exactly once,
/// here — a screen or provider that reached for
/// `policyValuesDto.holdTtlSeconds` directly would have re-derived a unit
/// conversion the mapper already owns.
abstract final class ConfigMapper {
  static RemoteConfig remoteConfigFromDto(RemoteConfigDto dto) => RemoteConfig(
    minSupportedAppVersion: dto.minSupportedAppVersion,
    maintenance: MaintenanceStatus(
      active: dto.maintenance.active,
      etaAt: dto.maintenance.etaAt == null
          ? null
          : DateTime.parse(dto.maintenance.etaAt!),
    ),
    featureFlags: dto.featureFlags,
    policyValues: policyValuesFromDto(dto.policyValues),
    taxonomyEtag: dto.taxonomyEtag,
  );

  static PolicyValues policyValuesFromDto(PolicyValuesDto dto) => PolicyValues(
    cancellationCutoffBeforeWindow: Duration(
      minutes: dto.cancellationCutoffMinutesBeforeWindow,
    ),
    noShowRefundPolicy: dto.noShowRefundPolicy,
    refundSlaWorkingDays: (
      min: dto.refundSlaWorkingDays.min,
      max: dto.refundSlaWorkingDays.max,
    ),
    grievanceSla: Duration(hours: dto.grievanceSlaHours),
    purchaseCapPerListing: dto.purchaseCapPerListing,
    holdTtl: Duration(seconds: dto.holdTtlSeconds),
    grievanceOfficer: GrievanceOfficer(
      name: dto.grievanceOfficer.name,
      designation: dto.grievanceOfficer.designation,
      email: dto.grievanceOfficer.email,
      phone: dto.grievanceOfficer.phone,
      address: dto.grievanceOfficer.address,
    ),
  );

  static Taxonomy taxonomyFromDto(TaxonomyDto dto) => Taxonomy(
    categories: dto.categories.map(_tagFromDto).toList(),
    foodTypes: dto.foodTypes.map(_tagFromDto).toList(),
  );

  static TaxonomyTag _tagFromDto(TaxonomyTagDto dto) => TaxonomyTag(
    id: dto.id,
    label: dto.label,
    iconKey: dto.iconKey,
    sortOrder: dto.sortOrder,
  );
}

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:surplus_marketplace/features/config/data/dto/policy_values_dto.dart';

part 'remote_config_dto.freezed.dart';
part 'remote_config_dto.g.dart';

/// Wire shape of `GET /v1/config` (Phase 7 §7.3), unmapped.
@freezed
abstract class RemoteConfigDto with _$RemoteConfigDto {
  const factory RemoteConfigDto({
    required String minSupportedAppVersion,
    required MaintenanceDto maintenance,
    required Map<String, bool> featureFlags,
    required PolicyValuesDto policyValues,
    required String taxonomyEtag,
  }) = _RemoteConfigDto;

  factory RemoteConfigDto.fromJson(Map<String, dynamic> json) =>
      _$RemoteConfigDtoFromJson(json);
}

/// `maintenance: { active, etaAt }` (Phase 7 §7.3).
@freezed
abstract class MaintenanceDto with _$MaintenanceDto {
  const factory MaintenanceDto({required bool active, String? etaAt}) =
      _MaintenanceDto;

  factory MaintenanceDto.fromJson(Map<String, dynamic> json) =>
      _$MaintenanceDtoFromJson(json);
}

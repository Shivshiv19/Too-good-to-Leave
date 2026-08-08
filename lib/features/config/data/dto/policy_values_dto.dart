import 'package:freezed_annotation/freezed_annotation.dart';

part 'policy_values_dto.freezed.dart';
part 'policy_values_dto.g.dart';

/// Wire shape of `policyValues` inside `GET /v1/config` (Phase 7 §7.3).
///
/// Raw wire units (minutes, hours, seconds) on purpose — the conversion to
/// [Duration] belongs in `ConfigMapper`, not here, so the DTO stays a literal
/// mirror of the JSON and every unit conversion lives in one reviewable
/// place.
@freezed
abstract class PolicyValuesDto with _$PolicyValuesDto {
  const factory PolicyValuesDto({
    required int cancellationCutoffMinutesBeforeWindow,
    required String noShowRefundPolicy,
    required RefundSlaDto refundSlaWorkingDays,
    required int grievanceSlaHours,
    required int purchaseCapPerListing,
    required int holdTtlSeconds,
    required GrievanceOfficerDto grievanceOfficer,
  }) = _PolicyValuesDto;

  factory PolicyValuesDto.fromJson(Map<String, dynamic> json) =>
      _$PolicyValuesDtoFromJson(json);
}

/// `refundSlaWorkingDays: { min, max }` (Phase 7 §7.3).
@freezed
abstract class RefundSlaDto with _$RefundSlaDto {
  const factory RefundSlaDto({required int min, required int max}) =
      _RefundSlaDto;

  factory RefundSlaDto.fromJson(Map<String, dynamic> json) =>
      _$RefundSlaDtoFromJson(json);
}

/// **Amendment A19** — the one wire shape for the grievance officer's
/// identity (§5f.8, §5f.9).
@freezed
abstract class GrievanceOfficerDto with _$GrievanceOfficerDto {
  const factory GrievanceOfficerDto({
    required String name,
    required String designation,
    required String email,
    required String phone,
    required String address,
  }) = _GrievanceOfficerDto;

  factory GrievanceOfficerDto.fromJson(Map<String, dynamic> json) =>
      _$GrievanceOfficerDtoFromJson(json);
}

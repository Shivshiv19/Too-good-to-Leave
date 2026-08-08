import 'package:freezed_annotation/freezed_annotation.dart';

part 'taxonomy_dto.freezed.dart';
part 'taxonomy_dto.g.dart';

/// Wire shape of `GET /v1/config/taxonomy` (Phase 7 §7.3).
@freezed
abstract class TaxonomyDto with _$TaxonomyDto {
  const factory TaxonomyDto({
    required List<TaxonomyTagDto> categories,
    required List<TaxonomyTagDto> foodTypes,
  }) = _TaxonomyDto;

  factory TaxonomyDto.fromJson(Map<String, dynamic> json) =>
      _$TaxonomyDtoFromJson(json);
}

/// One category or food-type entry (Phase 2 §2.3).
@freezed
abstract class TaxonomyTagDto with _$TaxonomyTagDto {
  const factory TaxonomyTagDto({
    required String id,
    required String label,
    required String iconKey,
    required int sortOrder,
  }) = _TaxonomyTagDto;

  factory TaxonomyTagDto.fromJson(Map<String, dynamic> json) =>
      _$TaxonomyTagDtoFromJson(json);
}

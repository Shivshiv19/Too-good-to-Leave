import 'package:freezed_annotation/freezed_annotation.dart';

part 'taxonomy.freezed.dart';

/// A merchant category or food-type tag, server-driven (Phase 2 §2.3).
///
/// **Deliberately data-only**, unlike [DietaryEnvelope]: the taxonomy is
/// display metadata with no domain logic attached, so it carries no legal
/// weight and is safe to extend from the server without a client release.
@freezed
abstract class TaxonomyTag with _$TaxonomyTag {
  const factory TaxonomyTag({
    required String id,
    required String label,
    required String iconKey,
    required int sortOrder,
  }) = _TaxonomyTag;
}

/// The full server-driven taxonomy (Phase 2 §2.3, Phase 7 §7.3).
///
/// A bundled fallback ships with the app for a cold first launch on a dead
/// network (§7.3) — see [ConfigRepositoryFake.bundledFallbackTaxonomy].
@freezed
abstract class Taxonomy with _$Taxonomy {
  const factory Taxonomy({
    required List<TaxonomyTag> categories,
    required List<TaxonomyTag> foodTypes,
  }) = _Taxonomy;
}

import 'package:surplus_marketplace/core/domain/rating_aggregate.dart';

/// The embedded merchant shape carried by a bag list item (Phase 7 §7.4) —
/// deliberately lighter than the full [Merchant] aggregate, matching what
/// `GET /v1/bags` actually returns on the wire.
final class MerchantSummary {
  const MerchantSummary({
    required this.id,
    required this.displayName,
    required this.category,
    required this.ratingAggregate,
  });

  final String id;
  final String displayName;

  /// Taxonomy-tag ID — see `Merchant`'s class doc.
  final String category;
  final RatingAggregate ratingAggregate;
}

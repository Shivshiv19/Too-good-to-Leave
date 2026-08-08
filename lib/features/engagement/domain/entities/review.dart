import 'package:surplus_marketplace/features/engagement/domain/entities/review_tag.dart';

/// Phase 2 §2.1. `orderId` is what makes a review authentic and
/// un-spammable — one review per collected order.
final class Review {
  const Review({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.merchantId,
    required this.rating,
    required this.tags,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String orderId;
  final String customerId;
  final String merchantId;

  /// 1–5, constructor-unchecked here — the fake is the only writer and
  /// always supplies a validated value; a real client would validate at
  /// the form boundary (§C5), not re-derive the invariant in the entity.
  final int rating;

  final List<ReviewTag> tags;
  final String? comment;
  final DateTime createdAt;
}

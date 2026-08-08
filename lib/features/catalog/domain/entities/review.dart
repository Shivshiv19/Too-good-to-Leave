/// Phase 2 §2.1 — `orderId` is **required**, not optional: it's what makes a
/// review authentic and un-spammable (one review per collected order,
/// §5e.3). Hand-written, no invariants beyond what the constructor already
/// requires.
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
    this.customerDisplayName,
  });

  final String id;
  final String orderId;
  final String customerId;
  final String merchantId;

  /// 1..5 — not enforced by an `assert` here since this is a read-only
  /// entity decoded from the server, per §5b.11 ("Validation. None
  /// (read-only)").
  final int rating;
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  /// Null for reviews decoded before this field existed on the wire, or for
  /// a customer who deleted their account (§5f.11) — `Review`s persist
  /// independent of the reviewer's identity.
  final String? customerDisplayName;
}

import 'package:surplus_marketplace/features/catalog/domain/entities/bag_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/review.dart';

/// Phase 7 §7.1.2 — collections get a cursor wrapper, single resources don't.
final class DiscoverPage {
  const DiscoverPage({required this.items, required this.nextCursor});

  final List<BagSummary> items;
  final String? nextCursor;
}

/// `GET /v1/merchants/{id}/reviews` (Phase 7 §7.4) — cursor-paginated, plus
/// the histogram aggregate the list itself doesn't otherwise expose.
final class ReviewsPage {
  const ReviewsPage({required this.items, required this.nextCursor});

  final List<Review> items;
  final String? nextCursor;
}

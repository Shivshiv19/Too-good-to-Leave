import 'package:surplus_marketplace/features/engagement/domain/entities/review.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/issue_report.dart';

/// `POST /v1/orders/{id}/review`'s response shape (§7.6) — the review and,
/// when `alsoCreateIssue` was set, the linked issue created in the same
/// round-trip (§5e.3's "escalation bridge is not a courtesy").
final class SubmitReviewResult {
  const SubmitReviewResult({required this.review, this.issue});

  final Review review;
  final IssueReport? issue;
}

import 'package:surplus_marketplace/features/orders/domain/entities/issue_type.dart';

/// The acknowledgement returned after a successful `POST /orders/{id}/issues`
/// (§5d.6). **A reference number, not a generic thank-you** — required
/// explicitly by amendment A16 for food-safety reports, and used
/// consistently for every issue type rather than inventing a second,
/// lesser acknowledgement.
final class IssueReport {
  const IssueReport({
    required this.id,
    required this.referenceNumber,
    required this.type,
    required this.submittedAt,
    required this.slaHours,
    this.photosDropped = false,
  });

  final String id;
  final String referenceNumber;
  final IssueType type;
  final DateTime submittedAt;

  /// Amendment A16 — food-safety reports get a distinct, faster SLA than
  /// every other issue type.
  final int slaHours;

  /// True when the report was submitted without its photos because upload
  /// failed (§5d.6's "never lose a report to a failed image").
  final bool photosDropped;
}

import 'package:surplus_marketplace/features/engagement/domain/entities/app_notification.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/review.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/review_tag.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/submit_review_result.dart';

/// Phase 7 §7.6/§7.7 (Phase 8 §8.12 step 8).
///
/// Deliberately **not** the owner of saved/watched merchant state — that
/// lives on `CatalogRepository` (§8.12 step 5 already built it; A17's
/// "watching implies saving" consolidation and `savedMerchants()` were
/// added there in this step rather than duplicated here). This interface
/// covers only what's genuinely new: notifications and reviews.
abstract interface class EngagementRepository {
  /// `GET /v1/notifications`. Throws nothing — an empty list is normal.
  Future<List<AppNotification>> getNotifications({required String customerId});

  /// `POST /v1/notifications/read-all`.
  Future<void> markAllRead({required String customerId});

  /// `DELETE /v1/notifications/{id}`. Throws
  /// `NotificationNotDismissibleException` while the underlying order is
  /// live (§5e.1).
  Future<void> dismissNotification(String notificationId);

  /// Null when the customer hasn't reviewed this order yet.
  Future<Review?> getExistingReview(String orderId);

  /// `POST /v1/orders/{id}/review` (idem). Throws `ReviewAlreadyExistsException`
  /// (one review per collected order) or `NotFoundException`.
  Future<SubmitReviewResult> submitReview({
    required String orderId,
    required String customerId,
    required int rating,
    List<ReviewTag> tags = const [],
    String? comment,
    bool alsoCreateIssue = false,
  });
}

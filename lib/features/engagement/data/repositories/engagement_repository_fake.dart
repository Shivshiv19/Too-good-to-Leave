import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/app_notification.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/notification_class.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/notification_type.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/review.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/review_tag.dart';
import 'package:surplus_marketplace/features/engagement/domain/entities/submit_review_result.dart';
import 'package:surplus_marketplace/features/engagement/domain/repositories/engagement_repository.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

const _terminalStatuses = {
  OrderStatus.collected,
  OrderStatus.expiredUncollected,
  OrderStatus.cancelledByCustomer,
  OrderStatus.cancelledByMerchant,
};

/// Server stand-in (Phase 1 locked decision) for Phase 7 §7.6/§7.7's
/// notification and review contracts.
///
/// **Notifications are lazily derived from `OrdersRepository.getOrders`**,
/// not stored — there is no push simulator, so this fake synthesises the
/// transactional/prompt classes that are genuinely inferable from order
/// state and timing (order confirmed, payment failed, merchant cancelled,
/// refund started/completed, rate-your-pickup an hour after collection,
/// and the pickup-window timing alerts). `newBagsNearby` and
/// `watchedMerchantListed` (the two **discovery**-class types) have no
/// equivalent trigger — a supply burst is a merchant-side/server event
/// this fake has no counterpart for — and are documented as unreached, the
/// same shape as `orders`' D-58.
final class EngagementRepositoryFake implements EngagementRepository {
  EngagementRepositoryFake({
    required OrdersRepository orders,
    required Clock clock,
  }) : _orders = orders,
       _clock = clock;

  final OrdersRepository _orders;
  final Clock _clock;

  final _readIds = <String>{};
  final _dismissedIds = <String>{};
  final _reviews = <String, Review>{};
  int _idSeq = 0;

  @override
  Future<List<AppNotification>> getNotifications({
    required String customerId,
  }) async {
    final all = await _deriveAll(customerId);
    return all.where((n) => !_dismissedIds.contains(n.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> markAllRead({required String customerId}) async {
    final all = await _deriveAll(customerId);
    _readIds.addAll(all.map((n) => n.id));
  }

  @override
  Future<void> dismissNotification(String notificationId) async {
    // `customerId` isn't part of this method's contract (mirroring
    // `DELETE /v1/notifications/{id}`, which relies on auth context, not a
    // param) — dismissibility is checked directly against the order the id
    // encodes, rather than re-deriving a customer-scoped list.
    final parsed = _parseId(notificationId);
    if (parsed != null) {
      final (type, orderId) = parsed;
      if (_classFor(type) == NotificationClass.transactional) {
        final order = await _orders.getOrder(orderId);
        if (!_terminalStatuses.contains(order.status)) {
          throw NotificationNotDismissibleException(orderId: orderId);
        }
      }
    }
    _dismissedIds.add(notificationId);
  }

  @override
  Future<Review?> getExistingReview(String orderId) async => _reviews[orderId];

  @override
  Future<SubmitReviewResult> submitReview({
    required String orderId,
    required String customerId,
    required int rating,
    List<ReviewTag> tags = const [],
    String? comment,
    bool alsoCreateIssue = false,
  }) async {
    final existing = _reviews[orderId];
    if (existing != null) {
      throw ReviewAlreadyExistsException(reviewId: existing.id);
    }
    final order = await _orders.getOrder(orderId);
    final review = Review(
      id: 'rev_${_nextId()}',
      orderId: orderId,
      customerId: customerId,
      merchantId: order.merchantSnapshot.id,
      rating: rating,
      tags: tags,
      comment: comment,
      createdAt: _clock.now(),
    );
    _reviews[orderId] = review;

    IssueReport? issue;
    if (alsoCreateIssue) {
      issue = await _orders.reportIssue(
        orderId: orderId,
        type: IssueType.qualityProblem,
        description: (comment == null || comment.isEmpty)
            ? 'Reported alongside a review — see rating and tags.'
            : comment,
      );
    }
    return SubmitReviewResult(review: review, issue: issue);
  }

  Future<List<AppNotification>> _deriveAll(String customerId) async {
    final orders = [
      ...await _orders.getOrders(
        segment: OrderListSegment.active,
        customerId: customerId,
      ),
      ...await _orders.getOrders(
        segment: OrderListSegment.past,
        customerId: customerId,
      ),
    ];
    final result = <AppNotification>[];
    final now = _clock.now();

    for (final order in orders) {
      switch (order.status) {
        case OrderStatus.confirmed:
        case OrderStatus.readyForPickup:
          result.add(
            _build(
              type: NotificationType.orderConfirmed,
              order: order,
              at: order.createdAt,
              route: '/orders/${order.id}',
            ),
          );
          final window = order.pickupWindow;
          if (!now.isBefore(
                window.startAt.subtract(const Duration(minutes: 30)),
              ) &&
              now.isBefore(window.startAt)) {
            result.add(
              _build(
                type: NotificationType.pickupWindowOpening,
                order: order,
                at: window.startAt.subtract(const Duration(minutes: 30)),
                route: '/orders/${order.id}/pickup',
              ),
            );
          }
          if (!now.isBefore(
                window.endAt.subtract(const Duration(minutes: 45)),
              ) &&
              now.isBefore(window.endAt)) {
            result.add(
              _build(
                type: NotificationType.pickupClosingSoon,
                order: order,
                at: window.endAt.subtract(const Duration(minutes: 45)),
                route: '/orders/${order.id}/pickup',
              ),
            );
          }
        case OrderStatus.paymentFailed:
          result.add(
            _build(
              type: NotificationType.paymentFailed,
              order: order,
              at: order.createdAt,
              route: '/checkout/failed?orderId=${order.id}',
            ),
          );
        case OrderStatus.cancelledByMerchant:
          result.add(
            _build(
              type: NotificationType.merchantCancelled,
              order: order,
              at: order.cancelledAt ?? order.createdAt,
              route: '/orders/${order.id}',
            ),
          );
        case OrderStatus.cancelledByCustomer:
          break;
        case OrderStatus.collected:
          final oneHourAfter = (order.collectedAt ?? order.createdAt).add(
            const Duration(hours: 1),
          );
          if (!now.isBefore(oneHourAfter)) {
            result.add(
              _build(
                type: NotificationType.rateYourPickup,
                order: order,
                at: oneHourAfter,
                route: '/orders/${order.id}/review',
              ),
            );
          }
        case OrderStatus.expiredUncollected:
        case OrderStatus.pendingPayment:
          break;
      }

      if (order.status == OrderStatus.cancelledByCustomer ||
          order.status == OrderStatus.cancelledByMerchant) {
        try {
          final refund = await _orders.getRefund(order.id);
          result.add(
            _build(
              type: NotificationType.refundInitiated,
              order: order,
              at: refund.steps.first.completedAt ?? now,
              route: '/orders/${order.id}/refund',
            ),
          );
          final creditedAt = refund.steps.last.completedAt;
          if (creditedAt != null) {
            result.add(
              _build(
                type: NotificationType.refundCompleted,
                order: order,
                at: creditedAt,
                route: '/orders/${order.id}/refund',
              ),
            );
          }
        } on Object {
          // No refund to report — nothing to add.
        }
      }
    }
    return result;
  }

  AppNotification _build({
    required NotificationType type,
    required Order order,
    required DateTime at,
    required String route,
  }) {
    final id = 'notif_${type.wireValue}_${order.id}';
    final notificationClass = _classFor(type);
    return AppNotification(
      id: id,
      type: type,
      notificationClass: notificationClass,
      title: order.bagSnapshot.title,
      body: order.merchantSnapshot.displayName,
      route: route,
      orderId: order.id,
      createdAt: at,
      read: _readIds.contains(id),
      dismissible:
          notificationClass != NotificationClass.transactional ||
          _terminalStatuses.contains(order.status),
    );
  }

  NotificationClass _classFor(NotificationType type) => switch (type) {
    NotificationType.newBagsNearby ||
    NotificationType.watchedMerchantListed => NotificationClass.discovery,
    NotificationType.rateYourPickup => NotificationClass.prompt,
    _ => NotificationClass.transactional,
  };

  /// Recovers `(type, orderId)` from an id built by [_build] — the fake's
  /// own encoding, not a wire format.
  (NotificationType, String)? _parseId(String notificationId) {
    for (final type in NotificationType.values) {
      final prefix = 'notif_${type.wireValue}_';
      if (notificationId.startsWith(prefix)) {
        return (type, notificationId.substring(prefix.length));
      }
    }
    return null;
  }

  String _nextId() => '${_clock.now().microsecondsSinceEpoch}_${_idSeq++}';
}

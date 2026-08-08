import 'dart:math';
import 'dart:typed_data';

import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_token.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/cancellation_eligibility.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/issue_report.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/issue_type.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/order_list_segment.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/refund_detail.dart';
import 'package:surplus_marketplace/features/orders/domain/repositories/orders_repository.dart';

const _activeStatuses = {
  OrderStatus.pendingPayment,
  OrderStatus.confirmed,
  OrderStatus.paymentFailed,
  OrderStatus.readyForPickup,
};

/// Server stand-in (Phase 1 locked decision) for Phase 7 §7.6.
///
/// **Depends on the concrete `CheckoutRepositoryFake`, not just the
/// `CheckoutRepository` interface** — `ordersForCustomer`/`updateOrder` are
/// fake-to-fake wiring, not part of the §7.5 contract `CheckoutRepository`
/// mirrors, so reaching them needs the concrete type. This is also what
/// makes `orders` need no dependency on `catalog` (§8.3.2): every read here
/// works off the immutable snapshot already embedded in the shared `Order`.
///
/// **No merchant-side simulation exists**, so `readyForPickup` and
/// `cancelledByMerchant` are valid `OrderStatus` values with no path to
/// reach them in this fake — the same "implemented, just not reachable
/// without a real backend" shape as `checkout`'s D-48. `collected` and
/// `expiredUncollected`, by contrast, are both derivable from time alone
/// and so are fully reachable: [_derive] lazily promotes a `confirmed`
/// order once its pickup window has lapsed (`expiredUncollected`) or once a
/// fixed delay after the window opens has passed (`collected` — standing
/// in for "the merchant scanned it", since no merchant app exists to do so
/// for real).
final class OrdersRepositoryFake implements OrdersRepository {
  OrdersRepositoryFake({
    required CheckoutRepositoryFake checkout,
    required Clock clock,
  }) : _checkout = checkout,
       _clock = clock;

  final CheckoutRepositoryFake _checkout;
  final Clock _clock;
  final _random = Random.secure();

  /// Simulated "merchant scanned it" — see class doc.
  static const _collectionDelay = Duration(seconds: 90);

  /// Amendment A15. Mirrors (does not read) `ConfigRepositoryFake`'s
  /// `cancellationCutoffMinutesBeforeWindow: 60` — the same
  /// no-cross-fake-wiring precedent as `checkout`'s D-46, for the same
  /// reason: `bootstrap.dart` constructs every repository synchronously,
  /// before any `Future<RemoteConfig>` resolves.
  static const _cancellationCutoff = Duration(minutes: 60);

  /// Fixture SLA numbers — Phase 7 §7.6 specifies the `food_safety`
  /// escalation class (A16) but not exact hours; these mirror
  /// `ConfigRepositoryFake`'s `grievanceSlaHours: 48` for the general case
  /// and pick a materially faster number for the escalated one.
  static const _generalIssueSlaHours = 48;
  static const _foodSafetySlaHours = 2;

  final _cancellationReasons = <String, String>{};
  final _refundInitiatedAt = <String, DateTime>{};
  int _idSeq = 0;

  @override
  Future<List<Order>> getOrders({
    required OrderListSegment segment,
    required String customerId,
  }) async {
    final derived = _checkout
        .ordersForCustomer(customerId)
        .map(_derive)
        .toList();
    final wanted = segment == OrderListSegment.active
        ? derived.where((o) => _activeStatuses.contains(o.status))
        : derived.where((o) => !_activeStatuses.contains(o.status));
    final list = wanted.toList();
    if (segment == OrderListSegment.active) {
      list.sort(
        (a, b) => a.pickupWindow.startAt.compareTo(b.pickupWindow.startAt),
      );
    } else {
      list.sort((a, b) => _pastTimestamp(b).compareTo(_pastTimestamp(a)));
    }
    return list;
  }

  @override
  Future<Order> getOrder(String orderId) async =>
      _derive(await _checkout.getOrder(orderId));

  @override
  Future<PickupToken> getPickupToken(String orderId) async {
    final order = await getOrder(orderId);
    final now = _clock.now();
    return PickupToken(
      rotatingPayload: 'qr_${order.id}_${now.millisecondsSinceEpoch ~/ 60000}',
      rotationExpiresAt: now.add(const Duration(seconds: 60)),
      offlineToken: 'offline_${order.id}',
      offlineTokenValidUntil: order.pickupWindow.endAt,
      fallbackCode: _fallbackCodeFor(order),
    );
  }

  @override
  Future<CancellationEligibility> getCancellationEligibility(
    String orderId,
  ) async {
    final order = await getOrder(orderId);
    final cutoff = order.pickupWindow.startAt.subtract(_cancellationCutoff);
    final eligible =
        _isCancellable(order.status) && _clock.now().isBefore(cutoff);
    return CancellationEligibility(
      eligible: eligible,
      cutoffAt: cutoff,
      refundOutcome: eligible
          ? CancellationRefundOutcome.full
          : CancellationRefundOutcome.none,
      refundAmount: eligible ? order.breakdown.total : const Money.zero(),
    );
  }

  @override
  Future<Order> cancelOrder(String orderId, {String? reason}) async {
    final order = await getOrder(orderId);
    final cutoff = order.pickupWindow.startAt.subtract(_cancellationCutoff);
    if (!_isCancellable(order.status) || !_clock.now().isBefore(cutoff)) {
      throw CancellationWindowPassedException(cutoffAt: cutoff);
    }
    final cancelled = order.copyWith(
      status: OrderStatus.cancelledByCustomer,
      cancelledAt: _clock.now(),
      cancellationReason: reason,
    );
    _checkout.updateOrder(cancelled);
    _refundInitiatedAt[orderId] = _clock.now();
    if (reason != null) _cancellationReasons[orderId] = reason;
    return cancelled;
  }

  @override
  Future<RefundDetail> getRefund(String orderId) async {
    final order = await getOrder(orderId);
    if (order.status != OrderStatus.cancelledByCustomer &&
        order.status != OrderStatus.cancelledByMerchant) {
      throw const NotFoundException();
    }
    final initiatedAt =
        _refundInitiatedAt[orderId] ?? order.cancelledAt ?? _clock.now();
    final sentToBankAt = initiatedAt.add(const Duration(hours: 6));
    final creditedAt = initiatedAt.add(const Duration(days: 3));
    final now = _clock.now();

    final steps = [
      RefundStep(label: RefundStepLabel.started, completedAt: initiatedAt),
      RefundStep(
        label: RefundStepLabel.sentToBank,
        completedAt: now.isAfter(sentToBankAt) ? sentToBankAt : null,
      ),
      RefundStep(
        label: RefundStepLabel.credited,
        completedAt: now.isAfter(creditedAt) ? creditedAt : null,
      ),
    ];
    final credited = steps.last.completedAt != null;

    return RefundDetail(
      amount: order.breakdown.total,
      status: credited ? RefundStatus.refunded : RefundStatus.initiated,
      steps: steps,
      method: order.payment.method,
      maskedDestination: order.payment.maskedIdentifier ?? '----',
      reason:
          _cancellationReasons[orderId] ??
          (order.status == OrderStatus.cancelledByMerchant
              ? 'merchant_cancelled'
              : 'customer_cancelled'),
      expectedByAt: credited ? null : creditedAt,
      bankReferenceNumber: steps[1].completedAt != null
          ? 'REF${_randomDigits(9)}'
          : null,
    );
  }

  @override
  Future<String> uploadAttachment(
    Uint8List bytes, {
    required String filename,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return 'att_${_nextId()}';
  }

  @override
  Future<IssueReport> reportIssue({
    required String orderId,
    required IssueType type,
    required String description,
    List<String> attachmentIds = const [],
  }) async {
    await getOrder(orderId); // validates existence — NotFoundException else
    return IssueReport(
      id: 'iss_${_nextId()}',
      referenceNumber: 'ISS-${_randomAlpha(6)}',
      type: type,
      submittedAt: _clock.now(),
      slaHours: type.isFoodSafety ? _foodSafetySlaHours : _generalIssueSlaHours,
    );
  }

  bool _isCancellable(OrderStatus status) => status == OrderStatus.confirmed;

  DateTime _pastTimestamp(Order order) =>
      order.collectedAt ?? order.cancelledAt ?? order.createdAt;

  /// Lazily promotes a `confirmed` order once time has moved past a
  /// threshold — see class doc. Persists the promotion back into the
  /// shared store so every subsequent read (list, detail, pickup) agrees.
  Order _derive(Order order) {
    if (order.status != OrderStatus.confirmed) return order;
    final now = _clock.now();
    if (now.isAfter(order.pickupWindow.endAt)) {
      final expired = order.copyWith(status: OrderStatus.expiredUncollected);
      _checkout.updateOrder(expired);
      return expired;
    }
    final collectAt = order.pickupWindow.startAt.add(_collectionDelay);
    if (now.isAfter(collectAt)) {
      final collected = order.copyWith(
        status: OrderStatus.collected,
        collectedAt: collectAt,
      );
      _checkout.updateOrder(collected);
      return collected;
    }
    return order;
  }

  String _fallbackCodeFor(Order order) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // excludes 0/O,1/I/L
    final seeded = Random(order.id.hashCode);
    return List.generate(
      6,
      (_) => alphabet[seeded.nextInt(alphabet.length)],
    ).join();
  }

  String _randomDigits(int length) =>
      List.generate(length, (_) => _random.nextInt(10)).join();

  String _randomAlpha(int length) {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(
      length,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  String _nextId() => '${_clock.now().microsecondsSinceEpoch}_${_idSeq++}';
}

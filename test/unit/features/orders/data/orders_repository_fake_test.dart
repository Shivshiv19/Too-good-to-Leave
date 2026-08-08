import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/catalog/data/repositories/catalog_repository_fake.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

Future<
  ({OrdersRepositoryFake orders, CheckoutRepositoryFake checkout, Clock clock})
>
_repositories({Clock? clock}) async {
  final effectiveClock = clock ?? const SystemClock();
  SharedPreferences.setMockInitialValues({});
  final catalog = CatalogRepositoryFake(
    prefs: await Prefs.open(),
    clock: effectiveClock,
  );
  final checkout = CheckoutRepositoryFake(
    catalog: catalog,
    clock: effectiveClock,
  );
  final orders = OrdersRepositoryFake(
    checkout: checkout,
    clock: effectiveClock,
  );
  return (orders: orders, checkout: checkout, clock: effectiveClock);
}

/// Confirms an order for `bag_sc_1` (fixture window `today(20)`–`today(22)`,
/// i.e. 20:00–22:00 relative to the clock's construction-time "now").
Future<Order> _confirmedOrder(
  CheckoutRepositoryFake checkout, {
  String bagId = 'bag_sc_1',
  String customerId = 'cust_1',
}) async {
  final hold = await checkout.createHold(bagId: bagId, quantity: 1);
  final result = await checkout.createOrder(
    holdId: hold.id,
    customerId: customerId,
    method: PaymentMethod.upi,
  );
  await checkout.verifyPayment(result.payment.id); // -> pendingVerification
  await checkout.verifyPayment(result.payment.id); // -> captured, confirmed
  return checkout.getOrder(result.order.id);
}

void main() {
  group('OrdersRepositoryFake — getOrders segmentation', () {
    test('a freshly confirmed order is active, not past', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      final active = await r.orders.getOrders(
        segment: OrderListSegment.active,
        customerId: order.customerId,
      );
      final past = await r.orders.getOrders(
        segment: OrderListSegment.past,
        customerId: order.customerId,
      );
      expect(active.map((o) => o.id), contains(order.id));
      expect(past, isEmpty);
    });

    test('an order past its window moves to the past segment', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      clock.set(DateTime(2026, 1, 1, 23)); // past the 22:00 window end
      final active = await r.orders.getOrders(
        segment: OrderListSegment.active,
        customerId: order.customerId,
      );
      final past = await r.orders.getOrders(
        segment: OrderListSegment.past,
        customerId: order.customerId,
      );
      expect(active, isEmpty);
      expect(past.single.status, OrderStatus.expiredUncollected);
    });
  });

  group('OrdersRepositoryFake — status derivation', () {
    test('collected 90s after the window opens', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      clock.set(DateTime(2026, 1, 1, 20, 1, 31)); // 91s after 20:00
      final derived = await r.orders.getOrder(order.id);
      expect(derived.status, OrderStatus.collected);
      expect(derived.collectedAt, DateTime(2026, 1, 1, 20, 1, 30));
    });

    test('expiredUncollected once the window has fully lapsed', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      clock.set(DateTime(2026, 1, 1, 22, 30)); // past 22:00
      final derived = await r.orders.getOrder(order.id);
      expect(derived.status, OrderStatus.expiredUncollected);
    });

    test('a derived status is persisted back into the shared store', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      clock.set(DateTime(2026, 1, 1, 22, 30));
      await r.orders.getOrder(order.id);
      final reread = await r.checkout.getOrder(order.id);
      expect(reread.status, OrderStatus.expiredUncollected);
    });
  });

  group('OrdersRepositoryFake — getPickupToken (A1)', () {
    test('returns all three layers, and a stable fallback code', () async {
      final r = await _repositories();
      final order = await _confirmedOrder(r.checkout);

      final first = await r.orders.getPickupToken(order.id);
      final second = await r.orders.getPickupToken(order.id);
      expect(first.fallbackCode, hasLength(6));
      expect(first.fallbackCode, second.fallbackCode);
      expect(first.offlineTokenValidUntil, order.pickupWindow.endAt);
    });
  });

  group('OrdersRepositoryFake — cancellation eligibility (A15)', () {
    test('eligible well before the 60-minute cutoff', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      final eligibility = await r.orders.getCancellationEligibility(order.id);
      expect(eligibility.eligible, isTrue);
      expect(eligibility.refundOutcome, CancellationRefundOutcome.full);
      expect(eligibility.refundAmount, order.breakdown.total);
      expect(eligibility.cutoffAt, DateTime(2026, 1, 1, 19));
    });

    test('not eligible past the cutoff', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      clock.set(DateTime(2026, 1, 1, 19, 30)); // past the 19:00 cutoff
      final eligibility = await r.orders.getCancellationEligibility(order.id);
      expect(eligibility.eligible, isFalse);
      expect(eligibility.refundOutcome, CancellationRefundOutcome.none);
      expect(eligibility.refundAmount.isZero, isTrue);
    });
  });

  group('OrdersRepositoryFake — cancelOrder', () {
    test('cancels and freezes the cancellation reason', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      final cancelled = await r.orders.cancelOrder(
        order.id,
        reason: 'change of plan',
      );
      expect(cancelled.status, OrderStatus.cancelledByCustomer);
      expect(cancelled.cancelledAt, clock.now());
      expect(cancelled.cancellationReason, 'change of plan');
    });

    test('throws CancellationWindowPassedException past the cutoff', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      clock.set(DateTime(2026, 1, 1, 19, 30));
      await expectLater(
        r.orders.cancelOrder(order.id),
        throwsA(isA<CancellationWindowPassedException>()),
      );
    });
  });

  group('OrdersRepositoryFake — getRefund (§5d.4)', () {
    test('throws NotFoundException for an order with no refund', () async {
      final r = await _repositories();
      final order = await _confirmedOrder(r.checkout);
      await expectLater(
        r.orders.getRefund(order.id),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('starts at "initiated" with an honest expectedByAt', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);
      await r.orders.cancelOrder(order.id);

      final refund = await r.orders.getRefund(order.id);
      expect(refund.status, RefundStatus.initiated);
      expect(refund.steps[0].completedAt, isNotNull);
      expect(refund.steps[1].completedAt, isNull);
      expect(refund.steps[2].completedAt, isNull);
      expect(refund.expectedByAt, isNotNull);
      expect(refund.amount, order.breakdown.total);
    });

    test('reaches "refunded" with all steps complete after 3 days', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);
      await r.orders.cancelOrder(order.id);

      clock.advance(const Duration(days: 3, hours: 1));
      final refund = await r.orders.getRefund(order.id);
      expect(refund.status, RefundStatus.refunded);
      expect(refund.steps.every((s) => s.completedAt != null), isTrue);
      expect(refund.expectedByAt, isNull);
      expect(refund.bankReferenceNumber, isNotNull);
    });
  });

  group('OrdersRepositoryFake — issues (A16)', () {
    test('a general issue gets the standard SLA', () async {
      final r = await _repositories();
      final order = await _confirmedOrder(r.checkout);
      final report = await r.orders.reportIssue(
        orderId: order.id,
        type: IssueType.noBagReady,
        description: 'No bag was ready at the counter.',
      );
      expect(report.slaHours, 48);
      expect(report.referenceNumber, isNotEmpty);
    });

    test('a food-safety issue gets the faster, escalated SLA', () async {
      final r = await _repositories();
      final order = await _confirmedOrder(r.checkout);
      final report = await r.orders.reportIssue(
        orderId: order.id,
        type: IssueType.foodSafety,
        description: 'Felt unwell after eating this.',
      );
      expect(report.slaHours, 2);
    });

    test('throws NotFoundException for an unknown order', () async {
      final r = await _repositories();
      await expectLater(
        r.orders.reportIssue(
          orderId: 'ord_never_created',
          type: IssueType.noBagReady,
          description: 'No bag was ready at the counter.',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('OrdersRepositoryFake — uploadAttachment', () {
    test('returns a non-empty opaque id', () async {
      final r = await _repositories();
      final id = await r.orders.uploadAttachment(
        Uint8List(0),
        filename: 'photo.jpg',
      );
      expect(id, isNotEmpty);
    });
  });
}

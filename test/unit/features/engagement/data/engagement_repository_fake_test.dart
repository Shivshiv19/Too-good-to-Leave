import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/catalog/data/repositories/catalog_repository_fake.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/engagement/engagement.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

Future<
  ({
    EngagementRepositoryFake engagement,
    OrdersRepositoryFake orders,
    CheckoutRepositoryFake checkout,
  })
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
  final engagement = EngagementRepositoryFake(
    orders: orders,
    clock: effectiveClock,
  );
  return (engagement: engagement, orders: orders, checkout: checkout);
}

/// Confirms an order for `bag_sc_1` (fixture window `today(20)`–`today(22)`).
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
  await checkout.verifyPayment(result.payment.id);
  await checkout.verifyPayment(result.payment.id);
  return checkout.getOrder(result.order.id);
}

void main() {
  group('EngagementRepositoryFake — getNotifications', () {
    test(
      'a confirmed order produces an unread orderConfirmed notice',
      () async {
        final clock = FixedClock(DateTime(2026, 1, 1, 12));
        final r = await _repositories(clock: clock);
        final order = await _confirmedOrder(r.checkout);

        final notifications = await r.engagement.getNotifications(
          customerId: order.customerId,
        );
        final confirmed = notifications.singleWhere(
          (n) => n.type == NotificationType.orderConfirmed,
        );
        expect(confirmed.read, isFalse);
        expect(confirmed.dismissible, isFalse); // order is still live
      },
    );

    test(
      'pickupWindowOpening appears only inside its 30-minute window',
      () async {
        final clock = FixedClock(DateTime(2026, 1, 1, 12));
        final r = await _repositories(clock: clock);
        final order = await _confirmedOrder(r.checkout);

        final before = await r.engagement.getNotifications(
          customerId: order.customerId,
        );
        expect(
          before.any((n) => n.type == NotificationType.pickupWindowOpening),
          isFalse,
        );

        clock.set(DateTime(2026, 1, 1, 19, 45)); // 15 min before 20:00
        final during = await r.engagement.getNotifications(
          customerId: order.customerId,
        );
        expect(
          during.any((n) => n.type == NotificationType.pickupWindowOpening),
          isTrue,
        );
      },
    );

    test('rateYourPickup appears only 1h+ after collection', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      // Advance past the window open + the fake's 90s auto-collect delay.
      clock.set(DateTime(2026, 1, 1, 20, 5));
      await r.orders.getOrder(order.id); // triggers derivation to collected

      final tooEarly = await r.engagement.getNotifications(
        customerId: order.customerId,
      );
      expect(
        tooEarly.any((n) => n.type == NotificationType.rateYourPickup),
        isFalse,
      );

      clock.set(DateTime(2026, 1, 1, 21, 6));
      final afterAnHour = await r.engagement.getNotifications(
        customerId: order.customerId,
      );
      expect(
        afterAnHour.any((n) => n.type == NotificationType.rateYourPickup),
        isTrue,
      );
    });
  });

  group('EngagementRepositoryFake — markAllRead', () {
    test('marks every currently-visible notification as read', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);

      await r.engagement.markAllRead(customerId: order.customerId);
      final notifications = await r.engagement.getNotifications(
        customerId: order.customerId,
      );
      expect(notifications.every((n) => n.read), isTrue);
    });
  });

  group('EngagementRepositoryFake — dismissNotification (§5e.1)', () {
    test('throws while the transactional order is still live', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);
      final notifications = await r.engagement.getNotifications(
        customerId: order.customerId,
      );
      final confirmed = notifications.singleWhere(
        (n) => n.type == NotificationType.orderConfirmed,
      );

      await expectLater(
        r.engagement.dismissNotification(confirmed.id),
        throwsA(isA<NotificationNotDismissibleException>()),
      );
    });

    test('succeeds once the order reaches a terminal state', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final r = await _repositories(clock: clock);
      final order = await _confirmedOrder(r.checkout);
      await r.orders.cancelOrder(order.id); // now cancelledByCustomer

      final notifications = await r.engagement.getNotifications(
        customerId: order.customerId,
      );
      final refundNotice = notifications.singleWhere(
        (n) => n.type == NotificationType.refundInitiated,
      );
      expect(refundNotice.dismissible, isTrue);
      await r.engagement.dismissNotification(refundNotice.id);

      final after = await r.engagement.getNotifications(
        customerId: order.customerId,
      );
      expect(
        after.any((n) => n.id == refundNotice.id),
        isFalse,
      );
    });
  });

  group('EngagementRepositoryFake — reviews (§5e.3)', () {
    test(
      'submitReview stores a review retrievable via getExistingReview',
      () async {
        final clock = FixedClock(DateTime(2026, 1, 1, 12));
        final r = await _repositories(clock: clock);
        final order = await _confirmedOrder(r.checkout);

        expect(await r.engagement.getExistingReview(order.id), isNull);
        final result = await r.engagement.submitReview(
          orderId: order.id,
          customerId: order.customerId,
          rating: 5,
          tags: const [ReviewTag.fresh, ReviewTag.easyPickup],
          comment: 'Great bag!',
        );
        expect(result.review.rating, 5);
        expect(result.issue, isNull);

        final existing = await r.engagement.getExistingReview(order.id);
        expect(existing, isNotNull);
        expect(existing!.tags, contains(ReviewTag.fresh));
      },
    );

    test(
      'throws ReviewAlreadyExistsException on a second submission',
      () async {
        final r = await _repositories();
        final order = await _confirmedOrder(r.checkout);
        await r.engagement.submitReview(
          orderId: order.id,
          customerId: order.customerId,
          rating: 4,
        );
        await expectLater(
          r.engagement.submitReview(
            orderId: order.id,
            customerId: order.customerId,
            rating: 2,
          ),
          throwsA(isA<ReviewAlreadyExistsException>()),
        );
      },
    );

    test(
      'alsoCreateIssue links an IssueReport in the same round trip',
      () async {
        final r = await _repositories();
        final order = await _confirmedOrder(r.checkout);
        final result = await r.engagement.submitReview(
          orderId: order.id,
          customerId: order.customerId,
          rating: 1,
          tags: const [ReviewTag.notFresh],
          comment: 'This was not fresh at all.',
          alsoCreateIssue: true,
        );
        expect(result.issue, isNotNull);
        expect(result.issue!.type, IssueType.qualityProblem);
      },
    );

    test('throws NotFoundException for an unknown order', () async {
      final r = await _repositories();
      await expectLater(
        r.engagement.submitReview(
          orderId: 'ord_never_created',
          customerId: 'cust_1',
          rating: 5,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}

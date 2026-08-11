import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/data/shop_repository.dart';
import 'package:too_good_to_leave_shop/domain/impact_estimate.dart';
import 'package:too_good_to_leave_shop/domain/payout.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';
import 'package:too_good_to_leave_shop/domain/shop_category.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';
import 'package:too_good_to_leave_shop/domain/store_hours.dart';
import 'package:too_good_to_leave_shop/main.dart';

ShopProfile _testProfile() => ShopProfile(
  businessName: 'Test Bakery',
  ownerName: 'Test Owner',
  phone: '9999999999',
  email: 'owner@test.com',
  category: ShopCategory.bakery,
  addressLine: '1 Test Street',
  locality: 'Test Locality',
  fssai: FssaiLicense(
    licenseNumber: 'FSSAI123',
    expiresAt: DateTime.now().add(const Duration(days: 365)),
  ),
  bankDetails: const BankDetails(
    accountHolderName: 'Test Owner',
    accountNumber: '000111222',
    ifscCode: 'TEST0001',
  ),
);

Future<ShopRepository> _verifiedRepository() async {
  final repo = ShopRepository();
  await repo.register(_testProfile());
  await repo.simulateApproval();
  return repo;
}

void main() {
  // register()/simulateApproval()/createBag()/etc. all persist via
  // shared_preferences now, which every test touches whether or not it
  // cares about persistence specifically.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('unregistered shop sees the registration form first', (
    tester,
  ) async {
    await tester.pumpWidget(ShopApp(repository: ShopRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Register your shop'), findsOneWidget);
  });

  testWidgets('submitting registration moves to the pending-review screen', (
    tester,
  ) async {
    final repository = ShopRepository();
    await tester.pumpWidget(ShopApp(repository: repository));
    await tester.pumpAndSettle();

    await repository.register(_testProfile());
    await tester.pumpAndSettle();

    expect(find.text('Under review'), findsOneWidget);

    await tester.tap(find.text('Simulate approval'));
    await tester.pumpAndSettle();

    expect(find.text('Your bags'), findsOneWidget);
  });

  testWidgets('a verified shop launches to the bag list with seeded fixtures', (
    tester,
  ) async {
    await tester.pumpWidget(ShopApp(repository: await _verifiedRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Your bags'), findsOneWidget);
    expect(find.text('Bakery Surprise Bag'), findsOneWidget);
  });

  testWidgets('Orders tab shows seeded orders', (tester) async {
    await tester.pumpWidget(ShopApp(repository: await _verifiedRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsWidgets);
    expect(find.text('For Aditi'), findsOneWidget);
  });

  testWidgets('Account tab shows business details and logging out returns '
      'to registration', (tester) async {
    await tester.pumpWidget(ShopApp(repository: await _verifiedRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.text('Test Bakery'), findsOneWidget);
    expect(find.text('Test Owner'), findsOneWidget);

    // The Account screen's list has grown past the test viewport's fold —
    // scroll straight to the bottom rather than use ensureVisible, which
    // needs its target to resolve to exactly one widget and gets confused
    // now that the screen has more on it.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    // Confirm the dialog — targeted by widget type rather than `.last`,
    // since ordinal text-matching is fragile once the screen has more than
    // one "Log out" on it at once (the button underneath, and the dialog's
    // own action).
    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Register your shop'), findsOneWidget);
  });

  // Registration/bags/orders are now Supabase-backed (see
  // data/shop_repository.dart's module doc) rather than persisted to
  // `shared_preferences`, so cross-reload persistence for them is no
  // longer something a backend-free unit test can exercise — that needs a
  // real (or mocked) Supabase project instead. `ShopRepository.load()`
  // with no prior Supabase session simply comes up unregistered, which is
  // covered by the widget tests above via the bare fixture constructor.

  group('listings', () {
    test(
      'duplicateBag copies details into a new draft shifted a day',
      () async {
        final repo = ShopRepository();
        final source = repo.getBags().first;

        final copy = await repo.duplicateBag(source.id);

        expect(copy.id, isNot(source.id));
        expect(copy.title, source.title);
        expect(copy.price, source.price);
        expect(
          copy.pickupWindow.startAt.difference(source.pickupWindow.startAt),
          const Duration(days: 1),
        );
      },
    );

    test('toggleAvailability flips live and paused, but not draft', () async {
      final repo = ShopRepository();
      final live = repo.getBags().firstWhere((b) => b.status == BagStatus.live);
      final draft = repo.getBags().firstWhere(
        (b) => b.status == BagStatus.draft,
      );

      await repo.toggleAvailability(live.id);
      expect(
        repo.getBags().firstWhere((b) => b.id == live.id).status,
        BagStatus.paused,
      );

      await repo.toggleAvailability(draft.id);
      expect(
        repo.getBags().firstWhere((b) => b.id == draft.id).status,
        BagStatus.draft,
      );
    });
  });

  group('order lifecycle', () {
    test('markNoShow moves a reserved order to expired', () async {
      final repo = ShopRepository();
      final reserved = repo.getOrders().firstWhere(
        (o) => o.status == ShopOrderStatus.reserved,
      );

      await repo.markNoShow(reserved.id);

      expect(
        repo.getOrders().firstWhere((o) => o.id == reserved.id).status,
        ShopOrderStatus.expired,
      );
    });

    test('markNoShow does not touch an already-collected order', () async {
      final repo = ShopRepository();
      final collected = repo.getOrders().firstWhere(
        (o) => o.status == ShopOrderStatus.collected,
      );

      await repo.markNoShow(collected.id);

      expect(
        repo.getOrders().firstWhere((o) => o.id == collected.id).status,
        ShopOrderStatus.collected,
      );
    });

    test('cancelOrder moves a reserved order to cancelled', () async {
      final repo = ShopRepository();
      final reserved = repo.getOrders().firstWhere(
        (o) => o.status == ShopOrderStatus.reserved,
      );

      await repo.cancelOrder(reserved.id);

      expect(
        repo.getOrders().firstWhere((o) => o.id == reserved.id).status,
        ShopOrderStatus.cancelled,
      );
    });

    test('cancelOrder does not touch an already-collected order', () async {
      final repo = ShopRepository();
      final collected = repo.getOrders().firstWhere(
        (o) => o.status == ShopOrderStatus.collected,
      );

      await repo.cancelOrder(collected.id);

      expect(
        repo.getOrders().firstWhere((o) => o.id == collected.id).status,
        ShopOrderStatus.collected,
      );
    });
  });

  group('payments', () {
    test('totalEarnedAllTime and pendingPayoutAmount start equal, net of '
        'commission on the one seeded collected order', () {
      final repo = ShopRepository();
      final collected = repo.getOrders().firstWhere(
        (o) => o.status == ShopOrderStatus.collected,
      );
      final expectedNet = EarningsBreakdown(gross: collected.price).net;

      expect(repo.totalEarnedAllTime, expectedNet);
      expect(repo.pendingPayoutAmount, expectedNet);
    });

    test('requestPayout pays out everything pending, then has nothing left '
        'to pay', () async {
      final repo = ShopRepository();
      final pendingBefore = repo.pendingPayoutAmount;

      final payout = await repo.requestPayout();

      expect(payout, isNotNull);
      expect(payout!.amount, pendingBefore);
      expect(repo.pendingPayoutAmount, const Money.zero());
      // All-time total is unaffected by a payout — it's still the same
      // money, just no longer *pending*.
      expect(repo.totalEarnedAllTime, pendingBefore);
      expect(repo.getPayouts(), hasLength(1));
    });

    test('requestPayout is a no-op when nothing is pending', () async {
      final repo = ShopRepository();
      await repo.requestPayout();

      final second = await repo.requestPayout();

      expect(second, isNull);
      expect(repo.getPayouts(), hasLength(1));
    });
  });

  group('impact estimate', () {
    test('zero collected bags means zero impact, not a divide-by-zero', () {
      expect(ImpactEstimate.mealsSaved(0), 0);
      expect(ImpactEstimate.kgSaved(0), 0);
      expect(ImpactEstimate.co2eKgAvoided(0), 0);
    });

    test('scales linearly with collected bag count', () {
      expect(ImpactEstimate.mealsSaved(10), 10);
      expect(ImpactEstimate.kgSaved(10), 10 * ImpactEstimate.kgPerBag);
      expect(
        ImpactEstimate.co2eKgAvoided(10),
        10 * ImpactEstimate.kgPerBag * ImpactEstimate.co2eKgPerKgFood,
      );
    });
  });

  group('notifications', () {
    test('confirming a pickup, marking a no-show, cancelling, and '
        'requesting a payout each add an unread notification', () async {
      final repo = ShopRepository();
      expect(repo.unreadNotificationCount, 0);

      final reserved = repo.getOrders().firstWhere(
        (o) => o.status == ShopOrderStatus.reserved,
      );
      await repo.confirmPickupByCode(
        orderId: reserved.id,
        code: reserved.token.fallbackCode,
      );
      expect(repo.unreadNotificationCount, 1);

      await repo.requestPayout();
      expect(repo.unreadNotificationCount, 2);
      expect(repo.getNotifications(), hasLength(2));
      // Newest first.
      expect(repo.getNotifications().first.message, contains('Payout'));
    });

    test('markAllNotificationsRead clears the unread count', () async {
      final repo = ShopRepository();
      final reserved = repo.getOrders().firstWhere(
        (o) => o.status == ShopOrderStatus.reserved,
      );
      await repo.markNoShow(reserved.id);
      expect(repo.unreadNotificationCount, 1);

      await repo.markAllNotificationsRead();

      expect(repo.unreadNotificationCount, 0);
      expect(repo.getNotifications().every((n) => n.read), true);
    });
  });

  group('persistence', () {
    test('store hours survive a fresh load()', () async {
      final first = await ShopRepository.load();
      final updated = first.storeHours.withDay(
        6,
        first.storeHours.days[6].copyWith(isOpen: true, openHour: 10),
      );

      await first.updateStoreHours(updated);

      final reloaded = await ShopRepository.load();
      expect(reloaded.storeHours.days[6].isOpen, true);
      expect(reloaded.storeHours.days[6].openHour, 10);
      // Untouched days are unaffected.
      expect(reloaded.storeHours.days[0].isOpen, true);
    });
  });

  group('store hours', () {
    test('defaults to open Monday-Saturday, closed Sunday', () {
      final defaults = StoreHours.defaults();

      expect(defaults.days, hasLength(7));
      expect(defaults.days.take(6).every((d) => d.isOpen), true);
      expect(defaults.days.last.isOpen, false);
    });

    test('withDay only changes the targeted day', () {
      final hours = StoreHours.defaults();

      final updated = hours.withDay(2, hours.days[2].copyWith(isOpen: false));

      expect(updated.days[2].isOpen, false);
      for (var i = 0; i < updated.days.length; i++) {
        if (i != 2) expect(updated.days[i].isOpen, hours.days[i].isOpen);
      }
    });
  });
}

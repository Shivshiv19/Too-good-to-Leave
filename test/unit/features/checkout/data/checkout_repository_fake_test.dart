import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/catalog/data/repositories/catalog_repository_fake.dart';
import 'package:surplus_marketplace/features/checkout/data/repositories/checkout_repository_fake.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_method.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_status.dart';

Future<CheckoutRepositoryFake> _repository({
  Clock clock = const SystemClock(),
}) async {
  SharedPreferences.setMockInitialValues({});
  final catalog = CatalogRepositoryFake(
    prefs: await Prefs.open(),
    clock: clock,
  );
  return CheckoutRepositoryFake(catalog: catalog, clock: clock);
}

void main() {
  group('CheckoutRepositoryFake — createHold', () {
    test('creates a hold with a server-computed breakdown (R1)', () async {
      final repo = await _repository();
      final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 2);
      expect(hold.bagId, 'bag_sc_1');
      expect(hold.quantity, 2);
      // price 120 * 2 = 240; platform fee 5% = 12; total = 252.
      expect(hold.breakdown.bagSubtotal.amountInPaise, 24000);
      expect(hold.breakdown.platformFee.amountInPaise, 1200);
      expect(hold.breakdown.total.amountInPaise, 25200);
      expect(hold.breakdown.taxes, isEmpty);
    });

    test('throws BagSoldOutException for a sold-out bag', () async {
      final repo = await _repository();
      await expectLater(
        repo.createHold(bagId: 'bag_sc_3', quantity: 1),
        throwsA(isA<BagSoldOutException>()),
      );
    });

    test(
      'throws BagWindowClosedException once the window has closed',
      () async {
        final repo = await _repository();
        await expectLater(
          repo.createHold(bagId: 'bag_sh_2', quantity: 1),
          throwsA(isA<BagWindowClosedException>()),
        );
      },
    );

    test('throws BagWithdrawnException for a withdrawn bag', () async {
      final repo = await _repository();
      await expectLater(
        repo.createHold(bagId: 'bag_db_2', quantity: 1),
        throwsA(isA<BagWithdrawnException>()),
      );
    });

    test(
      'throws PurchaseCapExceededException over the per-customer allowance (A9)',
      () async {
        final repo = await _repository();
        // bag_sh_1's fixture values: quantityAvailable 3,
        // remainingAllowanceForCustomer 2 — requesting 3 exceeds the cap
        // without also exceeding availability, isolating this exception
        // from BagSoldOutException.
        await expectLater(
          repo.createHold(bagId: 'bag_sh_1', quantity: 3),
          throwsA(isA<PurchaseCapExceededException>()),
        );
      },
    );
  });

  group('CheckoutRepositoryFake — quote and adjustHold', () {
    test('quote never mutates the hold (A11, side-effect-free)', () async {
      final repo = await _repository();
      final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 1);
      await repo.quote(holdId: hold.id, quantity: 2);
      final unchanged = await repo.getHold(hold.id);
      expect(unchanged.quantity, 1);
    });

    test('adjustHold updates quantity and recomputes the breakdown', () async {
      final repo = await _repository();
      final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 1);
      final adjusted = await repo.adjustHold(holdId: hold.id, quantity: 2);
      expect(adjusted.quantity, 2);
      expect(adjusted.breakdown.bagSubtotal.amountInPaise, 24000);
    });

    test(
      'adjustHold throws PurchaseCapExceededException past the cap',
      () async {
        final repo = await _repository();
        final hold = await repo.createHold(bagId: 'bag_sh_1', quantity: 1);
        await expectLater(
          repo.adjustHold(holdId: hold.id, quantity: 3),
          throwsA(isA<PurchaseCapExceededException>()),
        );
      },
    );
  });

  group('CheckoutRepositoryFake — releaseHold and getHold', () {
    test('releaseHold makes the hold unreadable', () async {
      final repo = await _repository();
      final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 1);
      await repo.releaseHold(hold.id);
      await expectLater(
        repo.getHold(hold.id),
        throwsA(isA<HoldExpiredException>()),
      );
    });

    test('getHold throws HoldExpiredException for an unknown id', () async {
      final repo = await _repository();
      await expectLater(
        repo.getHold('hold_never_created'),
        throwsA(isA<HoldExpiredException>()),
      );
    });

    test('a hold past its expiry throws HoldExpiredException', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final repo = await _repository(clock: clock);
      final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 1);
      clock.advance(const Duration(minutes: 10));
      await expectLater(
        repo.getHold(hold.id),
        throwsA(isA<HoldExpiredException>()),
      );
    });
  });

  group('CheckoutRepositoryFake — createOrder (A2)', () {
    test('creates a pending order and payment from a live hold', () async {
      final repo = await _repository();
      final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 1);
      final result = await repo.createOrder(
        holdId: hold.id,
        customerId: 'cust_1',
        method: PaymentMethod.upi,
      );
      expect(result.order.status.name, 'pendingPayment');
      expect(result.payment.status, PaymentStatus.pending);
      expect(result.payment.chargeState, ChargeState.uncertain);
      expect(result.gatewayPayload, isNotEmpty);
    });

    test('freezes the hold — it survives past its own expiresAt', () async {
      final clock = FixedClock(DateTime(2026, 1, 1, 12));
      final repo = await _repository(clock: clock);
      final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 1);
      await repo.createOrder(
        holdId: hold.id,
        customerId: 'cust_1',
        method: PaymentMethod.upi,
      );
      clock.advance(const Duration(minutes: 20)); // past the 540s hold TTL
      // A2 — must not throw HoldExpiredException now that payment is
      // in flight.
      final stillReadable = await repo.getHold(hold.id);
      expect(stillReadable.id, hold.id);
    });

    test('throws HoldExpiredException for an unknown hold', () async {
      final repo = await _repository();
      await expectLater(
        repo.createOrder(
          holdId: 'hold_never_created',
          customerId: 'cust_1',
          method: PaymentMethod.upi,
        ),
        throwsA(isA<HoldExpiredException>()),
      );
    });
  });

  group('CheckoutRepositoryFake — verifyPayment (R3)', () {
    test(
      'the first poll moves to pendingVerification, the second resolves',
      () async {
        final repo = await _repository();
        final hold = await repo.createHold(bagId: 'bag_sc_1', quantity: 1);
        final result = await repo.createOrder(
          holdId: hold.id,
          customerId: 'cust_1',
          method: PaymentMethod.upi,
        );

        final first = await repo.verifyPayment(result.payment.id);
        expect(first.status, PaymentStatus.pendingVerification);

        final second = await repo.verifyPayment(result.payment.id);
        expect(second.status, PaymentStatus.captured);
        expect(second.chargeState, ChargeState.charged);

        final order = await repo.getOrder(result.order.id);
        expect(order.status.name, 'confirmed');
      },
    );

    test('verifyPayment throws NotFoundException for an unknown id', () async {
      final repo = await _repository();
      await expectLater(
        repo.verifyPayment('pay_never_created'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('CheckoutRepositoryFake — getOrder and getUnresolvedOrder', () {
    test('getOrder throws NotFoundException for an unknown id', () async {
      final repo = await _repository();
      await expectLater(
        repo.getOrder('ord_never_created'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test(
      'getUnresolvedOrder is always null (no cross-restart persistence)',
      () async {
        final repo = await _repository();
        expect(await repo.getUnresolvedOrder(), isNull);
      },
    );
  });
}

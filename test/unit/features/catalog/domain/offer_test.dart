import 'package:flutter_test/flutter_test.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/offer.dart';

SurpriseBag _bag({
  Money? price,
  Money? statedRetailValue,
  int quantityTotal = 5,
  int quantityAvailable = 3,
  PickupWindow? pickupWindow,
  DateTime? safeUntil,
}) {
  final window =
      pickupWindow ??
      PickupWindow(
        startAt: DateTime(2026, 1, 1, 20),
        endAt: DateTime(2026, 1, 1, 22),
      );
  return SurpriseBag(
    id: 'bag_1',
    merchantId: 'mer_1',
    title: 'Test bag',
    description: 'A test bag',
    dietaryEnvelope: DietaryEnvelope.containsEgg,
    categoryHint: 'Assorted items',
    price: price ?? const Money.rupees(100),
    statedRetailValue: statedRetailValue ?? const Money.rupees(300),
    discountPercent: 66,
    quantityTotal: quantityTotal,
    quantityAvailable: quantityAvailable,
    pickupWindow: window,
    safeUntil: safeUntil ?? window.endAt,
    imageUrl: 'https://example.com/bag.png',
    pickupInstructions: 'Ask at the counter',
    status: BagStatus.live,
    remainingAllowanceForCustomer: 2,
  );
}

void main() {
  group('SurpriseBag invariants', () {
    test('constructs successfully when every invariant holds', () {
      expect(_bag, returnsNormally);
    });

    test('I1: rejects a pickup window ending after safeUntil', () {
      expect(
        () => _bag(
          pickupWindow: PickupWindow(
            startAt: DateTime(2026, 1, 1, 20),
            endAt: DateTime(2026, 1, 1, 23),
          ),
          safeUntil: DateTime(2026, 1, 1, 22),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('I2: rejects a price that is not less than statedRetailValue', () {
      expect(
        () => _bag(price: const Money.rupees(300)),
        throwsA(isA<AssertionError>()),
      );
    });

    test('I3: rejects quantityAvailable greater than quantityTotal', () {
      expect(
        () => _bag(quantityTotal: 2, quantityAvailable: 3),
        throwsA(isA<AssertionError>()),
      );
    });

    test('I3: rejects a negative quantityAvailable', () {
      expect(
        () => _bag(quantityTotal: 2, quantityAvailable: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

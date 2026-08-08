import 'package:too_good_to_leave_shop/core/domain/clock.dart';
import 'package:too_good_to_leave_shop/core/domain/dietary_envelope.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_token.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';

/// Thrown when a fallback code doesn't match the order it's checked against.
class PickupCodeMismatchException implements Exception {
  const PickupCodeMismatchException();
}

/// In-memory shop-side data — bags this shop lists, and the orders that
/// result. Standalone: nothing here is shared with the customer app, which
/// runs against its own fakes (Phase 1's "build against fakes" pattern,
/// applied on this side too).
class ShopRepository {
  ShopRepository({this._clock = const SystemClock()}) {
    _seed();
  }

  final Clock _clock;
  final List<ShopBag> _bags = [];
  final List<ShopOrder> _orders = [];
  int _nextBagId = 1;

  void _seed() {
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);

    _bags.addAll([
      ShopBag(
        id: 'bag_1',
        title: 'Bakery Surprise Bag',
        description: 'Assorted breads, pastries, and baked leftovers.',
        envelope: DietaryEnvelope.pureVeg,
        price: const Money.rupees(99),
        quantityAvailable: 4,
        pickupWindow: PickupWindow(
          startAt: today.add(const Duration(hours: 19)),
          endAt: today.add(const Duration(hours: 21)),
        ),
        status: BagStatus.live,
      ),
      ShopBag(
        id: 'bag_2',
        title: 'Lunch Combo Surprise',
        description: 'End-of-service curries, rice, and sides.',
        envelope: DietaryEnvelope.nonVeg,
        price: const Money.rupees(149),
        quantityAvailable: 2,
        pickupWindow: PickupWindow(
          startAt: today.add(const Duration(hours: 15)),
          endAt: today.add(const Duration(hours: 16)),
        ),
        status: BagStatus.live,
      ),
      ShopBag(
        id: 'bag_3',
        title: 'Evening Sweets Box',
        description: 'Mixed sweets nearing best-before.',
        envelope: DietaryEnvelope.jain,
        price: const Money.rupees(79),
        quantityAvailable: 0,
        pickupWindow: PickupWindow(
          startAt: today.add(const Duration(hours: 18)),
          endAt: today.add(const Duration(hours: 20)),
        ),
        status: BagStatus.draft,
      ),
    ]);

    _orders.addAll([
      ShopOrder(
        id: 'ord_1',
        bagTitle: 'Bakery Surprise Bag',
        customerName: 'Aditi',
        pickupWindow: _bags[0].pickupWindow,
        token: PickupToken(
          rotatingPayload: 'rot_ord1',
          rotationExpiresAt: now.add(const Duration(seconds: 60)),
          offlineToken: 'off_ord1',
          offlineTokenValidUntil: _bags[0].pickupWindow.endAt,
          fallbackCode: 'H4K9PQ',
        ),
      ),
      ShopOrder(
        id: 'ord_2',
        bagTitle: 'Lunch Combo Surprise',
        customerName: 'Rohan',
        pickupWindow: _bags[1].pickupWindow,
        token: PickupToken(
          rotatingPayload: 'rot_ord2',
          rotationExpiresAt: now.add(const Duration(seconds: 60)),
          offlineToken: 'off_ord2',
          offlineTokenValidUntil: _bags[1].pickupWindow.endAt,
          fallbackCode: 'M7X2DV',
        ),
        status: ShopOrderStatus.collected,
      ),
    ]);
  }

  List<ShopBag> getBags() => List.unmodifiable(_bags);

  List<ShopOrder> getOrders() => List.unmodifiable(_orders);

  ShopBag createBag({
    required String title,
    required String description,
    required DietaryEnvelope envelope,
    required Money price,
    required int quantityAvailable,
    required PickupWindow pickupWindow,
  }) {
    final bag = ShopBag(
      id: 'bag_${_nextBagId++}',
      title: title,
      description: description,
      envelope: envelope,
      price: price,
      quantityAvailable: quantityAvailable,
      pickupWindow: pickupWindow,
    );
    _bags.add(bag);
    return bag;
  }

  void updateBag(ShopBag updated) {
    final index = _bags.indexWhere((b) => b.id == updated.id);
    if (index != -1) _bags[index] = updated;
  }

  void deleteBag(String id) {
    _bags.removeWhere((b) => b.id == id);
  }

  /// Confirms a pickup by fallback code (manual entry) — the counter path
  /// every order supports regardless of whether the QR layers scan (A1).
  ///
  /// Throws [PickupCodeMismatchException] rather than silently no-op-ing
  /// on a wrong code, so the caller can show an explicit "that code doesn't
  /// match" error rather than a pickup that appears to do nothing.
  void confirmPickupByCode({required String orderId, required String code}) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    if (order.token.fallbackCode.toUpperCase() != code.trim().toUpperCase()) {
      throw const PickupCodeMismatchException();
    }
    _orders[index] = order.copyWith(status: ShopOrderStatus.collected);
  }
}

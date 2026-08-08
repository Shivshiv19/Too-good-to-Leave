import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:too_good_to_leave_shop/core/domain/clock.dart';
import 'package:too_good_to_leave_shop/core/domain/dietary_envelope.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_token.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';

/// Thrown when a fallback code doesn't match the order it's checked against.
class PickupCodeMismatchException implements Exception {
  const PickupCodeMismatchException();
}

const _profileKey = 'shop_profile';
const _bagsKey = 'shop_bags';
const _ordersKey = 'shop_orders';

/// Shop-side data — registration, bags, orders, and (as later areas land)
/// payments/analytics/notifications/settings. Standalone: nothing here is
/// shared with the customer app, which runs against its own fakes (Phase
/// 1's "build against fakes" pattern, applied on this side too).
///
/// A [ChangeNotifier] rather than manual per-screen refresh calls — this
/// repository's surface area is only going to grow, and a listenable single
/// source of truth scales better than each screen re-fetching after every
/// mutation it happens to know about.
///
/// Persisted to `shared_preferences` so a browser refresh doesn't wipe a
/// shop's registration and listings — the plain [ShopRepository] constructor
/// stays purely in-memory (seeded with fixtures, no persistence) for tests;
/// [ShopRepository.load] is what the real app uses.
class ShopRepository extends ChangeNotifier {
  ShopRepository({this._clock = const SystemClock()}) {
    _seedOrdersAndBags();
  }

  ShopRepository._loaded({required this._clock});

  /// Loads persisted state, or seeds fresh fixture bags/orders on a shop's
  /// first-ever launch (registration itself is never seeded — every shop
  /// starts unregistered).
  static Future<ShopRepository> load({
    Clock clock = const SystemClock(),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ShopRepository._loaded(clock: clock);

    final profileJson = prefs.getString(_profileKey);
    final bagsJson = prefs.getString(_bagsKey);
    final ordersJson = prefs.getString(_ordersKey);

    if (profileJson == null && bagsJson == null) {
      // First-ever launch on this browser — nothing persisted yet.
      repo._seedOrdersAndBags();
      return repo;
    }

    if (profileJson != null) {
      repo._profile = ShopProfile.fromJson(
        jsonDecode(profileJson) as Map<String, dynamic>,
      );
    }
    if (bagsJson != null) {
      repo._bags.addAll(
        (jsonDecode(bagsJson) as List)
            .cast<Map<String, dynamic>>()
            .map(ShopBag.fromJson),
      );
      repo._nextBagId = repo._bags.length + 1;
    }
    if (ordersJson != null) {
      repo._orders.addAll(
        (jsonDecode(ordersJson) as List)
            .cast<Map<String, dynamic>>()
            .map(ShopOrder.fromJson),
      );
    }
    return repo;
  }

  final Clock _clock;

  ShopProfile? _profile;
  final List<ShopBag> _bags = [];
  final List<ShopOrder> _orders = [];
  int _nextBagId = 1;

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_profile != null) {
      await prefs.setString(_profileKey, jsonEncode(_profile!.toJson()));
    }
    await prefs.setString(
      _bagsKey,
      jsonEncode(_bags.map((b) => b.toJson()).toList()),
    );
    await prefs.setString(
      _ordersKey,
      jsonEncode(_orders.map((o) => o.toJson()).toList()),
    );
  }

  void _seedOrdersAndBags() {
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

  // ---------------------------------------------------------------------
  // Registration / account
  // ---------------------------------------------------------------------

  ShopProfile? get profile => _profile;

  bool get isRegistered => _profile != null;

  Future<void> register(ShopProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _persist();
  }

  /// Stands in for a real review process — there's no admin surface in this
  /// standalone build, so approval is a demo action the registration flow's
  /// own "pending review" screen exposes, rather than something that
  /// silently never resolves.
  Future<void> simulateApproval() async {
    final current = _profile;
    if (current == null) return;
    _profile = current.copyWith(status: ShopApprovalStatus.verified);
    notifyListeners();
    await _persist();
  }

  Future<void> updateProfile(ShopProfile updated) async {
    _profile = updated;
    notifyListeners();
    await _persist();
  }

  /// Clears everything for this browser — the standalone equivalent of a
  /// real "log out and forget this device," since there's no server-side
  /// session to end.
  Future<void> logOut() async {
    _profile = null;
    _bags.clear();
    _orders.clear();
    _nextBagId = 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_bagsKey);
    await prefs.remove(_ordersKey);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Bags
  // ---------------------------------------------------------------------

  List<ShopBag> getBags() => List.unmodifiable(_bags);

  Future<ShopBag> createBag({
    required String title,
    required String description,
    required DietaryEnvelope envelope,
    required Money price,
    required int quantityAvailable,
    required PickupWindow pickupWindow,
  }) async {
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
    notifyListeners();
    await _persist();
    return bag;
  }

  Future<void> updateBag(ShopBag updated) async {
    final index = _bags.indexWhere((b) => b.id == updated.id);
    if (index != -1) _bags[index] = updated;
    notifyListeners();
    await _persist();
  }

  Future<void> deleteBag(String id) async {
    _bags.removeWhere((b) => b.id == id);
    notifyListeners();
    await _persist();
  }

  // ---------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------

  List<ShopOrder> getOrders() => List.unmodifiable(_orders);

  /// Confirms a pickup by fallback code (manual entry) — the counter path
  /// every order supports regardless of whether the QR layers scan (A1).
  ///
  /// Throws [PickupCodeMismatchException] rather than silently no-op-ing
  /// on a wrong code, so the caller can show an explicit "that code doesn't
  /// match" error rather than a pickup that appears to do nothing.
  Future<void> confirmPickupByCode({
    required String orderId,
    required String code,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    if (order.token.fallbackCode.toUpperCase() != code.trim().toUpperCase()) {
      throw const PickupCodeMismatchException();
    }
    _orders[index] = order.copyWith(status: ShopOrderStatus.collected);
    notifyListeners();
    await _persist();
  }
}

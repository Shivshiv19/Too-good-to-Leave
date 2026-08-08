import 'dart:math';

import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/domain/price_breakdown.dart';
import 'package:surplus_marketplace/core/domain/tax_line.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/hold.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order_snapshots.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order_status.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_method.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_status.dart';
import 'package:surplus_marketplace/features/checkout/domain/repositories/checkout_repository.dart';

class _PaymentState {
  _PaymentState(this.payment) : verifyCalls = 0;

  Payment payment;
  int verifyCalls;
}

/// Stands in for the server (Phase 1 locked decision) — the highest-risk
/// area in the app (Phase 5c, Phase 7 §7.5).
///
/// **Fixture policy numbers are hardcoded here**, matching (not read from)
/// `ConfigRepositoryFake`'s `holdTtlSeconds: 540` — the same
/// no-cross-fake-wiring precedent as `catalog`'s D-b6 purchase-cap
/// duplication. `bootstrap.dart` constructs every repository synchronously
/// before any `Future<RemoteConfig>` resolves, so a real dependency on
/// `policyValues` here would need async DI this codebase doesn't have yet.
///
/// **No cross-restart persistence.** `_holds`/`_orders`/`_payments` are
/// plain in-memory maps, unlike `location`'s/`catalog`'s `Prefs`-backed
/// state — a real kill-and-relaunch loses everything here exactly as it
/// would if this were real server state the client merely cached. This
/// does mean `getUnresolvedOrder` (A3) has no scenario to demonstrate
/// end-to-end without a real backend; the route and screen it feeds are
/// still fully built and wired for when one exists.
final class CheckoutRepositoryFake implements CheckoutRepository {
  CheckoutRepositoryFake({
    required CatalogRepository catalog,
    required Clock clock,
  }) : _catalog = catalog,
       _clock = clock;

  final CatalogRepository _catalog;
  final Clock _clock;
  final _random = Random.secure();

  static const _holdTtl = Duration(seconds: 540);
  static const _platformFeeRatePercent = 5;

  final _holds = <String, Hold>{};
  final _frozenHoldIds = <String>{};
  final _orders = <String, Order>{};
  final _payments = <String, _PaymentState>{};

  @override
  Future<Hold> getHold(String holdId) async {
    final hold = _holds[holdId];
    if (hold == null) throw HoldExpiredException(bagId: '');
    if (_clock.now().isAfter(hold.expiresAt) &&
        !_frozenHoldIds.contains(holdId)) {
      _holds.remove(holdId);
      throw HoldExpiredException(bagId: hold.bagId);
    }
    return hold;
  }

  @override
  Future<Hold> createHold({
    required String bagId,
    required int quantity,
  }) async {
    final bag = await _catalog.bag(bagId); // fresh fetch — exact A8 count
    await _assertBagReservable(bag.merchantId, bagId, bag.status);
    if (quantity > bag.quantityAvailable) {
      throw BagSoldOutException(
        alternativeBagIds: await _alternatives(bag.merchantId, bagId),
      );
    }
    if (quantity > bag.remainingAllowanceForCustomer) {
      throw PurchaseCapExceededException(
        remainingAllowance: bag.remainingAllowanceForCustomer,
      );
    }
    final breakdown = _computeBreakdown(bag.price, quantity);
    final hold = Hold(
      id: _nextId('hold'),
      bagId: bagId,
      merchantId: bag.merchantId,
      quantity: quantity,
      expiresAt: _clock.now().add(_holdTtl),
      breakdown: breakdown,
    );
    _holds[hold.id] = hold;
    return hold;
  }

  @override
  Future<PriceBreakdown> quote({
    required String holdId,
    required int quantity,
  }) async {
    final hold = _requireHold(holdId);
    final bag = await _catalog.bag(hold.bagId);
    return _computeBreakdown(bag.price, quantity);
  }

  @override
  Future<Hold> adjustHold({
    required String holdId,
    required int quantity,
  }) async {
    final hold = _requireHold(holdId);
    final bag = await _catalog.bag(hold.bagId);
    if (quantity > bag.quantityAvailable) {
      throw BagSoldOutException(
        alternativeBagIds: await _alternatives(bag.merchantId, hold.bagId),
      );
    }
    if (quantity > bag.remainingAllowanceForCustomer) {
      throw PurchaseCapExceededException(
        remainingAllowance: bag.remainingAllowanceForCustomer,
      );
    }
    final updated = hold.copyWith(
      quantity: quantity,
      breakdown: _computeBreakdown(bag.price, quantity),
    );
    _holds[holdId] = updated;
    return updated;
  }

  @override
  Future<void> releaseHold(String holdId) async {
    _holds.remove(holdId);
    _frozenHoldIds.remove(holdId);
  }

  @override
  Future<OrderCreationResult> createOrder({
    required String holdId,
    required String customerId,
    required PaymentMethod method,
    String? upiApp,
  }) async {
    final hold = _holds[holdId];
    if (hold == null) {
      throw HoldExpiredException(bagId: '');
    }
    if (_clock.now().isAfter(hold.expiresAt) &&
        !_frozenHoldIds.contains(holdId)) {
      _holds.remove(holdId);
      throw HoldExpiredException(bagId: hold.bagId);
    }

    final bag = await _catalog.bag(hold.bagId); // R2 — revalidate again
    if (bag.status != BagStatus.live || bag.quantityAvailable < hold.quantity) {
      throw BagSoldOutException(
        alternativeBagIds: await _alternatives(bag.merchantId, bag.id),
      );
    }
    final merchant = await _catalog.merchant(bag.merchantId);

    // A2 — the hold is frozen from this point: it must not expire while
    // payment is pending/pendingVerification.
    _frozenHoldIds.add(holdId);

    final orderId = _nextId('ord');
    final paymentId = _nextId('pay');

    final order = Order(
      id: orderId,
      orderCode: _generateOrderCode(),
      customerId: customerId,
      holdId: holdId,
      merchantSnapshot: OrderMerchantSnapshot(
        id: merchant.id,
        legalName: merchant.legalName,
        displayName: merchant.displayName,
        address: merchant.address,
        phone: merchant.phone,
        fssaiLicenceNumber: merchant.fssaiLicenceNumber,
        fssaiLicenceExpiry: merchant.fssaiLicenceExpiry,
        grievanceContact: merchant.grievanceContact,
      ),
      bagSnapshot: OrderBagSnapshot(
        bagId: bag.id,
        title: bag.title,
        dietaryEnvelope: bag.dietaryEnvelope,
        imageUrl: bag.imageUrl,
      ),
      quantity: hold.quantity,
      breakdown: hold.breakdown,
      pickupWindow: PickupWindow(
        startAt: bag.pickupWindow.startAt,
        endAt: bag.pickupWindow.endAt,
      ),
      status: OrderStatus.pendingPayment,
      payment: Payment(
        id: paymentId,
        orderId: orderId,
        method: method,
        gatewayRef: 'gw_${_randomHex(10)}',
        amount: hold.breakdown.total,
        status: PaymentStatus.pending,
        attempts: 1,
        chargeState: ChargeState.uncertain,
        maskedIdentifier: _randomDigits(4),
      ),
      createdAt: _clock.now(),
    );

    _orders[orderId] = order;
    _payments[paymentId] = _PaymentState(order.payment);

    return OrderCreationResult(
      order: order,
      payment: order.payment,
      gatewayPayload: 'payload_${_randomHex(12)}',
    );
  }

  @override
  Future<Payment> verifyPayment(String paymentId) async {
    final state = _payments[paymentId];
    if (state == null) throw const NotFoundException();

    // First poll: move from pending to the "checking with your bank" state
    // (§5c.6). Subsequent polls resolve — always to success in this fake,
    // a deliberate simplification (see class doc's sibling decision on
    // `PaymentGatewayFake`): there is no real gateway to fail against
    // meaningfully, and a demo flow that sometimes randomly fails is worse
    // for reliably exercising the happy path than one that doesn't.
    state.verifyCalls++;
    if (state.verifyCalls == 1) {
      state.payment = _withStatus(
        state.payment,
        PaymentStatus.pendingVerification,
      );
      return state.payment;
    }

    state.payment = _withStatus(
      state.payment,
      PaymentStatus.captured,
      chargeState: ChargeState.charged,
    );
    final order = _orders[state.payment.orderId];
    if (order != null) {
      _orders[order.id] = Order(
        id: order.id,
        orderCode: order.orderCode,
        customerId: order.customerId,
        holdId: order.holdId,
        merchantSnapshot: order.merchantSnapshot,
        bagSnapshot: order.bagSnapshot,
        quantity: order.quantity,
        breakdown: order.breakdown,
        pickupWindow: order.pickupWindow,
        status: OrderStatus.confirmed,
        payment: state.payment,
        createdAt: order.createdAt,
      );
    }
    return state.payment;
  }

  @override
  Future<Payment> getPayment(String paymentId) async {
    final state = _payments[paymentId];
    if (state == null) throw const NotFoundException();
    return state.payment;
  }

  @override
  Future<UnresolvedPayment?> getUnresolvedOrder() async => null;

  @override
  Future<Order> getOrder(String orderId) async {
    final order = _orders[orderId];
    if (order == null) throw const NotFoundException();
    return order;
  }

  /// **Fake-to-fake wiring only** — not part of the `CheckoutRepository`
  /// contract, which mirrors §7.5 alone. `OrdersRepositoryFake` (§7.6)
  /// reads through this exactly as a real orders service would read from
  /// the same orders table checkout writes to, rather than maintaining a
  /// second, divergent copy of every order ever created.
  List<Order> ordersForCustomer(String customerId) =>
      _orders.values.where((o) => o.customerId == customerId).toList();

  /// **Fake-to-fake wiring only** — lets `OrdersRepositoryFake` persist a
  /// derived status change (e.g. a lapsed pickup window becoming
  /// `expiredUncollected`) or a cancellation back into the one shared
  /// order store, instead of the two features silently disagreeing about
  /// an order's current state.
  void updateOrder(Order order) => _orders[order.id] = order;

  Future<void> _assertBagReservable(
    String merchantId,
    String bagId,
    BagStatus status,
  ) async {
    switch (status) {
      case BagStatus.soldOut:
        throw BagSoldOutException(
          alternativeBagIds: await _alternatives(merchantId, bagId),
        );
      case BagStatus.withdrawnByMerchant:
        throw BagWithdrawnException(
          alternativeBagIds: await _alternatives(merchantId, bagId),
        );
      case BagStatus.windowClosed:
        throw const BagWindowClosedException();
      case BagStatus.live:
      case BagStatus.draft:
        return;
    }
  }

  Future<List<String>> _alternatives(
    String merchantId,
    String excludingBagId,
  ) async {
    final bags = await _catalog.merchantBags(merchantId, _zeroLatLng);
    return bags
        .where((b) => b.id != excludingBagId)
        .take(3)
        .map((b) => b.id)
        .toList();
  }

  Hold _requireHold(String holdId) {
    final hold = _holds[holdId];
    if (hold == null) throw HoldExpiredException(bagId: '');
    return hold;
  }

  Payment _withStatus(
    Payment payment,
    PaymentStatus status, {
    ChargeState? chargeState,
  }) => Payment(
    id: payment.id,
    orderId: payment.orderId,
    method: payment.method,
    gatewayRef: payment.gatewayRef,
    amount: payment.amount,
    status: status,
    attempts: payment.attempts,
    chargeState: chargeState ?? payment.chargeState,
    refund: payment.refund,
    failureReason: payment.failureReason,
    maskedIdentifier: payment.maskedIdentifier,
  );

  /// Server-computed (R1) — legal here only because a fake repository
  /// stands in for the server (`Money`'s own class doc). **Taxes are
  /// deliberately an empty list**, not an invented GST line: Phase 1 §3.3
  /// flags GST §9(5) treatment as an open legal question, and asserting a
  /// specific rate here would risk being mistaken for a real policy
  /// decision rather than fixture data.
  PriceBreakdown _computeBreakdown(Money unitPrice, int quantity) {
    final subtotal = unitPrice * quantity;
    final fee = Money(subtotal.amountInPaise * _platformFeeRatePercent ~/ 100);
    return PriceBreakdown(
      bagSubtotal: subtotal,
      platformFee: fee,
      taxes: const <TaxLine>[],
      total: subtotal + fee,
    );
  }

  String _generateOrderCode() {
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // excludes 0/O, 1/I/L
    final code = List.generate(
      4,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
    return 'SV-$code';
  }

  String _randomHex(int length) => List.generate(
    length,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();

  String _randomDigits(int length) =>
      List.generate(length, (_) => _random.nextInt(10)).join();

  int _idSeq = 0;
  String _nextId(String prefix) =>
      '${prefix}_${_clock.now().microsecondsSinceEpoch}_${_idSeq++}';
}

const _zeroLatLng = LatLng(latitude: 0, longitude: 0);

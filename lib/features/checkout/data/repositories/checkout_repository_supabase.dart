import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surplus_marketplace/core/domain/address.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_token.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/domain/price_breakdown.dart';
import 'package:surplus_marketplace/core/domain/tax_line.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';

const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // excludes 0/O,1/I/L
final _random = Random.secure();

String _randomCode(int length) =>
    List.generate(length, (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)]).join();

String _paymentMethodToWire(PaymentMethod m) => switch (m) {
  PaymentMethod.upi => 'upi',
  PaymentMethod.card => 'card',
  PaymentMethod.netBanking => 'net_banking',
  PaymentMethod.wallet => 'wallet',
};

PaymentMethod _paymentMethodFromWire(String v) => switch (v) {
  'net_banking' => PaymentMethod.netBanking,
  'card' => PaymentMethod.card,
  'wallet' => PaymentMethod.wallet,
  _ => PaymentMethod.upi,
};

OrderStatus _orderStatusFromWire(String v) => switch (v) {
  'pending_payment' => OrderStatus.pendingPayment,
  'confirmed' => OrderStatus.confirmed,
  'payment_failed' => OrderStatus.paymentFailed,
  'ready_for_pickup' => OrderStatus.readyForPickup,
  'collected' => OrderStatus.collected,
  'cancelled_by_customer' => OrderStatus.cancelledByCustomer,
  'cancelled_by_merchant' => OrderStatus.cancelledByMerchant,
  'expired_uncollected' => OrderStatus.expiredUncollected,
  _ => OrderStatus.pendingPayment,
};

PaymentStatus _paymentStatusFromWire(String v) => switch (v) {
  'created' => PaymentStatus.created,
  'pending' => PaymentStatus.pending,
  'pending_verification' => PaymentStatus.pendingVerification,
  'captured' => PaymentStatus.captured,
  'failed' => PaymentStatus.failed,
  'cancelled' => PaymentStatus.cancelled,
  'refund_initiated' => PaymentStatus.refundInitiated,
  'refunded' => PaymentStatus.refunded,
  'refund_failed' => PaymentStatus.refundFailed,
  _ => PaymentStatus.pendingVerification,
};

Map<String, dynamic> _generatePickupTokenJson(DateTime pickupEnd) => {
  'rotatingPayload': _randomCode(24),
  'rotationExpiresAt': DateTime.now()
      .add(const Duration(seconds: 60))
      .toIso8601String(),
  'offlineToken': _randomCode(24),
  'offlineTokenValidUntil': pickupEnd.toIso8601String(),
  'fallbackCode': _randomCode(6),
};

PickupToken _pickupTokenFromJson(Map<String, dynamic> j) => PickupToken(
  rotatingPayload: j['rotatingPayload'] as String,
  rotationExpiresAt: DateTime.parse(j['rotationExpiresAt'] as String),
  offlineToken: j['offlineToken'] as String,
  offlineTokenValidUntil: DateTime.parse(
    j['offlineTokenValidUntil'] as String,
  ),
  fallbackCode: j['fallbackCode'] as String,
);

Map<String, dynamic> _bagSnapshotJson(Map<String, dynamic> bagRow) => {
  'bagId': bagRow['id'],
  'title': bagRow['title'],
  'dietaryEnvelope': bagRow['dietary_envelope'],
  'imageUrl': bagRow['image_url'] ?? '',
};

OrderBagSnapshot _bagSnapshotFromJson(Map<String, dynamic> j) =>
    OrderBagSnapshot(
      bagId: j['bagId'] as String,
      title: j['title'] as String,
      dietaryEnvelope: DietaryEnvelope.fromWire(
        j['dietaryEnvelope'] as String,
      ),
      imageUrl: j['imageUrl'] as String? ?? '',
    );

Map<String, dynamic> _shopSnapshotJson(Map<String, dynamic> shopRow) => {
  'id': shopRow['id'],
  'legalName': shopRow['legal_name'],
  'displayName': shopRow['display_name'],
  'phone': shopRow['phone'],
  'fssaiLicenceNumber': shopRow['fssai_license_number'],
  'fssaiLicenceExpiry': shopRow['fssai_license_expiry'],
  'grievanceContact': shopRow['grievance_contact'] ?? '',
  'address': {
    'line1': shopRow['address_line1'],
    'line2': shopRow['address_line2'],
    'floorOrShopNo': shopRow['floor_or_shop_no'],
    'landmark': shopRow['landmark'],
    'locality': shopRow['locality'],
    'city': shopRow['city'],
    'state': shopRow['state'],
    'pincode': shopRow['pincode'],
    'lat': shopRow['lat'],
    'lng': shopRow['lng'],
  },
};

OrderMerchantSnapshot _merchantSnapshotFromJson(Map<String, dynamic> j) {
  final addr = (j['address'] as Map).cast<String, dynamic>();
  return OrderMerchantSnapshot(
    id: j['id'] as String,
    legalName: j['legalName'] as String,
    displayName: j['displayName'] as String,
    address: Address(
      line1: addr['line1'] as String,
      line2: addr['line2'] as String?,
      floorOrShopNo: addr['floorOrShopNo'] as String?,
      landmark: addr['landmark'] as String,
      locality: addr['locality'] as String,
      city: addr['city'] as String,
      state: addr['state'] as String,
      pincode: addr['pincode'] as String,
      geo: LatLng(
        latitude: (addr['lat'] as num).toDouble(),
        longitude: (addr['lng'] as num).toDouble(),
      ),
    ),
    phone: j['phone'] as String,
    fssaiLicenceNumber: j['fssaiLicenceNumber'] as String,
    fssaiLicenceExpiry: DateTime.parse(j['fssaiLicenceExpiry'] as String),
    grievanceContact: j['grievanceContact'] as String? ?? '',
  );
}

Map<String, dynamic> _breakdownToJson(PriceBreakdown b) => {
  'bagSubtotal': b.bagSubtotal.amountInPaise,
  'platformFee': b.platformFee.amountInPaise,
  'taxes': b.taxes
      .map((t) => {'label': t.label, 'amount': t.amount.amountInPaise})
      .toList(),
  'discount': b.discount?.amountInPaise,
  'total': b.total.amountInPaise,
};

PriceBreakdown _breakdownFromJson(Map<String, dynamic> j) => PriceBreakdown(
  bagSubtotal: Money(j['bagSubtotal'] as int),
  platformFee: Money(j['platformFee'] as int),
  taxes: ((j['taxes'] as List?) ?? const [])
      .map(
        (t) => TaxLine(
          label: (t as Map)['label'] as String,
          amount: Money(t['amount'] as int),
        ),
      )
      .toList(),
  discount: j['discount'] == null ? null : Money(j['discount'] as int),
  total: Money(j['total'] as int),
);

Payment _missingPayment(String orderId) => Payment(
  id: 'unknown',
  orderId: orderId,
  method: PaymentMethod.upi,
  gatewayRef: '',
  amount: const Money.zero(),
  status: PaymentStatus.pendingVerification,
  attempts: 0,
  chargeState: ChargeState.uncertain,
);

Payment _paymentFromRow(Map<String, dynamic> row) => Payment(
  id: row['id'] as String,
  orderId: row['order_id'] as String,
  method: _paymentMethodFromWire(row['method'] as String),
  gatewayRef: row['gateway_ref'] as String? ?? '',
  amount: Money(row['amount_paise'] as int),
  status: _paymentStatusFromWire(row['status'] as String),
  attempts: (row['attempts'] as int?) ?? 1,
  // The fake gateway never leaves this ambiguous — it captures
  // synchronously at order creation, so a real debit either always
  // happened (this) or the order row never exists at all.
  chargeState: ChargeState.charged,
  maskedIdentifier: row['masked_identifier'] as String?,
  failureReason: row['failure_reason'] as String?,
);

Order _orderFromRows(
  Map<String, dynamic> row,
  Map<String, dynamic>? paymentRow,
) => Order(
  id: row['id'] as String,
  orderCode: row['order_code'] as String,
  customerId: row['customer_id'] as String,
  // Holds aren't persisted server-side (no `holds` table — see class doc);
  // nothing meaningful survives to reference here after creation.
  holdId: '',
  merchantSnapshot: _merchantSnapshotFromJson(
    (row['shop_snapshot'] as Map).cast<String, dynamic>(),
  ),
  bagSnapshot: _bagSnapshotFromJson(
    (row['bag_snapshot'] as Map).cast<String, dynamic>(),
  ),
  quantity: row['quantity'] as int,
  breakdown: _breakdownFromJson(
    (row['price_breakdown'] as Map).cast<String, dynamic>(),
  ),
  pickupWindow: PickupWindow(
    startAt: DateTime.parse(row['pickup_start_at'] as String),
    endAt: DateTime.parse(row['pickup_end_at'] as String),
  ),
  status: _orderStatusFromWire(row['status'] as String),
  payment: paymentRow != null
      ? _paymentFromRow(paymentRow)
      : _missingPayment(row['id'] as String),
  pickupToken: row['pickup_token'] == null
      ? null
      : _pickupTokenFromJson((row['pickup_token'] as Map).cast<String, dynamic>()),
  createdAt: DateTime.parse(row['created_at'] as String),
  collectedAt: row['collected_at'] == null
      ? null
      : DateTime.parse(row['collected_at'] as String),
  cancelledAt: row['cancelled_at'] == null
      ? null
      : DateTime.parse(row['cancelled_at'] as String),
  cancellationReason: row['cancellation_reason'] as String?,
);

/// A hold's live state, kept in memory only — there is no `holds` table in
/// the shared schema (see class doc for why).
final class _HoldState {
  _HoldState({
    required this.bagId,
    required this.merchantId,
    required this.quantity,
    required this.expiresAt,
    required this.breakdown,
  });

  final String bagId;
  final String merchantId;
  int quantity;
  DateTime expiresAt;
  PriceBreakdown breakdown;
}

/// Creates real, live-synced orders against the shared Supabase `orders`/
/// `bags`/`payments` tables (`supabase/schema.sql`) — this is the write
/// side of the customer → shop realtime lifecycle: inserting a row here is
/// what the shop app's Realtime subscription (`shop_repository.dart`)
/// notices and turns into a "new order" notification.
///
/// **Holds are session-local, not server-persisted** — the schema has no
/// `holds` table (Phase 1 scope), so [createHold]/[getHold]/[adjustHold]
/// operate on an in-memory map keyed by a locally generated id. This means
/// a hold can't survive an app restart (§4.8's cold-start resume from a
/// bare `holdId` in the URL won't find anything) — an accepted gap for this
/// pass; [createOrder] re-validates live availability against Supabase
/// regardless, so the one guarantee that matters (never oversell) still
/// holds even though the *hold* itself is soft state.
///
/// **Payment is fake by explicit product scope** ("hardcoded OTP, fake
/// payment scenario") — [createOrder] writes a `payments` row that's
/// already `captured`; there is no gateway round-trip, so
/// [getUnresolvedOrder] can never find anything in flight.
final class CheckoutRepositorySupabase implements CheckoutRepository {
  SupabaseClient get _client => Supabase.instance.client;

  final Map<String, _HoldState> _holds = {};
  int _holdSeq = 0;

  Future<Map<String, dynamic>> _customerSnapshotJson(String customerId) async {
    final row = await _client
        .from('customers')
        .select('name')
        .eq('id', customerId)
        .maybeSingle();
    return {'name': (row?['name'] as String?) ?? 'Customer'};
  }

  @override
  Future<Hold> createHold({required String bagId, required int quantity}) async {
    final bagRow = await _client
        .from('bags')
        .select()
        .eq('id', bagId)
        .maybeSingle();
    if (bagRow == null) throw const NotFoundException();
    final status = bagRow['status'] as String;
    if (status == 'withdrawn_by_merchant') {
      throw const BagWithdrawnException();
    }
    if (status != 'live') throw const BagSoldOutException();
    final available = bagRow['quantity_available'] as int;
    if (quantity > available) throw const BagSoldOutException();

    final cap = (bagRow['purchase_cap_per_customer'] as int?) ?? 2;
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      final remaining = await _remainingAllowance(bagId, userId, cap);
      if (quantity > remaining) {
        throw PurchaseCapExceededException(remainingAllowance: remaining);
      }
    }

    final holdId = 'hold_${_holdSeq++}_${_randomCode(6)}';
    final price = Money(bagRow['price_paise'] as int);
    final breakdown = PriceBreakdown(
      bagSubtotal: price * quantity,
      platformFee: const Money.zero(),
      taxes: const [],
      total: price * quantity,
    );
    _holds[holdId] = _HoldState(
      bagId: bagId,
      merchantId: bagRow['shop_id'] as String,
      quantity: quantity,
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      breakdown: breakdown,
    );
    final hold = _holds[holdId]!;
    return Hold(
      id: holdId,
      bagId: hold.bagId,
      merchantId: hold.merchantId,
      quantity: hold.quantity,
      expiresAt: hold.expiresAt,
      breakdown: hold.breakdown,
    );
  }

  Future<int> _remainingAllowance(
    String bagId,
    String customerId,
    int cap,
  ) async {
    final orderedRows = await _client
        .from('orders')
        .select('quantity')
        .eq('bag_id', bagId)
        .eq('customer_id', customerId)
        .not(
          'status',
          'in',
          '(cancelled_by_customer,cancelled_by_merchant,payment_failed)',
        );
    final already = (orderedRows as List)
        .cast<Map<String, dynamic>>()
        .fold<int>(0, (sum, o) => sum + (o['quantity'] as int));
    return (cap - already).clamp(0, cap);
  }

  @override
  Future<Hold> getHold(String holdId) async {
    final hold = _holds[holdId];
    if (hold == null || hold.expiresAt.isBefore(DateTime.now())) {
      throw HoldExpiredException(bagId: hold?.bagId ?? '');
    }
    return Hold(
      id: holdId,
      bagId: hold.bagId,
      merchantId: hold.merchantId,
      quantity: hold.quantity,
      expiresAt: hold.expiresAt,
      breakdown: hold.breakdown,
    );
  }

  @override
  Future<PriceBreakdown> quote({
    required String holdId,
    required int quantity,
  }) async {
    final hold = _holds[holdId];
    if (hold == null) throw HoldExpiredException(bagId: '');
    final bagRow = await _client
        .from('bags')
        .select('price_paise')
        .eq('id', hold.bagId)
        .maybeSingle();
    if (bagRow == null) throw const NotFoundException();
    final price = Money(bagRow['price_paise'] as int);
    return PriceBreakdown(
      bagSubtotal: price * quantity,
      platformFee: const Money.zero(),
      taxes: const [],
      total: price * quantity,
    );
  }

  @override
  Future<Hold> adjustHold({required String holdId, required int quantity}) async {
    final hold = _holds[holdId];
    if (hold == null) throw HoldExpiredException(bagId: '');
    final bagRow = await _client
        .from('bags')
        .select()
        .eq('id', hold.bagId)
        .maybeSingle();
    if (bagRow == null) throw const NotFoundException();
    final available = bagRow['quantity_available'] as int;
    if (quantity > available) throw const BagSoldOutException();
    final price = Money(bagRow['price_paise'] as int);
    hold.quantity = quantity;
    hold.breakdown = PriceBreakdown(
      bagSubtotal: price * quantity,
      platformFee: const Money.zero(),
      taxes: const [],
      total: price * quantity,
    );
    return Hold(
      id: holdId,
      bagId: hold.bagId,
      merchantId: hold.merchantId,
      quantity: hold.quantity,
      expiresAt: hold.expiresAt,
      breakdown: hold.breakdown,
    );
  }

  @override
  Future<void> releaseHold(String holdId) async {
    _holds.remove(holdId);
  }

  @override
  Future<OrderCreationResult> createOrder({
    required String holdId,
    required String customerId,
    required PaymentMethod method,
    String? upiApp,
  }) async {
    final hold = _holds[holdId];
    if (hold == null || hold.expiresAt.isBefore(DateTime.now())) {
      throw HoldExpiredException(bagId: hold?.bagId ?? '');
    }
    final bagRow = await _client
        .from('bags')
        .select()
        .eq('id', hold.bagId)
        .maybeSingle();
    if (bagRow == null) throw const NotFoundException();
    if (bagRow['status'] != 'live' ||
        (bagRow['quantity_available'] as int) < hold.quantity) {
      throw const BagSoldOutException();
    }
    final shopRow = await _client
        .from('shops')
        .select()
        .eq('id', hold.merchantId)
        .maybeSingle();
    if (shopRow == null) throw const NotFoundException();

    final pickupStart = DateTime.parse(bagRow['pickup_start_at'] as String);
    final pickupEnd = DateTime.parse(bagRow['pickup_end_at'] as String);

    // A single `security definer` RPC, not three separate REST calls — the
    // order insert, the shop-owned bag's stock decrement, and the payment
    // insert must all happen atomically (a customer session has no RLS
    // grant to update someone else's bag or insert a payment row directly;
    // see `create_order_and_pay`'s own doc comment in schema.sql). It also
    // row-locks the bag, closing the race where two holds on the last unit
    // could otherwise both succeed.
    final Object? result;
    try {
      result = await _client.rpc(
        'create_order_and_pay',
        params: {
          'p_bag_id': hold.bagId,
          'p_quantity': hold.quantity,
          'p_shop_snapshot': _shopSnapshotJson(shopRow),
          'p_bag_snapshot': _bagSnapshotJson(bagRow),
          'p_customer_snapshot': await _customerSnapshotJson(customerId),
          'p_price_breakdown': _breakdownToJson(hold.breakdown),
          'p_pickup_start_at': pickupStart.toIso8601String(),
          'p_pickup_end_at': pickupEnd.toIso8601String(),
          'p_pickup_token': _generatePickupTokenJson(pickupEnd),
          'p_payment_method': _paymentMethodToWire(method),
          'p_gateway_ref': 'FAKE-${_randomCode(10)}',
          'p_amount_paise': hold.breakdown.total.amountInPaise,
        },
      );
    } on PostgrestException catch (e) {
      // The RPC re-validates live stock under a row lock (closing the race
      // the pre-check above can't) — surface that the same way the
      // pre-check does rather than as a raw server error.
      if (e.message.contains('insufficient stock') ||
          e.message.contains('bag is not live')) {
        throw const BagSoldOutException();
      }
      rethrow;
    }
    final resultMap = (result! as Map).cast<String, dynamic>();
    final orderRow = (resultMap['order'] as Map).cast<String, dynamic>();
    final paymentRow = (resultMap['payment'] as Map).cast<String, dynamic>();

    _holds.remove(holdId);

    return OrderCreationResult(
      order: _orderFromRows(orderRow, paymentRow),
      payment: _paymentFromRow(paymentRow),
      gatewayPayload: 'fake-gateway-payload',
    );
  }

  @override
  Future<Payment> verifyPayment(String paymentId) => getPayment(paymentId);

  @override
  Future<Payment> getPayment(String paymentId) async {
    final row = await _client
        .from('payments')
        .select()
        .eq('id', paymentId)
        .maybeSingle();
    if (row == null) throw const NotFoundException();
    return _paymentFromRow(row);
  }

  @override
  Future<UnresolvedPayment?> getUnresolvedOrder() async =>
      // The fake gateway captures synchronously inside createOrder — there
      // is never a payment left mid-flight to resume.
      null;

  @override
  Future<Order> getOrder(String orderId) async {
    final row = await _client
        .from('orders')
        .select()
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) throw const NotFoundException();
    final paymentRow = await _client
        .from('payments')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();
    return _orderFromRows(row, paymentRow);
  }
}

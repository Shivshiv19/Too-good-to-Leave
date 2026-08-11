import 'dart:math';
import 'dart:typed_data';

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
import 'package:surplus_marketplace/features/orders/orders.dart';

const _activeStatuses = {
  OrderStatus.pendingPayment,
  OrderStatus.confirmed,
  OrderStatus.paymentFailed,
  OrderStatus.readyForPickup,
};

/// A15 — mirrors the shop-side registration form's own conventions: no
/// remote config table exists for this yet, so the cutoff is a fixed
/// constant, same as `OrdersRepositoryFake`'s equivalent.
const _cancellationCutoffBeforeWindow = Duration(minutes: 60);

const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
final _random = Random.secure();
String _randomCode(int length) => List.generate(
  length,
  (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
).join();

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

String _orderStatusToWire(OrderStatus s) => switch (s) {
  OrderStatus.pendingPayment => 'pending_payment',
  OrderStatus.confirmed => 'confirmed',
  OrderStatus.paymentFailed => 'payment_failed',
  OrderStatus.readyForPickup => 'ready_for_pickup',
  OrderStatus.collected => 'collected',
  OrderStatus.cancelledByCustomer => 'cancelled_by_customer',
  OrderStatus.cancelledByMerchant => 'cancelled_by_merchant',
  OrderStatus.expiredUncollected => 'expired_uncollected',
};

PaymentMethod _paymentMethodFromWire(String v) => switch (v) {
  'net_banking' => PaymentMethod.netBanking,
  'card' => PaymentMethod.card,
  'wallet' => PaymentMethod.wallet,
  _ => PaymentMethod.upi,
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

PickupToken _pickupTokenFromJson(Map<String, dynamic> j) => PickupToken(
  rotatingPayload: j['rotatingPayload'] as String,
  rotationExpiresAt: DateTime.parse(j['rotationExpiresAt'] as String),
  offlineToken: j['offlineToken'] as String,
  offlineTokenValidUntil: DateTime.parse(
    j['offlineTokenValidUntil'] as String,
  ),
  fallbackCode: j['fallbackCode'] as String,
);

OrderBagSnapshot _bagSnapshotFromJson(Map<String, dynamic> j) =>
    OrderBagSnapshot(
      bagId: j['bagId'] as String,
      title: j['title'] as String,
      dietaryEnvelope: DietaryEnvelope.fromWire(
        j['dietaryEnvelope'] as String,
      ),
      imageUrl: j['imageUrl'] as String? ?? '',
    );

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
      : _pickupTokenFromJson(
          (row['pickup_token'] as Map).cast<String, dynamic>(),
        ),
  createdAt: DateTime.parse(row['created_at'] as String),
  collectedAt: row['collected_at'] == null
      ? null
      : DateTime.parse(row['collected_at'] as String),
  cancelledAt: row['cancelled_at'] == null
      ? null
      : DateTime.parse(row['cancelled_at'] as String),
  cancellationReason: row['cancellation_reason'] as String?,
);

/// Reads/updates the same shared `orders`/`payments`/`bags` rows
/// `CheckoutRepositorySupabase` writes.
///
/// **No dependency on `catalog`**, matching the interface's own doc note —
/// every read here works off the immutable snapshot already embedded in
/// the order row, never a live bag/shop lookup.
///
/// **No Realtime subscription lives here** — the interface has no
/// stream-shaped method for one (today's "live status" is the existing
/// screens' own polling `Timer`, e.g. `pickup_screen.dart`). Every method
/// below reads Supabase fresh on each call, so that existing poll loop
/// automatically becomes "live" the moment it's pointed at this
/// repository — a shop confirming pickup shows up on the next poll tick
/// without this repository needing to grow new surface area.
///
/// `getRefund`/`uploadAttachment`/`reportIssue` are honestly minimal:
/// there's no `refunds`-pipeline, Storage bucket, or `issues` table wired
/// in this pass (fake payment has no real gateway to refund from, and
/// issue reporting is out of this pass's "shop/customer realtime order
/// lifecycle" scope) — each returns a locally synthesized, unpersisted
/// result rather than pretending to hit a backend that isn't there.
final class OrdersRepositorySupabase implements OrdersRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<Order>> getOrders({
    required OrderListSegment segment,
    required String customerId,
  }) async {
    final rows = await _client
        .from('orders')
        .select()
        .eq('customer_id', customerId)
        .order('created_at', ascending: false);
    final orderIds = (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['id'] as String)
        .toList();
    final paymentRows = orderIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
                  .from('payments')
                  .select()
                  .inFilter('order_id', orderIds)
              as List)
              .cast<Map<String, dynamic>>();
    final paymentsByOrderId = {
      for (final p in paymentRows) p['order_id'] as String: p,
    };

    final orders = rows
        .cast<Map<String, dynamic>>()
        .map((r) => _orderFromRows(r, paymentsByOrderId[r['id'] as String]))
        .where(
          (o) => segment == OrderListSegment.active
              ? _activeStatuses.contains(o.status)
              : !_activeStatuses.contains(o.status),
        )
        .toList();
    return orders;
  }

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

  @override
  Future<PickupToken> getPickupToken(String orderId) async {
    final row = await _client
        .from('orders')
        .select('pickup_token')
        .eq('id', orderId)
        .maybeSingle();
    if (row == null || row['pickup_token'] == null) {
      throw const NotFoundException();
    }
    return _pickupTokenFromJson(
      (row['pickup_token'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<CancellationEligibility> getCancellationEligibility(
    String orderId,
  ) async {
    final order = await getOrder(orderId);
    final cutoff = order.pickupWindow.startAt.subtract(
      _cancellationCutoffBeforeWindow,
    );
    final eligible =
        DateTime.now().isBefore(cutoff) &&
        (order.status == OrderStatus.pendingPayment ||
            order.status == OrderStatus.confirmed);
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
    final eligibility = await getCancellationEligibility(orderId);
    if (!eligibility.eligible) {
      throw CancellationWindowPassedException(cutoffAt: eligibility.cutoffAt);
    }
    final order = await getOrder(orderId);
    final now = DateTime.now().toUtc();
    final updatedRow = await _client
        .from('orders')
        .update({
          'status': _orderStatusToWire(OrderStatus.cancelledByCustomer),
          'cancelled_at': now.toIso8601String(),
          'cancellation_reason': reason,
          'updated_at': now.toIso8601String(),
        })
        .eq('id', orderId)
        .select()
        .single();

    // Give the reserved stock back — a customer-initiated cancellation
    // frees the bag for someone else, same as the shop app's own
    // cancelOrder/markNoShow actions do on their side.
    final bagRow = await _client
        .from('bags')
        .select('quantity_available, quantity_total, status')
        .eq('id', order.bagSnapshot.bagId)
        .maybeSingle();
    if (bagRow != null) {
      final restored = ((bagRow['quantity_available'] as int) + order.quantity)
          .clamp(0, bagRow['quantity_total'] as int);
      await _client
          .from('bags')
          .update({
            'quantity_available': restored,
            'status': bagRow['status'] == 'sold_out' ? 'live' : bagRow['status'],
            'updated_at': now.toIso8601String(),
          })
          .eq('id', order.bagSnapshot.bagId);
    }

    final paymentRow = await _client
        .from('payments')
        .select()
        .eq('order_id', orderId)
        .maybeSingle();
    return _orderFromRows(updatedRow, paymentRow);
  }

  @override
  Future<RefundDetail> getRefund(String orderId) async {
    final order = await getOrder(orderId);
    final isCancelled =
        order.status == OrderStatus.cancelledByCustomer ||
        order.status == OrderStatus.cancelledByMerchant;
    if (!isCancelled) throw const NotFoundException();
    // No real refund pipeline exists behind the fake gateway — a cancelled
    // order's money was never actually moved, so this reports the honest
    // equivalent: instantly and fully resolved.
    final when = order.cancelledAt ?? order.createdAt;
    return RefundDetail(
      amount: order.breakdown.total,
      status: RefundStatus.refunded,
      steps: [
        RefundStep(label: RefundStepLabel.started, completedAt: when),
        RefundStep(label: RefundStepLabel.sentToBank, completedAt: when),
        RefundStep(label: RefundStepLabel.credited, completedAt: when),
      ],
      method: order.payment.method,
      maskedDestination: order.payment.maskedIdentifier ?? '0000',
      reason: order.cancellationReason ?? 'Order cancelled',
      bankReferenceNumber: 'FAKE-${_randomCode(8)}',
    );
  }

  @override
  Future<String> uploadAttachment(
    Uint8List bytes, {
    required String filename,
  }) async =>
      // No Storage bucket wired this pass — returns an opaque local id so
      // the issue-report flow doesn't crash; nothing is actually uploaded.
      'attachment_${_randomCode(12)}';

  @override
  Future<IssueReport> reportIssue({
    required String orderId,
    required IssueType type,
    required String description,
    List<String> attachmentIds = const [],
  }) async =>
      // No `issues` table exists yet — this acknowledges the report
      // locally (a real reference number, so the UI's copy stays honest)
      // without persisting it anywhere a shop or support queue could see.
      IssueReport(
        id: 'issue_${_randomCode(10)}',
        referenceNumber: 'ISS-${_randomCode(6)}',
        type: type,
        submittedAt: DateTime.now(),
        slaHours: type.isFoodSafety ? 4 : 48,
      );
}

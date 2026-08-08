import 'package:surplus_marketplace/core/domain/pickup_token.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/domain/price_breakdown.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order_snapshots.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/order_status.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment.dart';

/// Phase 2 §2.1. **User-facing "Reservation" == this aggregate** (§2.7.3) —
/// the brief's reservation language is UX vocabulary; there is no separate
/// `Reservation` type, to avoid two sources of truth for one fact.
final class Order {
  const Order({
    required this.id,
    required this.orderCode,
    required this.customerId,
    required this.holdId,
    required this.merchantSnapshot,
    required this.bagSnapshot,
    required this.quantity,
    required this.breakdown,
    required this.pickupWindow,
    required this.status,
    required this.payment,
    required this.createdAt,
    this.pickupToken,
    this.collectedAt,
    this.cancelledAt,
    this.cancellationReason,
  });

  final String id;

  /// Human-readable, e.g. `SV-7K2M` — the identifier a customer reads
  /// aloud or recognises in a receipt, distinct from [id].
  final String orderCode;
  final String customerId;

  /// The hold this order was created from. **Still meaningful after
  /// creation** — the hold isn't deleted, only frozen (A2) — so
  /// §5c.7's retry path can check whether it's still alive before
  /// deciding between "Retry" and "Hold it again".
  final String holdId;

  /// Immutable copy as at purchase — see [OrderMerchantSnapshot]'s class
  /// doc for why this is never a live reference.
  final OrderMerchantSnapshot merchantSnapshot;
  final OrderBagSnapshot bagSnapshot;
  final int quantity;

  /// Immutable copy as at purchase — a repriced listing must never change
  /// what a past order shows it charged.
  final PriceBreakdown breakdown;
  final PickupWindow pickupWindow;
  final OrderStatus status;
  final Payment payment;
  final PickupToken? pickupToken;
  final DateTime createdAt;
  final DateTime? collectedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  /// Used by `orders` (§8.12 step 7) to persist a derived or customer-driven
  /// status change — never by `checkout`, which only ever constructs a
  /// fresh [Order] at creation.
  Order copyWith({
    OrderStatus? status,
    Payment? payment,
    PickupToken? pickupToken,
    DateTime? collectedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
  }) => Order(
    id: id,
    orderCode: orderCode,
    customerId: customerId,
    holdId: holdId,
    merchantSnapshot: merchantSnapshot,
    bagSnapshot: bagSnapshot,
    quantity: quantity,
    breakdown: breakdown,
    pickupWindow: pickupWindow,
    status: status ?? this.status,
    payment: payment ?? this.payment,
    pickupToken: pickupToken ?? this.pickupToken,
    createdAt: createdAt,
    collectedAt: collectedAt ?? this.collectedAt,
    cancelledAt: cancelledAt ?? this.cancelledAt,
    cancellationReason: cancellationReason ?? this.cancellationReason,
  );
}

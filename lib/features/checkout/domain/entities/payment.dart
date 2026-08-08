import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_method.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/payment_status.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/refund.dart';

/// Phase 2 §2.1.
///
/// [chargeState] reuses [ChargeState] from `core/error` rather than
/// duplicating it — it's the same amendment-A13 concept whether it arrives
/// attached to a thrown [PaymentFailedException] or, as here, sitting on a
/// resolved payment record.
final class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.method,
    required this.gatewayRef,
    required this.amount,
    required this.status,
    required this.attempts,
    required this.chargeState,
    this.refund,
    this.failureReason,
    this.maskedIdentifier,
  });

  final String id;
  final String orderId;
  final PaymentMethod method;

  /// Opaque gateway reference — never a raw gateway string surfaced to the
  /// user (§C5); shown only in an expandable support-details affordance.
  final String gatewayRef;
  final Money amount;
  final PaymentStatus status;
  final int attempts;
  final ChargeState chargeState;

  /// Non-null once a refund has been initiated against this payment.
  final Refund? refund;

  /// e.g. `"4210"` — the last digits of the UPI ID / card, **never the
  /// full identifier** (§5d.2/§5d.4's "ending 4210"). Null only for a
  /// method with nothing to mask (rare in practice).
  final String? maskedIdentifier;

  /// Stable gateway reason code (`declined`, `insufficient_funds`,
  /// `cancelled`, `timeout`), non-null only when [status] is `failed` —
  /// mapped to authored copy by `ErrorCopyMapper._paymentReason`, never
  /// surfaced raw (§C5).
  final String? failureReason;
}

import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';

/// One step of §5d.4's three-step timeline — *Refund started → Sent to your
/// bank → Credited*.
///
/// [completedAt] null means this step hasn't happened yet. The **first**
/// step with a null [completedAt] is the current one; every later step is
/// upcoming.
final class RefundStep {
  const RefundStep({required this.label, this.completedAt});

  final RefundStepLabel label;
  final DateTime? completedAt;
}

enum RefundStepLabel { started, sentToBank, credited }

/// The full refund picture for one order (§5d.4).
///
/// **`expectedByAt` is required to be stated honestly, never as a bare
/// "processing"** (§5d.4) — null only once the refund has reached a
/// terminal state ([RefundStatus.refunded] or [RefundStatus.failed]).
final class RefundDetail {
  const RefundDetail({
    required this.amount,
    required this.status,
    required this.steps,
    required this.method,
    required this.maskedDestination,
    required this.reason,
    this.expectedByAt,
    this.bankReferenceNumber,
  });

  final Money amount;
  final RefundStatus status;
  final List<RefundStep> steps;

  final PaymentMethod method;

  /// e.g. `"4210"` — the last digits of the UPI ID / card, never the full
  /// identifier (§5d.4 "to your UPI ID ending 4210").
  final String maskedDestination;

  final String reason;
  final DateTime? expectedByAt;

  /// Present once the refund has been sent to the bank — exists to be
  /// quoted to a bank, so it's announced character by character (§5d.4).
  final String? bankReferenceNumber;
}

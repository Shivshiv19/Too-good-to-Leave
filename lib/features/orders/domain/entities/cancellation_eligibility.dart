import 'package:surplus_marketplace/core/domain/money.dart';

/// Amendment A15 — whether cancelling this order right now is free.
///
/// **Server-determined, never client-computed** — §5d.5's own validation
/// rule, the same principle as R1 extended from money to policy outcomes.
enum CancellationRefundOutcome {
  full('full'),
  none('none');

  const CancellationRefundOutcome(this.wireValue);

  final String wireValue;

  static CancellationRefundOutcome fromWire(String? value) =>
      CancellationRefundOutcome.values.firstWhere(
        (s) => s.wireValue == value,
        // Conservative fallback: never imply a refund the server didn't
        // actually promise.
        orElse: () => CancellationRefundOutcome.none,
      );
}

final class CancellationEligibility {
  const CancellationEligibility({
    required this.eligible,
    required this.cutoffAt,
    required this.refundOutcome,
    required this.refundAmount,
  });

  final bool eligible;
  final DateTime cutoffAt;
  final CancellationRefundOutcome refundOutcome;
  final Money refundAmount;
}

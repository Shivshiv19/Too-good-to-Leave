import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/refund_status.dart';

/// Phase 2 §2.1 — hangs off [Payment], not [Order]: money movement is the
/// payment's concern, and one order may have multiple payment attempts
/// with independent refund needs (§2.7.4).
final class Refund {
  const Refund({
    required this.id,
    required this.amount,
    required this.reason,
    required this.status,
    required this.initiatedAt,
    required this.expectedByAt,
  });

  final String id;
  final Money amount;
  final String reason;
  final RefundStatus status;
  final DateTime initiatedAt;

  /// §5d.4 — a refund step must never be shown without a date; an
  /// open-ended "processing" is what turns a waiting customer into one who
  /// believes they've been robbed.
  final DateTime expectedByAt;
}

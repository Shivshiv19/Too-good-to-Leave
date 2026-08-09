import 'package:too_good_to_leave_shop/core/domain/money.dart';

/// Platform commission — the same **20%** figure from the customer app's
/// own docs (Phase 1 §1.2's "Illustrative unit economics"), explicitly
/// flagged there as "modelled, not measured." Kept as one named constant
/// here rather than scattered literals, for the same reason.
const commissionRate = 0.20;

/// GST on the platform's commission fee — the standard Indian rate for
/// marketplace/platform services. Informational only: it does not change
/// [EarningsBreakdown.net] or any payout amount, since the fee (and the tax
/// on it) is the platform's own revenue, not the shop's — this is purely
/// what a statement itemises for a shop's own bookkeeping.
const gstOnCommissionRate = 0.18;

/// The commission and payout split for a single collected order's price.
final class EarningsBreakdown {
  const EarningsBreakdown({required this.gross});

  final Money gross;

  Money get commission => Money((gross.amountInPaise * commissionRate).round());

  /// GST charged on [commission] — shown for transparency, already folded
  /// into the commission the platform retains rather than billed
  /// separately to the shop.
  Money get gstOnCommission =>
      Money((commission.amountInPaise * gstOnCommissionRate).round());

  Money get net => gross - commission;
}

/// A payout request against the shop's bank account (`ShopProfile
/// .bankDetails`). Standalone: there's no real payment processor here, so
/// "requesting" a payout is a demo action that records the shop's side of
/// the transaction — money doesn't actually move.
final class PayoutRecord {
  const PayoutRecord({
    required this.id,
    required this.requestedAt,
    required this.amount,
    required this.orderIds,
  });

  final String id;
  final DateTime requestedAt;
  final Money amount;

  /// Which collected orders this payout covers — so a later payout never
  /// double-counts an order that was already paid out.
  final List<String> orderIds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'requestedAt': requestedAt.toIso8601String(),
    'amountInPaise': amount.amountInPaise,
    'orderIds': orderIds,
  };

  factory PayoutRecord.fromJson(Map<String, dynamic> json) => PayoutRecord(
    id: json['id'] as String,
    requestedAt: DateTime.parse(json['requestedAt'] as String),
    amount: Money(json['amountInPaise'] as int),
    orderIds: (json['orderIds'] as List).cast<String>(),
  );
}

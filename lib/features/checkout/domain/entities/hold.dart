import 'package:surplus_marketplace/core/domain/price_breakdown.dart';

/// The customer-facing name for `Cart` (Phase 2 §2.1) is "Your reservation"
/// (§C5 copy), and the wire resource is a **hold** (`POST /v1/holds`,
/// Phase 7 §7.5) — this entity follows the API's own noun rather than
/// inventing a third name for the same thing.
///
/// **Modelled as single-bag-type, not §2.1's `lines: List<...>`.** Every
/// screen in §5b.9/§5c.1 reserves a quantity of exactly *one* bag; nothing
/// in the spec browses and adds a second, different bag to an existing
/// hold before paying. A multi-line cart would be modelling a flow this
/// product doesn't have.
final class Hold {
  const Hold({
    required this.id,
    required this.bagId,
    required this.merchantId,
    required this.quantity,
    required this.expiresAt,
    required this.breakdown,
  });

  final String id;
  final String bagId;
  final String merchantId;
  final int quantity;

  /// Server-authoritative — the countdown (§5c.1) renders this, never a
  /// client-computed deadline.
  final DateTime expiresAt;

  /// Server-computed (R1) — never re-derived when [quantity] changes;
  /// A11 requires a fresh `POST /checkout/quote` instead.
  final PriceBreakdown breakdown;

  Hold copyWith({
    int? quantity,
    DateTime? expiresAt,
    PriceBreakdown? breakdown,
  }) => Hold(
    id: id,
    bagId: bagId,
    merchantId: merchantId,
    quantity: quantity ?? this.quantity,
    expiresAt: expiresAt ?? this.expiresAt,
    breakdown: breakdown ?? this.breakdown,
  );
}

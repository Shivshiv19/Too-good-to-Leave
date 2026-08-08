import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/tax_line.dart';

/// The authoritative price for a hold/order (Phase 2 §2.1, Phase 7 §7.5).
///
/// **Server-computed, client-rendered — this is Rule R1 given a shape.**
/// Every field here is what the server returned; nothing is derived from
/// the others on the client (not even `total`, which could trivially be
/// summed). A client that re-derives any of these has already broken R1,
/// because the point of the rule is that only the server's arithmetic is
/// ever displayed, not that the arithmetic happens to be simple enough to
/// trust locally.
final class PriceBreakdown {
  const PriceBreakdown({
    required this.bagSubtotal,
    required this.platformFee,
    required this.taxes,
    required this.total,
    this.discount,
  });

  final Money bagSubtotal;
  final Money platformFee;
  final List<TaxLine> taxes;

  /// Null when nothing was discounted beyond the bag's own listed price.
  final Money? discount;
  final Money total;

  @override
  bool operator ==(Object other) =>
      other is PriceBreakdown &&
      other.bagSubtotal == bagSubtotal &&
      other.platformFee == platformFee &&
      _taxesEqual(other.taxes) &&
      other.discount == discount &&
      other.total == total;

  bool _taxesEqual(List<TaxLine> other) {
    if (other.length != taxes.length) return false;
    for (var i = 0; i < taxes.length; i++) {
      if (other[i] != taxes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    bagSubtotal,
    platformFee,
    Object.hashAll(taxes),
    discount,
    total,
  );
}

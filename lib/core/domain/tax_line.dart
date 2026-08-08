import 'package:surplus_marketplace/core/domain/money.dart';

/// One line of a [PriceBreakdown] (Phase 2 §2.1).
///
/// `label` is a **server-supplied string**, not a client-side enum or
/// lookup — so a tax-treatment change (the GST §9(5) question, Phase 1
/// §3.3) never needs an app release.
final class TaxLine {
  const TaxLine({required this.label, required this.amount});

  final String label;
  final Money amount;

  @override
  bool operator ==(Object other) =>
      other is TaxLine && other.label == label && other.amount == amount;

  @override
  int get hashCode => Object.hash(label, amount);
}

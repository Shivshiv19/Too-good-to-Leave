import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/merchant_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/scarcity.dart';

/// The list/map/search card shape (Phase 7 §7.4's `GET /v1/bags` response
/// item) — a deliberately separate entity from [SurpriseBag], not a
/// "detail entity with some fields omitted".
///
/// A8 is the reason for the split: this shape can carry only a [Scarcity]
/// enum, never `quantityAvailable`, so a cached card is structurally
/// incapable of asserting an exact count and being wrong. Reusing the detail
/// entity here (with an optional/nullable count) would leave that guarantee
/// resting on every call site remembering not to read the field — a weaker
/// guarantee than not having the field at all.
final class BagSummary {
  const BagSummary({
    required this.id,
    required this.merchant,
    required this.title,
    required this.dietaryEnvelope,
    required this.price,
    required this.statedRetailValue,
    required this.discountPercent,
    required this.pickupWindow,
    required this.distanceMetres,
    required this.scarcity,
    required this.imageUrl,
    required this.geo,
  });

  final String id;
  final MerchantSummary merchant;
  final String title;
  final DietaryEnvelope dietaryEnvelope;
  final Money price;
  final Money statedRetailValue;
  final int discountPercent;
  final PickupWindow pickupWindow;
  final int distanceMetres;
  final Scarcity scarcity;
  final String imageUrl;

  /// The merchant's coordinate — §5b.2's map view needs a pin position.
  /// Never a finer precision than the merchant's own storefront (A8's
  /// "never expose more than the list-card shape earns" reasoning extends
  /// to position, not just count).
  final LatLng geo;
}

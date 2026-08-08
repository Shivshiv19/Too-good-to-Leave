import 'package:too_good_to_leave_shop/core/domain/dietary_envelope.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';

/// Whether a listing is visible to customers.
enum BagStatus {
  /// Being edited, not yet visible.
  draft,

  /// Visible and reservable.
  live,

  /// Visible but temporarily not reservable (e.g. sold out for today).
  paused,
}

/// A surprise bag as the shop sees and edits it.
///
/// Deliberately a different shape from the customer-facing `BagSummary`/
/// `SurpriseBag` (the read-only, fixed-content types the customer app
/// consumes) — this is the *editable* source a shop owner fills in, before
/// it becomes something a customer sees.
final class ShopBag {
  ShopBag({
    required this.id,
    required this.title,
    required this.description,
    required this.envelope,
    required this.price,
    required this.quantityAvailable,
    required this.pickupWindow,
    this.status = BagStatus.draft,
  });

  final String id;
  final String title;
  final String description;
  final DietaryEnvelope envelope;
  final Money price;
  final int quantityAvailable;
  final PickupWindow pickupWindow;
  final BagStatus status;

  ShopBag copyWith({
    String? title,
    String? description,
    DietaryEnvelope? envelope,
    Money? price,
    int? quantityAvailable,
    PickupWindow? pickupWindow,
    BagStatus? status,
  }) => ShopBag(
    id: id,
    title: title ?? this.title,
    description: description ?? this.description,
    envelope: envelope ?? this.envelope,
    price: price ?? this.price,
    quantityAvailable: quantityAvailable ?? this.quantityAvailable,
    pickupWindow: pickupWindow ?? this.pickupWindow,
    status: status ?? this.status,
  );
}

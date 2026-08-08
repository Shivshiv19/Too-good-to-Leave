import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_status.dart';

/// A listing a customer can buy (Phase 2 §2.1).
///
/// **Sealed with a single variant on purpose.** Nothing in the domain, UI,
/// or data layer may pattern-match on "the only kind of offer" — all
/// consumption goes through an exhaustive `switch`, so adding a second
/// variant (e.g. `ExactItem`) later becomes a compile-error-guided change
/// across the codebase rather than a grep-and-hope audit.
///
/// Hand-written, not `freezed`, despite being a sealed type: [SurpriseBag]'s
/// invariants (I1–I4) are enforced in the constructor via `assert`, the same
/// shape as `PickupWindow`'s I4 — `freezed`'s generated constructor has no
/// hook for that.
sealed class Offer {
  const Offer();
}

/// The bag detail shape (Phase 7 §7.4's `GET /v1/bags/{bagId}`, `no-store`).
///
/// Carries the two fields only a fresh, uncached fetch may supply:
/// [quantityAvailable] (exact, A8) and [remainingAllowanceForCustomer] (A9).
final class SurpriseBag extends Offer {
  SurpriseBag({
    required this.id,
    required this.merchantId,
    required this.title,
    required this.description,
    required this.dietaryEnvelope,
    required this.categoryHint,
    required this.price,
    required this.statedRetailValue,
    required this.discountPercent,
    required this.quantityTotal,
    required this.quantityAvailable,
    required this.pickupWindow,
    required this.safeUntil,
    required this.imageUrl,
    required this.pickupInstructions,
    required this.status,
    required this.remainingAllowanceForCustomer,
    this.allergenNotes,
  }) : assert(
         pickupWindow.isWithinSafetyDeadline(safeUntil),
         'I1 violated: pickupWindow must end at or before safeUntil — food '
         'may not be sold for collection after its FSSAI safe-consumption '
         'deadline.',
       ),
       assert(
         price.amountInPaise < statedRetailValue.amountInPaise,
         'I2 violated: price must be less than statedRetailValue — the '
         'discount claim must be true.',
       ),
       assert(
         quantityAvailable >= 0 && quantityAvailable <= quantityTotal,
         'I3 violated: 0 <= quantityAvailable <= quantityTotal.',
       );

  final String id;
  final String merchantId;
  final String title;
  final String description;
  final DietaryEnvelope dietaryEnvelope;

  /// e.g. "A selection of today's unsold breads, pastries and cookies." —
  /// what to expect, since contents are otherwise undisclosed (§5b.9).
  final String categoryHint;
  final Money price;
  final Money statedRetailValue;

  /// Server-supplied, per R1 — never computed client-side for display.
  /// `Money.discountPercentAgainst` exists to *verify* this value in tests
  /// and fixtures, not to derive it here.
  final int discountPercent;
  final int quantityTotal;

  /// Exact — this shape only ever comes from a fresh, uncached fetch (A8).
  final int quantityAvailable;
  final PickupWindow pickupWindow;

  /// FSSAI safe-consumption deadline — see I1.
  final DateTime safeUntil;
  final String imageUrl;
  final String? allergenNotes;
  final String pickupInstructions;
  final BagStatus status;

  /// A9 — the true per-customer cap on this listing, so the quantity
  /// stepper renders reality rather than guessing `min(quantityAvailable,
  /// 2)` and risking a stale client-side constant.
  final int remainingAllowanceForCustomer;
}

import 'package:surplus_marketplace/core/domain/address.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';

/// An immutable copy of a merchant as at purchase (Phase 2 §2.1's
/// "snapshot principle").
///
/// **Deliberately a distinct type from `catalog`'s `Merchant`**, not a
/// reused reference — if a merchant later renames or moves, a six-month-old
/// order must still render exactly what was bought. Referencing a live
/// entity from an order is "both a correctness and a legal defect" (§2.1);
/// giving the snapshot its own type makes reaching for a live reference by
/// accident a compile error rather than a code-review catch.
final class OrderMerchantSnapshot {
  const OrderMerchantSnapshot({
    required this.id,
    required this.legalName,
    required this.displayName,
    required this.address,
    required this.phone,
    required this.fssaiLicenceNumber,
    required this.fssaiLicenceExpiry,
    required this.grievanceContact,
  });

  final String id;
  final String legalName;
  final String displayName;
  final Address address;
  final String phone;

  /// §5d.2's legal disclosure block — Consumer Protection (E-commerce)
  /// Rules 2020. Captured at purchase time, same snapshot reasoning as
  /// every other field here.
  final String fssaiLicenceNumber;
  final DateTime fssaiLicenceExpiry;
  final String grievanceContact;
}

/// An immutable copy of a bag as at purchase — see [OrderMerchantSnapshot].
final class OrderBagSnapshot {
  const OrderBagSnapshot({
    required this.bagId,
    required this.title,
    required this.dietaryEnvelope,
    required this.imageUrl,
  });

  final String bagId;
  final String title;
  final DietaryEnvelope dietaryEnvelope;
  final String imageUrl;
}

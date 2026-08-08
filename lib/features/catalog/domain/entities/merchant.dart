import 'package:surplus_marketplace/core/domain/address.dart';
import 'package:surplus_marketplace/core/domain/rating_aggregate.dart';

/// Phase 2 §2.1 aggregate.
///
/// **`legalName` and `grievanceContact` are compliance-load-bearing, not
/// metadata** — they satisfy the Consumer Protection (E-commerce) Rules 2020
/// disclosure duty. `fssaiLicenceNumber`/`fssaiLicenceExpiry` satisfy FSSAI
/// display requirements (§5b.8's trust block).
///
/// **`category`/`foodTypeTags` are taxonomy-tag IDs (`String`), not a
/// compiled `MerchantCategory` enum** — a deliberate deviation from this
/// phase's own §2.1 enum listing, in favour of §2.3's more specific decision
/// that categories are server-driven display metadata with no behavioural
/// meaning (D-1's "client enums exist only for values with behavioural
/// meaning" line). Resolve a label via the already-fetched `Taxonomy`
/// (`config` feature), never hardcode one here.
final class Merchant {
  const Merchant({
    required this.id,
    required this.legalName,
    required this.displayName,
    required this.category,
    required this.foodTypeTags,
    required this.fssaiLicenceNumber,
    required this.fssaiLicenceExpiry,
    required this.certifications,
    required this.logoUrl,
    required this.storefrontPhotos,
    required this.address,
    required this.phone,
    required this.operatingHours,
    required this.description,
    required this.ratingAggregate,
    required this.isVerified,
    required this.grievanceContact,
    this.typicalListingTime,
  });

  final String id;
  final String legalName;
  final String displayName;

  /// Taxonomy-tag ID — see class doc.
  final String category;

  /// Taxonomy-tag IDs — see class doc.
  final List<String> foodTypeTags;

  final String fssaiLicenceNumber;
  final DateTime fssaiLicenceExpiry;

  /// e.g. `halal` — a merchant certification, orthogonal to the veg/non-veg
  /// axis (§2.3 — "Halal is a merchant certification, not a
  /// `DietaryEnvelope` value").
  final List<String> certifications;

  final String logoUrl;
  final List<String> storefrontPhotos;
  final Address address;
  final String phone;
  final String operatingHours;
  final String description;
  final RatingAggregate ratingAggregate;
  final bool isVerified;
  final String grievanceContact;

  /// §5b.8's empty-state education — "Sweet Crumb usually lists around
  /// 8 pm". Null when the server has no estimate yet.
  final String? typicalListingTime;
}

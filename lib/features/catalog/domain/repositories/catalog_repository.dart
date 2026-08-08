import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/coverage_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_page.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_query.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/merchant.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/offer.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/search_results.dart';

/// Server stand-in (Phase 1 locked decision) for the Discovery surface
/// (Phase 5b, Phase 7 §7.4).
abstract interface class CatalogRepository {
  /// `GET /v1/bags` — the list/map card shape (A8: [Scarcity], never an
  /// exact count).
  Future<DiscoverPage> discoverBags(DiscoverQuery query, {String? cursor});

  /// `GET /v1/bags/{bagId}`, `no-store` — exact `quantityAvailable` and
  /// `remainingAllowanceForCustomer` (A8/A9). Never served from the
  /// [discoverBags] cache.
  Future<SurpriseBag> bag(String bagId);

  /// `GET /v1/merchants/{id}`.
  Future<Merchant> merchant(String merchantId);

  /// This merchant's current live bags, in the list-card shape (§5b.8's
  /// "Bags" region) — unlike [discoverBags], never facet-filtered, since a
  /// merchant's own profile shows everything it currently has regardless of
  /// the customer's dietary/category/price narrowing.
  Future<List<BagSummary>> merchantBags(String merchantId, LatLng anchor);

  /// `GET /v1/merchants/{id}/reviews` — cursor-paginated, plus the
  /// histogram aggregate (already on [Merchant.ratingAggregate]).
  Future<ReviewsPage> merchantReviews(String merchantId, {String? cursor});

  /// `GET /v1/coverage` — A10's disambiguating signal.
  Future<CoverageStatus> coverage(LatLng anchor);

  /// `POST /v1/coverage/notify` — accepts anonymous callers (A10).
  Future<void> notifyCoverage({
    required String locality,
    required LatLng anchor,
    String? deviceToken,
  });

  /// `GET /v1/search` — merchants only (D-b4).
  Future<SearchResults> search(String query, LatLng anchor);

  Future<bool> isMerchantSaved(String merchantId);

  /// **Amendment A17** — unsaving clears the watch too; a merchant can't be
  /// watched without appearing in Saved.
  Future<void> setMerchantSaved(String merchantId, {required bool saved});

  Future<bool> isMerchantWatched(String merchantId);

  /// **Amendment A17** — "watching implies saving": setting `watched: true`
  /// on an unsaved merchant saves it too, in the same call.
  Future<void> setMerchantWatched(String merchantId, {required bool watched});

  /// `GET /v1/saved` — every merchant this customer has saved (§5e.2). Order
  /// is not sorted here (presentation sorts by live-availability then
  /// distance, per §5e.2).
  Future<List<Merchant>> savedMerchants();
}

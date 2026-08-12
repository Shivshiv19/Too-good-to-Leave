import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surplus_marketplace/core/domain/address.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/domain/rating_aggregate.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/catalog/catalog.dart';

Address _addressFromShopRow(Map<String, dynamic> row) => Address(
  line1: row['address_line1'] as String,
  line2: row['address_line2'] as String?,
  floorOrShopNo: row['floor_or_shop_no'] as String?,
  landmark: row['landmark'] as String,
  locality: row['locality'] as String,
  city: row['city'] as String,
  state: row['state'] as String,
  pincode: row['pincode'] as String,
  geo: _geoFromShopRow(row),
);

LatLng _geoFromShopRow(Map<String, dynamic> row) => LatLng(
  latitude: (row['lat'] as num).toDouble(),
  longitude: (row['lng'] as num).toDouble(),
);

RatingAggregate _ratingFromShopRow(Map<String, dynamic> row) {
  final histogram = (row['rating_histogram'] as Map?) ?? const {};
  return RatingAggregate(
    average: ((row['rating_average'] as num?) ?? 0).toDouble(),
    count: (row['rating_count'] as int?) ?? 0,
    histogram: {
      for (final entry in histogram.entries)
        int.parse(entry.key as String): entry.value as int,
    },
  );
}

Merchant _merchantFromRow(Map<String, dynamic> row) => Merchant(
  id: row['id'] as String,
  legalName: row['legal_name'] as String,
  displayName: row['display_name'] as String,
  category: row['category'] as String,
  foodTypeTags: ((row['food_type_tags'] as List?) ?? const []).cast<String>(),
  fssaiLicenceNumber: row['fssai_license_number'] as String,
  fssaiLicenceExpiry: DateTime.parse(row['fssai_license_expiry'] as String),
  certifications: ((row['certifications'] as List?) ?? const []).cast<String>(),
  logoUrl: row['logo_url'] as String? ?? '',
  storefrontPhotos: ((row['storefront_photos'] as List?) ?? const [])
      .cast<String>(),
  address: _addressFromShopRow(row),
  phone: row['phone'] as String,
  operatingHours: row['operating_hours_text'] as String? ?? '',
  description: row['description'] as String? ?? '',
  ratingAggregate: _ratingFromShopRow(row),
  isVerified: row['approval_status'] == 'verified',
  grievanceContact: row['grievance_contact'] as String? ?? '',
  typicalListingTime: row['typical_listing_time'] as String?,
);

MerchantSummary _merchantSummaryFromRow(Map<String, dynamic> row) =>
    MerchantSummary(
      id: row['id'] as String,
      displayName: row['display_name'] as String,
      category: row['category'] as String,
      ratingAggregate: _ratingFromShopRow(row),
    );

BagStatus _bagStatusFromPostgresWire(String value) => switch (value) {
  'draft' => BagStatus.draft,
  'live' => BagStatus.live,
  // The shop app's own 3-value status (draft/live/paused, see
  // shop/lib/core/domain/dietary_envelope.dart's sibling shop_bag.dart) —
  // "paused" (shop temporarily out of stock) reads closest to "sold out"
  // from a customer's perspective.
  'paused' || 'sold_out' => BagStatus.soldOut,
  'withdrawn_by_merchant' => BagStatus.withdrawnByMerchant,
  _ => BagStatus.windowClosed,
};

BagSummary _bagSummaryFromRow(Map<String, dynamic> row, LatLng anchor) {
  final shop = (row['shops'] as Map).cast<String, dynamic>();
  final geo = _geoFromShopRow(shop);
  final available = row['quantity_available'] as int;
  return BagSummary(
    id: row['id'] as String,
    merchant: _merchantSummaryFromRow(shop),
    title: row['title'] as String,
    dietaryEnvelope: DietaryEnvelope.fromWire(
      row['dietary_envelope'] as String,
    ),
    price: Money(row['price_paise'] as int),
    statedRetailValue: Money(row['stated_retail_value_paise'] as int),
    discountPercent: row['discount_percent'] as int,
    pickupWindow: PickupWindow(
      startAt: DateTime.parse(row['pickup_start_at'] as String),
      endAt: DateTime.parse(row['pickup_end_at'] as String),
    ),
    distanceMetres: anchor.distanceInMetersTo(geo).round(),
    scarcity: available > 0 && available <= 2 ? Scarcity.few : Scarcity.none,
    imageUrl: row['image_url'] as String? ?? '',
    geo: geo,
  );
}

int Function(BagSummary, BagSummary) _comparatorFor(DiscoverSort sort) =>
    switch (sort) {
      DiscoverSort.distance => (a, b) =>
          a.distanceMetres.compareTo(b.distanceMetres),
      DiscoverSort.pickupTime => (a, b) =>
          a.pickupWindow.endAt.compareTo(b.pickupWindow.endAt),
      DiscoverSort.priceAsc => (a, b) =>
          a.price.amountInPaise.compareTo(b.price.amountInPaise),
      DiscoverSort.discountDesc => (a, b) =>
          b.discountPercent.compareTo(a.discountPercent),
      DiscoverSort.rating => (a, b) => b.merchant.ratingAggregate.average
          .compareTo(a.merchant.ratingAggregate.average),
      DiscoverSort.urgencyThenDistance => (a, b) {
        final byPickup = a.pickupWindow.endAt.compareTo(b.pickupWindow.endAt);
        return byPickup != 0
            ? byPickup
            : a.distanceMetres.compareTo(b.distanceMetres);
      },
    };

/// Reads the shared Supabase `bags`/`shops` tables (`supabase/schema.sql`) —
/// the same rows the shop app's bag editor writes, so a bag published there
/// appears here live (Realtime keeps any open discover list in sync via the
/// presentation layer's own subscription, not this repository, matching
/// `OrdersRepository`'s "no dependency on catalog" boundary in reverse).
///
/// Facet filtering/sorting/pagination happen client-side over a single
/// fetch of all live bags — there's no PostGIS/full-text search behind this
/// schema yet, so this is a deliberate Phase-1 simplification rather than a
/// server-side query. `merchantReviews`/`coverage`/`notifyCoverage` have no
/// backing tables at all (reviews and geofencing are out of this pass's
/// scope) and return the honest "nothing here yet" shape rather than fake
/// data. Saved/watched merchants are session-local (no table for them
/// either) — they reset on app restart until a real `saved_merchants` table
/// exists.
final class CatalogRepositorySupabase implements CatalogRepository {
  /// [_prefs] persists saved/watched merchant ids to this device's local
  /// storage — there's no `saved_merchants` table in the shared schema, but
  /// a customer expecting "Saved" to survive a page reload is a much lower
  /// bar than syncing across devices, and shared_preferences already
  /// covers it without new backend surface.
  CatalogRepositorySupabase(this._prefs) {
    _savedMerchantIds.addAll(_prefs.getStringList(_savedKey) ?? const []);
    _watchedMerchantIds.addAll(_prefs.getStringList(_watchedKey) ?? const []);
  }

  static const _savedKey = 'catalog.savedMerchantIds';
  static const _watchedKey = 'catalog.watchedMerchantIds';

  SupabaseClient get _client => Supabase.instance.client;

  final Prefs _prefs;
  final Set<String> _savedMerchantIds = {};
  final Set<String> _watchedMerchantIds = {};

  Future<void> _persist() async {
    await _prefs.setStringList(_savedKey, _savedMerchantIds.toList());
    await _prefs.setStringList(_watchedKey, _watchedMerchantIds.toList());
  }

  Future<List<Map<String, dynamic>>> _fetchLiveBagsWithShops() async {
    // `status='live'` alone isn't "actually purchasable" — the shop editor's
    // Quantity field and its Draft/Live/Paused toggle are independent
    // controls, so a shop can leave a bag "Live" with 0 units left (e.g.
    // after manually editing it down, outside the checkout RPC's own
    // atomic sold-out flip). Filtering stock here keeps a phantom listing
    // out of Discover rather than showing it with no scarcity warning.
    final rows = await _client
        .from('bags')
        .select('*, shops(*)')
        .eq('status', 'live')
        .gt('quantity_available', 0);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .where((r) => (r['shops'] as Map)['approval_status'] == 'verified')
        .toList();
  }

  @override
  Future<DiscoverPage> discoverBags(
    DiscoverQuery query, {
    String? cursor,
  }) async {
    final rows = await _fetchLiveBagsWithShops();
    var items = rows
        .map((r) => _bagSummaryFromRow(r, query.anchor))
        .toList();

    items = items
        .where((b) => b.distanceMetres <= query.radiusKm * 1000)
        .toList();
    if (query.acceptedEnvelopes.isNotEmpty) {
      items = items
          .where((b) => query.acceptedEnvelopes.contains(b.dietaryEnvelope))
          .toList();
    }
    if (query.categories.isNotEmpty) {
      items = items
          .where((b) => query.categories.contains(b.merchant.category))
          .toList();
    }
    if (query.priceMinPaise != null) {
      items = items
          .where((b) => b.price.amountInPaise >= query.priceMinPaise!)
          .toList();
    }
    if (query.priceMaxPaise != null) {
      items = items
          .where((b) => b.price.amountInPaise <= query.priceMaxPaise!)
          .toList();
    }
    if (query.minRating != null) {
      items = items
          .where(
            (b) => b.merchant.ratingAggregate.average >= query.minRating!,
          )
          .toList();
    }
    // `foodTypes`/`pickupTimeFacet`: bags don't carry a taxonomy-tag food
    // type distinct from the shop's own, and "later today"/"tomorrow"
    // windowing isn't modelled yet — out of scope for this pass.

    items.sort(_comparatorFor(query.sort));

    const pageSize = 20;
    final start = int.tryParse(cursor ?? '0') ?? 0;
    final page = items.skip(start).take(pageSize).toList();
    final nextCursor = start + pageSize < items.length
        ? '${start + pageSize}'
        : null;
    return DiscoverPage(items: page, nextCursor: nextCursor);
  }

  @override
  Future<SurpriseBag> bag(String bagId) async {
    final row = await _client
        .from('bags')
        .select()
        .eq('id', bagId)
        .maybeSingle();
    if (row == null) throw const NotFoundException();

    final cap = (row['purchase_cap_per_customer'] as int?) ?? 2;
    var remaining = cap;
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      final orderedRows = await _client
          .from('orders')
          .select('quantity')
          .eq('bag_id', bagId)
          .eq('customer_id', userId)
          .not(
            'status',
            'in',
            '(cancelled_by_customer,cancelled_by_merchant,payment_failed)',
          );
      final alreadyOrdered = (orderedRows as List)
          .cast<Map<String, dynamic>>()
          .fold<int>(0, (sum, o) => sum + (o['quantity'] as int));
      remaining = (cap - alreadyOrdered).clamp(0, cap);
    }

    return SurpriseBag(
      id: row['id'] as String,
      merchantId: row['shop_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      dietaryEnvelope: DietaryEnvelope.fromWire(
        row['dietary_envelope'] as String,
      ),
      categoryHint: row['category_hint'] as String? ?? '',
      price: Money(row['price_paise'] as int),
      statedRetailValue: Money(row['stated_retail_value_paise'] as int),
      discountPercent: row['discount_percent'] as int,
      quantityTotal: row['quantity_total'] as int,
      quantityAvailable: row['quantity_available'] as int,
      pickupWindow: PickupWindow(
        startAt: DateTime.parse(row['pickup_start_at'] as String),
        endAt: DateTime.parse(row['pickup_end_at'] as String),
      ),
      safeUntil: DateTime.parse(row['safe_until'] as String),
      imageUrl: row['image_url'] as String? ?? '',
      pickupInstructions: row['pickup_instructions'] as String? ?? '',
      status: _bagStatusFromPostgresWire(row['status'] as String),
      remainingAllowanceForCustomer: remaining,
      allergenNotes: row['allergen_notes'] as String?,
    );
  }

  @override
  Future<Merchant> merchant(String merchantId) async {
    final row = await _client
        .from('shops')
        .select()
        .eq('id', merchantId)
        .maybeSingle();
    if (row == null) throw const NotFoundException();
    return _merchantFromRow(row);
  }

  @override
  Future<List<BagSummary>> merchantBags(
    String merchantId,
    LatLng anchor,
  ) async {
    final shopRow = await _client
        .from('shops')
        .select()
        .eq('id', merchantId)
        .maybeSingle();
    if (shopRow == null) throw const NotFoundException();
    final rows = await _client
        .from('bags')
        .select()
        .eq('shop_id', merchantId)
        .eq('status', 'live')
        .gt('quantity_available', 0);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => _bagSummaryFromRow({...r, 'shops': shopRow}, anchor))
        .toList();
  }

  @override
  Future<ReviewsPage> merchantReviews(
    String merchantId, {
    String? cursor,
  }) async => const ReviewsPage(items: [], nextCursor: null);

  @override
  Future<CoverageStatus> coverage(LatLng anchor) async =>
      const CoverageStatus.live();

  @override
  Future<void> notifyCoverage({
    required String locality,
    required LatLng anchor,
    String? deviceToken,
  }) async {}

  @override
  Future<SearchResults> search(String query, LatLng anchor) async {
    if (query.trim().isEmpty) return const SearchResults(merchants: []);
    final rows = await _client
        .from('shops')
        .select()
        .eq('approval_status', 'verified')
        .ilike('display_name', '%${query.trim()}%');
    final results = <MerchantResult>[];
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final liveBags = await _client
          .from('bags')
          .select('id')
          .eq('shop_id', row['id'] as String)
          .eq('status', 'live');
      results.add(
        MerchantResult(
          merchant: _merchantSummaryFromRow(row),
          liveBagCount: (liveBags as List).length,
          distanceMetres: anchor
              .distanceInMetersTo(_geoFromShopRow(row))
              .round(),
        ),
      );
    }
    return SearchResults(merchants: results);
  }

  @override
  Future<bool> isMerchantSaved(String merchantId) async =>
      _savedMerchantIds.contains(merchantId);

  @override
  Future<void> setMerchantSaved(
    String merchantId, {
    required bool saved,
  }) async {
    if (saved) {
      _savedMerchantIds.add(merchantId);
    } else {
      _savedMerchantIds.remove(merchantId);
      _watchedMerchantIds.remove(merchantId); // A17
    }
    await _persist();
  }

  @override
  Future<bool> isMerchantWatched(String merchantId) async =>
      _watchedMerchantIds.contains(merchantId);

  @override
  Future<void> setMerchantWatched(
    String merchantId, {
    required bool watched,
  }) async {
    if (watched) {
      _watchedMerchantIds.add(merchantId);
      _savedMerchantIds.add(merchantId); // A17
    } else {
      _watchedMerchantIds.remove(merchantId);
    }
    await _persist();
  }

  @override
  Future<List<Merchant>> savedMerchants() async {
    final merchants = <Merchant>[];
    for (final id in _savedMerchantIds) {
      final row = await _client
          .from('shops')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row != null) merchants.add(_merchantFromRow(row));
    }
    return merchants;
  }
}

import 'package:surplus_marketplace/core/domain/address.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/domain/money.dart';
import 'package:surplus_marketplace/core/domain/pickup_window.dart';
import 'package:surplus_marketplace/core/domain/rating_aggregate.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/bag_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/coverage_status.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_page.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_query.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/discover_sort.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/merchant.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/merchant_summary.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/offer.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/review.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/scarcity.dart';
import 'package:surplus_marketplace/features/catalog/domain/entities/search_results.dart';
import 'package:surplus_marketplace/features/catalog/domain/repositories/catalog_repository.dart';

class _MerchantFixture {
  const _MerchantFixture(this.merchant, this.bags, this.reviews);

  final Merchant merchant;
  final List<SurpriseBag> bags;
  final List<Review> reviews;
}

/// Stands in for the server (Phase 1 locked decision).
///
/// **Fixtures are constructed as domain objects directly**, not run through a
/// JSON DTO pipeline the way `ConfigRepositoryFake` is (D-15). Catalog's own
/// domain entities are hand-written with constructor-enforced invariants
/// (`SurpriseBag`'s I1–I4), not `freezed` wire mirrors, so there is no DTO
/// layer here yet to exercise — one is added alongside the HTTP binding,
/// same as auth's and onboarding's fakes.
final class CatalogRepositoryFake implements CatalogRepository {
  CatalogRepositoryFake({required Prefs prefs, required Clock clock})
    : _prefs = prefs,
      _clock = clock,
      _fixtures = _buildFixtures(clock);

  final Prefs _prefs;
  final Clock _clock;
  final List<_MerchantFixture> _fixtures;

  static const _savedMerchantsKey = 'catalog.savedMerchantIds';
  static const _watchedMerchantsKey = 'catalog.watchedMerchantIds';

  @override
  Future<DiscoverPage> discoverBags(
    DiscoverQuery query, {
    String? cursor,
  }) async {
    final allBags = _fixtures
        .expand((f) => f.bags)
        .where(
          (b) => b.status == BagStatus.live,
        );

    var summaries = allBags
        .map((bag) => _toSummary(bag, query.anchor))
        .toList();

    summaries = summaries.where((s) {
      if (s.distanceMetres > query.radiusKm * 1000) return false;
      if (query.acceptedEnvelopes.isNotEmpty &&
          !query.acceptedEnvelopes.contains(s.dietaryEnvelope)) {
        return false;
      }
      if (query.categories.isNotEmpty &&
          !query.categories.contains(s.merchant.category)) {
        return false;
      }
      if (query.priceMinPaise != null &&
          s.price.amountInPaise < query.priceMinPaise!) {
        return false;
      }
      if (query.priceMaxPaise != null &&
          s.price.amountInPaise > query.priceMaxPaise!) {
        return false;
      }
      if (query.minRating != null &&
          s.merchant.ratingAggregate.average < query.minRating!) {
        return false;
      }
      if (query.pickupTimeFacet != null &&
          !_matchesPickupTimeFacet(s, query.pickupTimeFacet!)) {
        return false;
      }
      return true;
    }).toList();

    summaries.sort((a, b) => _compareForSort(a, b, query.sort));

    // A single unpaginated fixture page — pagination has nothing genuine to
    // demonstrate against ~15 fixture bags. `nextCursor` stays null.
    return DiscoverPage(items: summaries, nextCursor: null);
  }

  @override
  Future<SurpriseBag> bag(String bagId) async {
    for (final fixture in _fixtures) {
      for (final bag in fixture.bags) {
        if (bag.id == bagId) return bag;
      }
    }
    throw const NotFoundException();
  }

  @override
  Future<Merchant> merchant(String merchantId) async {
    final fixture = _fixtureFor(merchantId);
    return fixture.merchant;
  }

  @override
  Future<List<BagSummary>> merchantBags(
    String merchantId,
    LatLng anchor,
  ) async {
    final fixture = _fixtureFor(merchantId);
    return fixture.bags
        .where((b) => b.status == BagStatus.live)
        .map((b) => _toSummary(b, anchor))
        .toList();
  }

  @override
  Future<ReviewsPage> merchantReviews(
    String merchantId, {
    String? cursor,
  }) async {
    final fixture = _fixtureFor(merchantId);
    return ReviewsPage(items: fixture.reviews, nextCursor: null);
  }

  @override
  Future<CoverageStatus> coverage(LatLng anchor) async {
    final withinLaunchCity =
        anchor.distanceInMetersTo(_bengaluruCentre) <= 40000;
    if (!withinLaunchCity) {
      return CoverageStatus.noCoverage(
        nearestLiveAreaName: 'Indiranagar',
        nearestLiveAreaDistanceMetres: anchor
            .distanceInMetersTo(_bengaluruCentre)
            .round(),
        nearestLiveAreaAnchor: _bengaluruCentre,
      );
    }
    final hasLiveBagsNearby = (await discoverBags(
      DiscoverQuery(anchor: anchor, radiusKm: 10),
    )).items.isNotEmpty;
    if (!hasLiveBagsNearby) {
      return const CoverageStatus.noSupplyNow(
        typicalWindowStart: '19:00',
        merchantCountInArea: 6,
      );
    }
    return const CoverageStatus.live();
  }

  @override
  Future<void> notifyCoverage({
    required String locality,
    required LatLng anchor,
    String? deviceToken,
  }) async {
    // Anonymous-accepting by design (A10) — the fake has nowhere to record
    // this yet since there is no merchant-supply backend to notify against.
  }

  @override
  Future<SearchResults> search(String query, LatLng anchor) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const SearchResults(merchants: []);
    final results = _fixtures
        .where(
          (f) =>
              f.merchant.displayName.toLowerCase().contains(needle) ||
              f.merchant.category.toLowerCase().contains(needle) ||
              f.merchant.foodTypeTags.any(
                (t) => t.toLowerCase().contains(needle),
              ) ||
              f.merchant.address.locality.toLowerCase().contains(needle),
        )
        .map(
          (f) => MerchantResult(
            merchant: MerchantSummary(
              id: f.merchant.id,
              displayName: f.merchant.displayName,
              category: f.merchant.category,
              ratingAggregate: f.merchant.ratingAggregate,
            ),
            liveBagCount: f.bags
                .where((b) => b.status == BagStatus.live)
                .length,
            distanceMetres: anchor
                .distanceInMetersTo(f.merchant.address.geo)
                .round(),
          ),
        )
        .toList();
    return SearchResults(merchants: results);
  }

  @override
  Future<bool> isMerchantSaved(String merchantId) async =>
      _readIdSet(_savedMerchantsKey).contains(merchantId);

  @override
  Future<void> setMerchantSaved(
    String merchantId, {
    required bool saved,
  }) async {
    final ids = _readIdSet(_savedMerchantsKey);
    saved ? ids.add(merchantId) : ids.remove(merchantId);
    await _writeIdSet(_savedMerchantsKey, ids);
    // A17 — unsaving clears the watch too; a merchant can't be watched
    // without appearing in Saved.
    if (!saved) {
      final watched = _readIdSet(_watchedMerchantsKey)..remove(merchantId);
      await _writeIdSet(_watchedMerchantsKey, watched);
    }
  }

  @override
  Future<bool> isMerchantWatched(String merchantId) async =>
      _readIdSet(_watchedMerchantsKey).contains(merchantId);

  @override
  Future<void> setMerchantWatched(
    String merchantId, {
    required bool watched,
  }) async {
    final ids = _readIdSet(_watchedMerchantsKey);
    watched ? ids.add(merchantId) : ids.remove(merchantId);
    await _writeIdSet(_watchedMerchantsKey, ids);
    // A17 — watching implies saving.
    if (watched) await setMerchantSaved(merchantId, saved: true);
  }

  @override
  Future<List<Merchant>> savedMerchants() async {
    final ids = _readIdSet(_savedMerchantsKey);
    return _fixtures
        .where((f) => ids.contains(f.merchant.id))
        .map((f) => f.merchant)
        .toList();
  }

  Set<String> _readIdSet(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    return raw.split(',').toSet();
  }

  Future<void> _writeIdSet(String key, Set<String> ids) =>
      _prefs.setString(key, ids.join(','));

  _MerchantFixture _fixtureFor(String merchantId) => _fixtures.firstWhere(
    (f) => f.merchant.id == merchantId,
    orElse: () => throw const NotFoundException(),
  );

  BagSummary _toSummary(SurpriseBag bag, LatLng anchor) {
    final fixture = _fixtures.firstWhere(
      (f) => f.merchant.id == bag.merchantId,
    );
    return BagSummary(
      id: bag.id,
      merchant: MerchantSummary(
        id: fixture.merchant.id,
        displayName: fixture.merchant.displayName,
        category: fixture.merchant.category,
        ratingAggregate: fixture.merchant.ratingAggregate,
      ),
      title: bag.title,
      dietaryEnvelope: bag.dietaryEnvelope,
      price: bag.price,
      statedRetailValue: bag.statedRetailValue,
      discountPercent: bag.discountPercent,
      pickupWindow: bag.pickupWindow,
      distanceMetres: anchor
          .distanceInMetersTo(fixture.merchant.address.geo)
          .round(),
      // A8 — collapsed to qualitative here, never the exact count.
      scarcity: bag.quantityAvailable <= 2 ? Scarcity.few : Scarcity.none,
      imageUrl: bag.imageUrl,
      geo: fixture.merchant.address.geo,
    );
  }

  bool _matchesPickupTimeFacet(BagSummary s, PickupTimeFacet facet) {
    final now = _clock.now();
    final startsToday =
        s.pickupWindow.startAt.year == now.year &&
        s.pickupWindow.startAt.month == now.month &&
        s.pickupWindow.startAt.day == now.day;
    return switch (facet) {
      PickupTimeFacet.availableNow => s.pickupWindow.isOpenAt(_clock),
      PickupTimeFacet.laterToday =>
        startsToday && !s.pickupWindow.isOpenAt(_clock),
      PickupTimeFacet.tomorrow => !startsToday,
    };
  }

  int _urgencyRank(BagSummary s) => switch (s.pickupWindow.urgencyAt(_clock)) {
    WindowUrgency.openNow => 0,
    WindowUrgency.closingSoon => 0,
    WindowUrgency.upcoming => 1,
    WindowUrgency.closed => 2,
  };

  int _compareForSort(BagSummary a, BagSummary b, DiscoverSort sort) {
    switch (sort) {
      case DiscoverSort.urgencyThenDistance:
        final byUrgency = _urgencyRank(a).compareTo(_urgencyRank(b));
        return byUrgency != 0
            ? byUrgency
            : a.distanceMetres.compareTo(b.distanceMetres);
      case DiscoverSort.distance:
        return a.distanceMetres.compareTo(b.distanceMetres);
      case DiscoverSort.pickupTime:
        return a.pickupWindow.startAt.compareTo(b.pickupWindow.startAt);
      case DiscoverSort.priceAsc:
        return a.price.compareTo(b.price);
      case DiscoverSort.discountDesc:
        return b.discountPercent.compareTo(a.discountPercent);
      case DiscoverSort.rating:
        return b.merchant.ratingAggregate.average.compareTo(
          a.merchant.ratingAggregate.average,
        );
    }
  }

  static const _bengaluruCentre = LatLng(latitude: 12.9716, longitude: 77.5946);

  static List<_MerchantFixture> _buildFixtures(Clock clock) {
    final now = clock.now();
    DateTime today(int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day, hour, minute);
    DateTime tomorrow(int hour, [int minute = 0]) =>
        DateTime(now.year, now.month, now.day + 1, hour, minute);

    final sweetCrumb = Merchant(
      id: 'mer_sweetcrumb',
      legalName: 'Sweet Crumb Bakers Pvt Ltd',
      displayName: 'Sweet Crumb',
      category: 'cat_bakery',
      foodTypeTags: const ['food_bakery', 'food_desserts'],
      fssaiLicenceNumber: '12421001000123',
      fssaiLicenceExpiry: DateTime(2027, 3, 31),
      certifications: const [],
      logoUrl: 'https://picsum.photos/seed/sweetcrumb/200',
      storefrontPhotos: const [
        'https://picsum.photos/seed/sweetcrumb1/800/600',
        'https://picsum.photos/seed/sweetcrumb2/800/600',
      ],
      address: const Address(
        line1: '12, 100 Feet Road',
        floorOrShopNo: 'Shop 3',
        landmark: 'next to Indiranagar metro station',
        locality: 'Indiranagar',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560038',
        geo: LatLng(latitude: 12.9916, longitude: 77.6146),
      ),
      phone: '+918041234501',
      operatingHours: '8:00 am – 10:00 pm',
      description:
          'A neighbourhood bakery known for its sourdough and evening pastry '
          'spread.',
      ratingAggregate: const RatingAggregate(
        average: 4.3,
        count: 128,
        histogram: {1: 3, 2: 4, 3: 12, 4: 45, 5: 64},
      ),
      isVerified: true,
      grievanceContact: 'grievance@sweetcrumb.example',
      typicalListingTime: 'around 8 pm',
    );

    final greenLeaf = Merchant(
      id: 'mer_greenleaf',
      legalName: 'Green Leaf Kitchens LLP',
      displayName: 'Green Leaf',
      category: 'cat_restaurant',
      foodTypeTags: const ['food_south_indian', 'food_thali'],
      fssaiLicenceNumber: '12421001000456',
      fssaiLicenceExpiry: DateTime(2026, 11, 30),
      certifications: const [],
      logoUrl: 'https://picsum.photos/seed/greenleaf/200',
      storefrontPhotos: const [
        'https://picsum.photos/seed/greenleaf1/800/600',
      ],
      address: const Address(
        line1: '5th Block, 80 Feet Road',
        landmark: 'opposite Forum Mall',
        locality: 'Koramangala',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560034',
        geo: LatLng(latitude: 12.9566, longitude: 77.6096),
      ),
      phone: '+918041234502',
      operatingHours: '11:00 am – 10:30 pm',
      description: 'Pure vegetarian South Indian thalis and tiffin.',
      ratingAggregate: const RatingAggregate(
        average: 4.6,
        count: 342,
        histogram: {1: 4, 2: 6, 3: 20, 4: 90, 5: 222},
      ),
      isVerified: true,
      grievanceContact: 'grievance@greenleaf.example',
      typicalListingTime: 'around 9:30 pm',
    );

    final spiceHouse = Merchant(
      id: 'mer_spicehouse',
      legalName: 'Spice House Restaurants Pvt Ltd',
      displayName: 'Spice House',
      category: 'cat_restaurant',
      foodTypeTags: const ['food_north_indian', 'food_biryani'],
      fssaiLicenceNumber: '12421001000789',
      fssaiLicenceExpiry: DateTime(2026, 9, 15),
      certifications: const ['halal'],
      logoUrl: 'https://picsum.photos/seed/spicehouse/200',
      storefrontPhotos: const [
        'https://picsum.photos/seed/spicehouse1/800/600',
      ],
      address: const Address(
        line1: '27th Main',
        floorOrShopNo: 'Ground floor',
        landmark: 'behind HSR BDA Complex',
        locality: 'HSR Layout',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560102',
        geo: LatLng(latitude: 12.9216, longitude: 77.6346),
      ),
      phone: '+918041234503',
      operatingHours: '12:00 pm – 11:00 pm',
      description: 'Biryani and North Indian curries, halal-certified.',
      ratingAggregate: const RatingAggregate(
        average: 4.1,
        count: 89,
        histogram: {1: 5, 2: 6, 3: 15, 4: 28, 5: 35},
      ),
      isVerified: true,
      grievanceContact: 'grievance@spicehouse.example',
      typicalListingTime: 'around 9 pm',
    );

    final dailyBread = Merchant(
      id: 'mer_dailybread',
      legalName: 'Daily Bread Foods',
      displayName: 'Daily Bread',
      category: 'cat_bakery',
      foodTypeTags: const ['food_bakery'],
      fssaiLicenceNumber: '12421001000321',
      fssaiLicenceExpiry: DateTime(2026, 8, 20),
      certifications: const [],
      logoUrl: 'https://picsum.photos/seed/dailybread/200',
      storefrontPhotos: const [
        'https://picsum.photos/seed/dailybread1/800/600',
      ],
      address: const Address(
        line1: 'ITPL Main Road',
        landmark: 'near Whitefield bus depot',
        locality: 'Whitefield',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560066',
        geo: LatLng(latitude: 12.9816, longitude: 77.7146),
      ),
      phone: '+918041234504',
      operatingHours: '7:00 am – 9:00 pm',
      description: 'Everyday breads, buns and cakes.',
      ratingAggregate: const RatingAggregate(
        average: 3.9,
        count: 21,
        histogram: {1: 1, 2: 2, 3: 6, 4: 7, 5: 5},
      ),
      isVerified: false,
      grievanceContact: 'grievance@dailybread.example',
      typicalListingTime: 'around 7:30 pm',
    );

    final jainBhog = Merchant(
      id: 'mer_jainbhog',
      legalName: 'Jain Bhog Sweets',
      displayName: 'Jain Bhog',
      category: 'cat_sweetshop',
      foodTypeTags: const ['food_sweets', 'food_jain'],
      fssaiLicenceNumber: '12421001000654',
      fssaiLicenceExpiry: DateTime(2027, 1, 31),
      certifications: const [],
      logoUrl: 'https://picsum.photos/seed/jainbhog/200',
      storefrontPhotos: const ['https://picsum.photos/seed/jainbhog1/800/600'],
      address: const Address(
        line1: '4th Block',
        landmark: 'next to Jayanagar Complex',
        locality: 'Jayanagar',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560041',
        geo: LatLng(latitude: 12.9366, longitude: 77.5896),
      ),
      phone: '+918041234505',
      operatingHours: '9:00 am – 9:00 pm',
      description: 'Jain-friendly sweets and snacks, no onion or garlic.',
      ratingAggregate: const RatingAggregate(
        average: 4.7,
        count: 56,
        histogram: {1: 0, 2: 1, 3: 3, 4: 12, 5: 40},
      ),
      isVerified: true,
      grievanceContact: 'grievance@jainbhog.example',
      typicalListingTime: 'around 6:30 pm',
    );

    final urbanKitchen = Merchant(
      id: 'mer_urbankitchen',
      legalName: 'Urban Kitchen Cloud Foods',
      displayName: 'Urban Kitchen',
      category: 'cat_cloudkitchen',
      foodTypeTags: const ['food_multi_cuisine'],
      fssaiLicenceNumber: '12421001000987',
      fssaiLicenceExpiry: DateTime(2026, 12, 31),
      certifications: const [],
      logoUrl: 'https://picsum.photos/seed/urbankitchen/200',
      storefrontPhotos: const [
        'https://picsum.photos/seed/urbankitchen1/800/600',
      ],
      address: const Address(
        line1: '6th Block',
        landmark: 'near Sony World Signal',
        locality: 'Koramangala',
        city: 'Bengaluru',
        state: 'Karnataka',
        pincode: '560095',
        geo: LatLng(latitude: 12.9316, longitude: 77.6146),
      ),
      phone: '+918041234506',
      operatingHours: '11:00 am – 11:00 pm',
      description: 'Delivery-first multi-cuisine kitchen, new to the platform.',
      ratingAggregate: RatingAggregate.empty(),
      isVerified: true,
      grievanceContact: 'grievance@urbankitchen.example',
      typicalListingTime: null,
    );

    return [
      _MerchantFixture(
        sweetCrumb,
        [
          SurpriseBag(
            id: 'bag_sc_1',
            merchantId: sweetCrumb.id,
            title: 'Bakery Surprise Bag',
            description:
                "A mix of today's unsold breads, pastries and cookies.",
            dietaryEnvelope: DietaryEnvelope.containsEgg,
            categoryHint:
                "A selection of today's unsold breads, pastries and cookies.",
            price: const Money.rupees(120),
            statedRetailValue: const Money.rupees(350),
            discountPercent: 65,
            quantityTotal: 8,
            quantityAvailable: 2,
            pickupWindow: PickupWindow(
              startAt: today(20),
              endAt: today(22),
            ),
            safeUntil: today(22),
            imageUrl: 'https://picsum.photos/seed/scbag1/600/400',
            pickupInstructions:
                'Show your code at the counter; ask for the surprise bag.',
            status: BagStatus.live,
            remainingAllowanceForCustomer: 2,
          ),
          SurpriseBag(
            id: 'bag_sc_2',
            merchantId: sweetCrumb.id,
            title: 'Sweet Box',
            description: 'Assorted pastries and one whole cake slice.',
            dietaryEnvelope: DietaryEnvelope.containsEgg,
            categoryHint: 'Pastries, a cake slice, and a cookie or two.',
            price: const Money.rupees(150),
            statedRetailValue: const Money.rupees(400),
            discountPercent: 62,
            quantityTotal: 5,
            quantityAvailable: 5,
            pickupWindow: PickupWindow(
              startAt: today(21),
              endAt: tomorrow(0),
            ),
            safeUntil: tomorrow(0),
            imageUrl: 'https://picsum.photos/seed/scbag2/600/400',
            pickupInstructions: 'Collect from the side counter after 9 pm.',
            status: BagStatus.live,
            remainingAllowanceForCustomer: 2,
          ),
          SurpriseBag(
            id: 'bag_sc_3',
            merchantId: sweetCrumb.id,
            title: "Yesterday's Sold-out Bag",
            description: 'Demo fixture for the soldOut bag-detail state.',
            dietaryEnvelope: DietaryEnvelope.containsEgg,
            categoryHint: 'Breads and pastries.',
            price: const Money.rupees(120),
            statedRetailValue: const Money.rupees(350),
            discountPercent: 65,
            quantityTotal: 6,
            quantityAvailable: 0,
            pickupWindow: PickupWindow(
              startAt: today(20),
              endAt: today(22),
            ),
            safeUntil: today(22),
            imageUrl: 'https://picsum.photos/seed/scbag3/600/400',
            pickupInstructions: 'Collect from the side counter after 9 pm.',
            status: BagStatus.soldOut,
            remainingAllowanceForCustomer: 0,
          ),
        ],
        [
          Review(
            id: 'rev_sc_1',
            orderId: 'ord_demo_1',
            customerId: 'cust_demo_1',
            merchantId: sweetCrumb.id,
            rating: 5,
            tags: const ['fresh', 'great value'],
            comment: 'Loaded with pastries, way more than I expected.',
            createdAt: now.subtract(const Duration(days: 3)),
            customerDisplayName: 'Asha',
          ),
          Review(
            id: 'rev_sc_2',
            orderId: 'ord_demo_2',
            customerId: 'cust_demo_2',
            merchantId: sweetCrumb.id,
            rating: 4,
            tags: const ['fresh'],
            comment: 'Good bag, one item was a bit dry.',
            createdAt: now.subtract(const Duration(days: 10)),
            customerDisplayName: 'Rohit',
          ),
        ],
      ),
      _MerchantFixture(
        greenLeaf,
        [
          SurpriseBag(
            id: 'bag_gl_1',
            merchantId: greenLeaf.id,
            title: 'Thali Surprise Bag',
            description: 'A generous mixed thali portion, packed fresh.',
            dietaryEnvelope: DietaryEnvelope.pureVeg,
            categoryHint: "Today's thali items — rice, curry, sides, sweet.",
            price: const Money.rupees(99),
            statedRetailValue: const Money.rupees(280),
            discountPercent: 65,
            quantityTotal: 10,
            quantityAvailable: 6,
            pickupWindow: PickupWindow(
              startAt: today(now.hour), // collect-now section
              endAt: today(now.hour + 2).isAfter(today(23))
                  ? today(23, 59)
                  : today(now.hour + 2),
            ),
            safeUntil: today(23, 59),
            imageUrl: 'https://picsum.photos/seed/glbag1/600/400',
            pickupInstructions: 'Ask for the surprise thali at the counter.',
            status: BagStatus.live,
            remainingAllowanceForCustomer: 2,
          ),
          SurpriseBag(
            id: 'bag_gl_2',
            merchantId: greenLeaf.id,
            title: 'Tiffin Box',
            description: 'Idli, vada, and chutneys.',
            dietaryEnvelope: DietaryEnvelope.pureVeg,
            categoryHint: 'South Indian breakfast tiffin items.',
            price: const Money.rupees(80),
            statedRetailValue: const Money.rupees(220),
            discountPercent: 64,
            quantityTotal: 4,
            quantityAvailable: 1,
            pickupWindow: PickupWindow(
              startAt: tomorrow(8),
              endAt: tomorrow(10),
            ),
            safeUntil: tomorrow(10),
            imageUrl: 'https://picsum.photos/seed/glbag2/600/400',
            pickupInstructions: 'Morning pickup — ring the bell if closed.',
            status: BagStatus.live,
            remainingAllowanceForCustomer: 1,
            allergenNotes: 'May contain traces of peanut.',
          ),
        ],
        [
          Review(
            id: 'rev_gl_1',
            orderId: 'ord_demo_3',
            customerId: 'cust_demo_3',
            merchantId: greenLeaf.id,
            rating: 5,
            tags: const ['authentic', 'great value'],
            comment: 'Best thali deal in the area, every time.',
            createdAt: now.subtract(const Duration(days: 1)),
            customerDisplayName: 'Priya',
          ),
        ],
      ),
      _MerchantFixture(
        spiceHouse,
        [
          SurpriseBag(
            id: 'bag_sh_1',
            merchantId: spiceHouse.id,
            title: 'Biryani Surprise Bag',
            description: 'A hearty biryani-based surprise portion.',
            dietaryEnvelope: DietaryEnvelope.nonVeg,
            categoryHint: 'Biryani, kebabs, or curry — whatever is unsold.',
            price: const Money.rupees(140),
            statedRetailValue: const Money.rupees(380),
            discountPercent: 63,
            quantityTotal: 6,
            quantityAvailable: 3,
            pickupWindow: PickupWindow(
              startAt: today(21),
              endAt: today(23),
            ),
            safeUntil: today(23),
            imageUrl: 'https://picsum.photos/seed/shbag1/600/400',
            pickupInstructions: 'Show your code to the counter staff.',
            status: BagStatus.live,
            remainingAllowanceForCustomer: 2,
            allergenNotes: 'Contains dairy and nuts.',
          ),
          SurpriseBag(
            id: 'bag_sh_2',
            merchantId: spiceHouse.id,
            title: "Window Closed Demo Bag",
            description: 'Demo fixture for the windowClosed bag-detail state.',
            dietaryEnvelope: DietaryEnvelope.nonVeg,
            categoryHint: 'Curry and rice.',
            price: const Money.rupees(130),
            statedRetailValue: const Money.rupees(350),
            discountPercent: 63,
            quantityTotal: 4,
            quantityAvailable: 1,
            pickupWindow: PickupWindow(
              startAt: today(now.hour > 1 ? now.hour - 2 : 0),
              endAt: today(now.hour > 0 ? now.hour : 1),
            ),
            safeUntil: today(23, 59),
            imageUrl: 'https://picsum.photos/seed/shbag2/600/400',
            pickupInstructions: 'Show your code to the counter staff.',
            status: BagStatus.windowClosed,
            remainingAllowanceForCustomer: 1,
          ),
        ],
        const [],
      ),
      _MerchantFixture(
        dailyBread,
        [
          SurpriseBag(
            id: 'bag_db_1',
            merchantId: dailyBread.id,
            title: 'Bread Basket',
            description: 'End-of-day loaves and buns.',
            dietaryEnvelope: DietaryEnvelope.containsEgg,
            categoryHint: 'Bread loaves and buns.',
            price: const Money.rupees(70),
            statedRetailValue: const Money.rupees(180),
            discountPercent: 61,
            quantityTotal: 10,
            quantityAvailable: 8,
            pickupWindow: PickupWindow(
              startAt: tomorrow(9),
              endAt: tomorrow(11),
            ),
            safeUntil: tomorrow(11),
            imageUrl: 'https://picsum.photos/seed/dbbag1/600/400',
            pickupInstructions: 'Collect from the front counter.',
            status: BagStatus.live,
            remainingAllowanceForCustomer: 2,
          ),
          SurpriseBag(
            id: 'bag_db_2',
            merchantId: dailyBread.id,
            title: 'Withdrawn Demo Bag',
            description: 'Demo fixture for the withdrawn bag-detail state.',
            dietaryEnvelope: DietaryEnvelope.containsEgg,
            categoryHint: 'Bread loaves.',
            price: const Money.rupees(70),
            statedRetailValue: const Money.rupees(180),
            discountPercent: 61,
            quantityTotal: 4,
            quantityAvailable: 4,
            pickupWindow: PickupWindow(
              startAt: tomorrow(9),
              endAt: tomorrow(11),
            ),
            safeUntil: tomorrow(11),
            imageUrl: 'https://picsum.photos/seed/dbbag2/600/400',
            pickupInstructions: 'Collect from the front counter.',
            status: BagStatus.withdrawnByMerchant,
            remainingAllowanceForCustomer: 2,
          ),
        ],
        [
          Review(
            id: 'rev_db_1',
            orderId: 'ord_demo_4',
            customerId: 'cust_demo_4',
            merchantId: dailyBread.id,
            rating: 3,
            tags: const ['ok'],
            comment: 'Fine, nothing special.',
            createdAt: now.subtract(const Duration(days: 20)),
            customerDisplayName: 'Deepak',
          ),
        ],
      ),
      _MerchantFixture(
        jainBhog,
        [
          SurpriseBag(
            id: 'bag_jb_1',
            merchantId: jainBhog.id,
            title: 'Jain Sweet Box',
            description: 'Assorted Jain-friendly sweets and namkeen.',
            dietaryEnvelope: DietaryEnvelope.jain,
            categoryHint: 'Sweets and namkeen, no onion or garlic.',
            price: const Money.rupees(110),
            statedRetailValue: const Money.rupees(300),
            discountPercent: 63,
            quantityTotal: 6,
            quantityAvailable: 1,
            pickupWindow: PickupWindow(
              startAt: today(18),
              endAt: today(20),
            ),
            safeUntil: today(20),
            imageUrl: 'https://picsum.photos/seed/jbbag1/600/400',
            pickupInstructions: 'Ask for the Jain surprise box.',
            status: BagStatus.live,
            remainingAllowanceForCustomer: 1,
          ),
        ],
        [
          Review(
            id: 'rev_jb_1',
            orderId: 'ord_demo_5',
            customerId: 'cust_demo_5',
            merchantId: jainBhog.id,
            rating: 5,
            tags: const ['authentic', 'jain-friendly'],
            comment: 'Finally a place I can trust completely.',
            createdAt: now.subtract(const Duration(days: 5)),
            customerDisplayName: 'Meera',
          ),
        ],
      ),
      _MerchantFixture(urbanKitchen, const [], const []),
    ];
  }
}

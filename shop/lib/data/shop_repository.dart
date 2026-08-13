import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:too_good_to_leave_shop/core/domain/clock.dart';
import 'package:too_good_to_leave_shop/core/domain/dietary_envelope.dart';
import 'package:too_good_to_leave_shop/core/domain/money.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_token.dart';
import 'package:too_good_to_leave_shop/core/domain/pickup_window.dart';
import 'package:too_good_to_leave_shop/domain/payout.dart';
import 'package:too_good_to_leave_shop/domain/shop_bag.dart';
import 'package:too_good_to_leave_shop/domain/shop_category.dart';
import 'package:too_good_to_leave_shop/domain/shop_notification.dart';
import 'package:too_good_to_leave_shop/domain/shop_order.dart';
import 'package:too_good_to_leave_shop/domain/shop_profile.dart';
import 'package:too_good_to_leave_shop/domain/store_hours.dart';

/// Thrown when a fallback code doesn't match the order it's checked against.
class PickupCodeMismatchException implements Exception {
  const PickupCodeMismatchException();
}

const _payoutsKey = 'shop_payouts';
const _notificationsKey = 'shop_notifications';
const _storeHoursKey = 'shop_store_hours';

String _categoryToWire(ShopCategory category) => switch (category) {
  ShopCategory.sweetsShop => 'sweets_shop',
  ShopCategory.cloudKitchen => 'cloud_kitchen',
  _ => category.name,
};

ShopCategory _categoryFromWire(String value) => switch (value) {
  'sweets_shop' => ShopCategory.sweetsShop,
  'cloud_kitchen' => ShopCategory.cloudKitchen,
  _ => ShopCategory.values.firstWhere(
    (c) => c.name == value,
    orElse: () => ShopCategory.other,
  ),
};

ShopApprovalStatus _approvalFromWire(String value) => switch (value) {
  'verified' => ShopApprovalStatus.verified,
  'rejected' => ShopApprovalStatus.rejected,
  _ => ShopApprovalStatus.pendingReview,
};

/// Fields shared by insert and update — everything the registration/account
/// screens actually collect. `auth_user_id`/`state`/`pincode` aren't
/// collected by today's UI, so they're insert-only defaults (see
/// [_shopInsertRow]) rather than something an edit could ever reset.
Map<String, dynamic> _shopUpdateRow(ShopProfile profile) => {
  'display_name': profile.businessName,
  'legal_name': profile.businessName,
  'category': _categoryToWire(profile.category),
  'address_line1': profile.addressLine,
  // The registration form only captures a single locality string today —
  // landmark/city reuse it and state/pincode get placeholders (below)
  // until a real structured-address screen replaces this.
  'landmark': profile.locality,
  'locality': profile.locality,
  'city': profile.locality,
  'phone': profile.phone,
  'fssai_license_number': profile.fssai.licenseNumber,
  'fssai_license_expiry': profile.fssai.expiresAt.toIso8601String().split(
    'T',
  )[0],
  'updated_at': DateTime.now().toUtc().toIso8601String(),
};

/// Bengaluru city centre — the customer app's own launch-city fallback
/// (`LocationRepositoryFake._cityCenter`). Used only when real geolocation
/// isn't available/granted, so a shop still lands somewhere the customer
/// app actually considers "in service" rather than off the coast of
/// Africa at `(0, 0)`.
const _fallbackLat = 12.9716;
const _fallbackLng = 77.5946;

/// Real device geolocation at the moment of registration — a shop is
/// physically where its owner is standing when they sign up, which is a
/// reasonable proxy for "where the shop is" without building a full
/// address-to-coordinates lookup. Falls back to Bengaluru (see
/// [_fallbackLat]) on denial/timeout/any platform error rather than
/// blocking registration on a permission prompt succeeding.
Future<({double lat, double lng})> _resolveShopLocation() async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return (lat: _fallbackLat, lng: _fallbackLng);
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        timeLimit: Duration(seconds: 15),
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  } catch (_) {
    return (lat: _fallbackLat, lng: _fallbackLng);
  }
}

Map<String, dynamic> _shopInsertRow(
  ShopProfile profile,
  String authUserId, {
  required double lat,
  required double lng,
}) => {
  ..._shopUpdateRow(profile),
  'auth_user_id': authUserId,
  'state': 'Unknown',
  'pincode': '000000',
  'lat': lat,
  'lng': lng,
};

Map<String, dynamic> _billingRow(ShopProfile profile, {String? shopId}) => {
  if (shopId != null) 'shop_id': shopId,
  'owner_name': profile.ownerName,
  'owner_email': profile.email,
  'bank_account_holder_name': profile.bankDetails.accountHolderName,
  'bank_account_number': profile.bankDetails.accountNumber,
  'bank_ifsc_code': profile.bankDetails.ifscCode,
  'bank_upi_id': profile.bankDetails.upiId,
  'updated_at': DateTime.now().toUtc().toIso8601String(),
};

ShopProfile _profileFromRows(
  Map<String, dynamic> shop,
  Map<String, dynamic> billing,
) => ShopProfile(
  businessName: shop['display_name'] as String,
  ownerName: billing['owner_name'] as String,
  phone: shop['phone'] as String,
  email: billing['owner_email'] as String,
  category: _categoryFromWire(shop['category'] as String),
  addressLine: shop['address_line1'] as String,
  locality: shop['locality'] as String,
  fssai: FssaiLicense(
    licenseNumber: shop['fssai_license_number'] as String,
    expiresAt: DateTime.parse(shop['fssai_license_expiry'] as String),
  ),
  bankDetails: BankDetails(
    accountHolderName: billing['bank_account_holder_name'] as String,
    accountNumber: billing['bank_account_number'] as String,
    ifscCode: billing['bank_ifsc_code'] as String,
    upiId: billing['bank_upi_id'] as String?,
  ),
  status: _approvalFromWire(shop['approval_status'] as String),
  rejectionReason: billing['rejection_reason'] as String?,
);

BagStatus _bagStatusFromWire(String value) => BagStatus.values.firstWhere(
  (s) => s.name == value,
  orElse: () => BagStatus.paused,
);

Map<String, dynamic> _bagRow({
  required String title,
  required String description,
  required DietaryEnvelope envelope,
  required Money price,
  required int quantityAvailable,
  required PickupWindow pickupWindow,
  required BagStatus status,
  required bool repeatsDaily,
  required List<String> tags,
  String? shopId,
  // Create has no prior row, so total starts equal to available. Update
  // passes the existing row's total (see `updateBag`) so an edit that
  // doesn't touch quantity never silently discards how many were
  // originally listed — only ever grows to cover a genuine restock.
  int? quantityTotal,
}) => {
  if (shopId != null) 'shop_id': shopId,
  'title': title,
  'description': description,
  'dietary_envelope': envelope.wireValue,
  'tags': tags,
  'price_paise': price.amountInPaise,
  // Not collected by today's bag editor — a plausible default that keeps
  // the schema's `price < stated_retail_value` constraint satisfied until
  // a real "original price" field is added to the editor.
  'stated_retail_value_paise': price.amountInPaise * 2,
  'quantity_total': quantityTotal == null
      ? quantityAvailable
      : (quantityTotal < quantityAvailable ? quantityAvailable : quantityTotal),
  'quantity_available': quantityAvailable,
  'pickup_start_at': pickupWindow.startAt.toIso8601String(),
  'pickup_end_at': pickupWindow.endAt.toIso8601String(),
  'safe_until': pickupWindow.endAt.toIso8601String(),
  'status': status.name,
  'repeats_daily': repeatsDaily,
  'updated_at': DateTime.now().toUtc().toIso8601String(),
};

ShopBag _bagFromRow(Map<String, dynamic> row) => ShopBag(
  id: row['id'] as String,
  title: row['title'] as String,
  description: row['description'] as String,
  envelope: DietaryEnvelope.fromWire(row['dietary_envelope'] as String),
  price: Money(row['price_paise'] as int),
  quantityAvailable: row['quantity_available'] as int,
  pickupWindow: PickupWindow(
    startAt: DateTime.parse(row['pickup_start_at'] as String),
    endAt: DateTime.parse(row['pickup_end_at'] as String),
  ),
  status: _bagStatusFromWire(row['status'] as String),
  repeatsDaily: row['repeats_daily'] as bool? ?? false,
  tags: (row['tags'] as List).cast<String>(),
);

ShopOrderStatus _shopOrderStatusFromWire(String value) => switch (value) {
  'collected' => ShopOrderStatus.collected,
  'cancelled_by_customer' ||
  'cancelled_by_merchant' => ShopOrderStatus.cancelled,
  'expired_uncollected' => ShopOrderStatus.expired,
  _ => ShopOrderStatus.reserved,
};

PickupToken _tokenFromRow(Map<String, dynamic>? json) {
  if (json == null) {
    // Every order the customer app creates populates this at insert time —
    // null only happens for data created outside that path.
    final now = DateTime.now();
    return PickupToken(
      rotatingPayload: '',
      rotationExpiresAt: now,
      offlineToken: '',
      offlineTokenValidUntil: now,
      fallbackCode: '------',
    );
  }
  return PickupToken(
    rotatingPayload: json['rotatingPayload'] as String? ?? '',
    rotationExpiresAt: DateTime.parse(json['rotationExpiresAt'] as String),
    offlineToken: json['offlineToken'] as String? ?? '',
    offlineTokenValidUntil: DateTime.parse(
      json['offlineTokenValidUntil'] as String,
    ),
    fallbackCode: json['fallbackCode'] as String,
  );
}

ShopOrder _orderFromRow(Map<String, dynamic> row) {
  final bagSnapshot = (row['bag_snapshot'] as Map).cast<String, dynamic>();
  final customerSnapshot = (row['customer_snapshot'] as Map)
      .cast<String, dynamic>();
  final priceBreakdown = (row['price_breakdown'] as Map)
      .cast<String, dynamic>();
  return ShopOrder(
    id: row['id'] as String,
    bagTitle: bagSnapshot['title'] as String? ?? 'Surprise bag',
    customerName: customerSnapshot['name'] as String? ?? 'Customer',
    pickupWindow: PickupWindow(
      startAt: DateTime.parse(row['pickup_start_at'] as String),
      endAt: DateTime.parse(row['pickup_end_at'] as String),
    ),
    token: _tokenFromRow(
      (row['pickup_token'] as Map?)?.cast<String, dynamic>(),
    ),
    price: Money((priceBreakdown['total'] as num).round()),
    status: _shopOrderStatusFromWire(row['status'] as String),
  );
}

/// Shop-side data — registration, bags, orders, payments/payouts, and
/// notifications.
///
/// Registration, bags, and orders are backed by the shared Supabase project
/// (`supabase/schema.sql`) once loaded via [ShopRepository.load] — the same
/// backend the customer app reads/writes, so a bag published here shows up
/// live on the customer side, and an order placed there shows up live here
/// (via a Realtime subscription on `orders`). Payouts, notifications, and
/// store hours stay on local `shared_preferences` — genuinely local
/// shop-device settings that don't need to sync anywhere.
///
/// The plain [ShopRepository] constructor stays purely in-memory and
/// fixture-seeded, touching neither Supabase nor `shared_preferences` beyond
/// the local-only sections — it exists for fast unit/widget tests that
/// exercise bag/order/payout domain logic without a backend.
class ShopRepository extends ChangeNotifier {
  ShopRepository({this._clock = const SystemClock()}) : _useBackend = false {
    _seedOrdersAndBags();
  }

  ShopRepository._loaded({required this._clock}) : _useBackend = true;

  /// Loads local settings (payouts/notifications/store hours) and, if a
  /// Supabase session already exists on this device, the signed-in shop's
  /// profile/bags/orders plus a live subscription for new orders.
  static Future<ShopRepository> load({
    Clock clock = const SystemClock(),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final repo = ShopRepository._loaded(clock: clock);

    final payoutsJson = prefs.getString(_payoutsKey);
    final notificationsJson = prefs.getString(_notificationsKey);
    final storeHoursJson = prefs.getString(_storeHoursKey);

    if (payoutsJson != null) {
      repo._payouts.addAll(
        (jsonDecode(payoutsJson) as List).cast<Map<String, dynamic>>().map(
          PayoutRecord.fromJson,
        ),
      );
    }
    if (notificationsJson != null) {
      repo._notifications.addAll(
        (jsonDecode(notificationsJson) as List)
            .cast<Map<String, dynamic>>()
            .map(ShopNotification.fromJson),
      );
    }
    if (storeHoursJson != null) {
      repo._storeHours = StoreHours.fromJson(
        jsonDecode(storeHoursJson) as Map<String, dynamic>,
      );
    }

    // Supabase.instance throws if Supabase.initialize() was never called —
    // true in unit/widget tests, which never touch the network. Treat that
    // the same as "no session": the bare fixture-free unregistered state.
    User? user;
    try {
      user = repo._client.auth.currentUser;
    } catch (_) {
      return repo;
    }
    if (user == null) return repo;

    final shopRow = await repo._client
        .from('shops')
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();
    if (shopRow == null) return repo;

    final billingRow = await repo._client
        .from('shop_billing')
        .select()
        .eq('shop_id', shopRow['id'] as String)
        .single();

    repo._shopId = shopRow['id'] as String;
    repo._profile = _profileFromRows(shopRow, billingRow);
    await repo._loadBagsAndOrders();
    repo._subscribeToOrders();
    return repo;
  }

  final Clock _clock;
  final bool _useBackend;

  SupabaseClient get _client => Supabase.instance.client;

  String? _shopId;
  RealtimeChannel? _ordersChannel;

  ShopProfile? _profile;
  final List<ShopBag> _bags = [];
  final List<ShopOrder> _orders = [];
  final List<PayoutRecord> _payouts = [];
  final List<ShopNotification> _notifications = [];
  StoreHours _storeHours = StoreHours.defaults();
  int _nextBagId = 1;
  int _nextPayoutId = 1;
  int _nextNotificationId = 1;

  void _addNotification(String message) {
    _notifications.insert(
      0,
      ShopNotification(
        id: 'notif_${_nextNotificationId++}',
        message: message,
        createdAt: _clock.now(),
      ),
    );
  }

  /// Derives the next id from the highest `bag_N` suffix actually present —
  /// only used by the fixture-only, non-backend constructor.
  void _recomputeNextBagId() {
    var highest = 0;
    for (final bag in _bags) {
      final suffix = int.tryParse(bag.id.replaceFirst('bag_', ''));
      if (suffix != null && suffix > highest) highest = suffix;
    }
    _nextBagId = highest + 1;
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _payoutsKey,
      jsonEncode(_payouts.map((p) => p.toJson()).toList()),
    );
    await prefs.setString(
      _notificationsKey,
      jsonEncode(_notifications.map((n) => n.toJson()).toList()),
    );
    await prefs.setString(_storeHoursKey, jsonEncode(_storeHours.toJson()));
  }

  Future<void> _loadBagsAndOrders() async {
    final shopId = _shopId;
    if (shopId == null) return;
    final bagRows = await _client
        .from('bags')
        .select()
        .eq('shop_id', shopId)
        .neq('status', 'withdrawn_by_merchant')
        .order('created_at');
    _bags
      ..clear()
      ..addAll((bagRows as List).cast<Map<String, dynamic>>().map(_bagFromRow));

    final orderRows = await _client
        .from('orders')
        .select()
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);
    _orders
      ..clear()
      ..addAll(
        (orderRows as List).cast<Map<String, dynamic>>().map(_orderFromRow),
      );
  }

  /// New orders arrive live — a customer completing checkout against this
  /// shop's bag shows up here without any manual refresh, which is the
  /// "shop gets notified" half of the order lifecycle.
  void _subscribeToOrders() {
    final shopId = _shopId;
    if (shopId == null) return;
    _ordersChannel = _client
        .channel('shop-orders-$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (payload) {
            final order = _orderFromRow(payload.newRecord);
            if (_orders.any((o) => o.id == order.id)) return;
            _orders.insert(0, order);
            _addNotification(
              'New order — ${order.bagTitle} for ${order.customerName}.',
            );
            notifyListeners();
            unawaited(_persistLocal());
          },
        )
        .subscribe();
  }

  void _seedOrdersAndBags() {
    final now = _clock.now();
    final today = DateTime(now.year, now.month, now.day);

    _bags.addAll([
      ShopBag(
        id: 'bag_1',
        title: 'Bakery Surprise Bag',
        description: 'Assorted breads, pastries, and baked leftovers.',
        envelope: DietaryEnvelope.pureVeg,
        price: const Money.rupees(99),
        quantityAvailable: 4,
        pickupWindow: PickupWindow(
          startAt: today.add(const Duration(hours: 19)),
          endAt: today.add(const Duration(hours: 21)),
        ),
        status: BagStatus.live,
      ),
      ShopBag(
        id: 'bag_2',
        title: 'Lunch Combo Surprise',
        description: 'End-of-service curries, rice, and sides.',
        envelope: DietaryEnvelope.nonVeg,
        price: const Money.rupees(149),
        quantityAvailable: 2,
        pickupWindow: PickupWindow(
          startAt: today.add(const Duration(hours: 15)),
          endAt: today.add(const Duration(hours: 16)),
        ),
        status: BagStatus.live,
      ),
      ShopBag(
        id: 'bag_3',
        title: 'Evening Sweets Box',
        description: 'Mixed sweets nearing best-before.',
        envelope: DietaryEnvelope.jain,
        price: const Money.rupees(79),
        quantityAvailable: 0,
        pickupWindow: PickupWindow(
          startAt: today.add(const Duration(hours: 18)),
          endAt: today.add(const Duration(hours: 20)),
        ),
        status: BagStatus.draft,
      ),
    ]);
    _recomputeNextBagId();

    _orders.addAll([
      ShopOrder(
        id: 'ord_1',
        bagTitle: 'Bakery Surprise Bag',
        customerName: 'Aditi',
        pickupWindow: _bags[0].pickupWindow,
        price: _bags[0].price,
        token: PickupToken(
          rotatingPayload: 'rot_ord1',
          rotationExpiresAt: now.add(const Duration(seconds: 60)),
          offlineToken: 'off_ord1',
          offlineTokenValidUntil: _bags[0].pickupWindow.endAt,
          fallbackCode: 'H4K9PQ',
        ),
      ),
      ShopOrder(
        id: 'ord_2',
        bagTitle: 'Lunch Combo Surprise',
        customerName: 'Rohan',
        pickupWindow: _bags[1].pickupWindow,
        price: _bags[1].price,
        token: PickupToken(
          rotatingPayload: 'rot_ord2',
          rotationExpiresAt: now.add(const Duration(seconds: 60)),
          offlineToken: 'off_ord2',
          offlineTokenValidUntil: _bags[1].pickupWindow.endAt,
          fallbackCode: 'M7X2DV',
        ),
        status: ShopOrderStatus.collected,
      ),
    ]);
  }

  // ---------------------------------------------------------------------
  // Registration / account
  // ---------------------------------------------------------------------

  ShopProfile? get profile => _profile;

  bool get isRegistered => _profile != null;

  /// Signs in via Supabase's **anonymous auth** (no email/SMS provider
  /// needed — see module doc) and creates/loads the matching
  /// `shops`/`shop_billing` rows. Requires Authentication > Settings >
  /// "Allow anonymous sign-ins" enabled in the Supabase dashboard.
  ///
  /// [lat]/[lng] come from the registration screen's map picker when the
  /// shop owner confirms a pin; when omitted, falls back to
  /// [_resolveShopLocation] (silent device geolocation, then Bengaluru).
  Future<void> register(ShopProfile profile, {double? lat, double? lng}) async {
    if (!_useBackend) {
      _profile = profile;
      notifyListeners();
      return;
    }

    var user = _client.auth.currentUser;
    if (user == null) {
      final AuthResponse res;
      try {
        res = await _client.auth.signInAnonymously();
      } on AuthException catch (e) {
        throw StateError(
          'Supabase anonymous sign-in failed ($e). Check Authentication > '
          'Settings > "Allow anonymous sign-ins" is enabled.',
        );
      }
      user = res.user;
    }
    if (user == null) {
      throw StateError('Supabase anonymous sign-in returned no user.');
    }

    final location = (lat != null && lng != null)
        ? (lat: lat, lng: lng)
        : await _resolveShopLocation();
    Map<String, dynamic> shopRow;
    try {
      shopRow = await _client
          .from('shops')
          .insert(
            _shopInsertRow(
              profile,
              user.id,
              lat: location.lat,
              lng: location.lng,
            ),
          )
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // unique_violation on auth_user_id
      shopRow = await _client
          .from('shops')
          .select()
          .eq('auth_user_id', user.id)
          .single();
    }
    final shopId = shopRow['id'] as String;
    final billingRow = await _client
        .from('shop_billing')
        .upsert(_billingRow(profile, shopId: shopId))
        .select()
        .single();

    _shopId = shopId;
    _profile = _profileFromRows(shopRow, billingRow);
    await _loadBagsAndOrders();
    _subscribeToOrders();
    notifyListeners();
  }

  /// Signs in with a real Supabase email+password identity — the one
  /// deliberate exception to this app's otherwise-anonymous auth (see
  /// [register]'s doc). This is what lets a shop return to the *same*
  /// account from any browser/device using nothing but a fixed
  /// email/password, which anonymous sign-in (tied to one browser's local
  /// session) can't do on its own.
  ///
  /// The matching Supabase user must already exist — create it via the
  /// Supabase dashboard's **Authentication > Users > "Add user"** (with
  /// "Auto Confirm User" checked) so this never goes through the sign-up
  /// mailer that caused problems earlier.
  ///
  /// Returns `true` once an existing shop tied to this account is loaded
  /// and ready. Returns `false` when the credentials are valid but no shop
  /// is registered under this account yet — the session is still real and
  /// signed in, so the caller can proceed straight to [register] and it
  /// will attach the new shop to this same identity rather than creating a
  /// throwaway anonymous one (see [register]'s own "already signed in"
  /// check).
  Future<bool> logIn({required String email, required String password}) async {
    if (!_useBackend) return false;
    await _client.auth.signInWithPassword(email: email, password: password);
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Supabase sign-in returned no user.');
    }

    final shopRow = await _client
        .from('shops')
        .select()
        .eq('auth_user_id', user.id)
        .maybeSingle();
    if (shopRow == null) return false;

    final billingRow = await _client
        .from('shop_billing')
        .select()
        .eq('shop_id', shopRow['id'] as String)
        .single();

    _shopId = shopRow['id'] as String;
    _profile = _profileFromRows(shopRow, billingRow);
    await _loadBagsAndOrders();
    _subscribeToOrders();
    notifyListeners();
    return true;
  }

  /// Sends a real Supabase password-reset email for a [logIn] account.
  /// Unlike sign-up, a reset email is unavoidable — resetting a password is
  /// the one auth action here that has no hardcoded-workaround shape — so
  /// this only actually reaches an inbox if a working SMTP provider is
  /// configured (see `logIn`'s doc on the sign-up mailer issues this app
  /// otherwise avoids entirely).
  Future<void> requestPasswordReset(String email) async {
    if (!_useBackend) return;
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Stands in for a real review process — there's no admin surface in this
  /// standalone build, so approval is a demo action the registration flow's
  /// own "pending review" screen exposes, rather than something that
  /// silently never resolves.
  Future<void> simulateApproval() async {
    final current = _profile;
    if (current == null) return;
    if (_useBackend) {
      final shopId = _shopId;
      if (shopId == null) return;
      await _client
          .from('shops')
          .update({
            'approval_status': 'verified',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', shopId);
    }
    _profile = current.copyWith(status: ShopApprovalStatus.verified);
    notifyListeners();
  }

  Future<void> updateProfile(ShopProfile updated) async {
    if (_useBackend) {
      final shopId = _shopId;
      if (shopId == null) return;
      await _client
          .from('shops')
          .update(_shopUpdateRow(updated))
          .eq('id', shopId);
      await _client
          .from('shop_billing')
          .update(_billingRow(updated))
          .eq('shop_id', shopId);
    }
    _profile = updated;
    notifyListeners();
  }

  /// Ends the Supabase session (or, for the fixture-only build, just clears
  /// in-memory state) and drops this device's cached profile/bags/orders.
  Future<void> logOut() async {
    if (_useBackend) {
      await _ordersChannel?.unsubscribe();
      _ordersChannel = null;
      await _client.auth.signOut();
    }
    _profile = null;
    _shopId = null;
    _bags.clear();
    _orders.clear();
    _nextBagId = 1;
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Bags
  // ---------------------------------------------------------------------

  List<ShopBag> getBags() => List.unmodifiable(_bags);

  Future<ShopBag> createBag({
    required String title,
    required String description,
    required DietaryEnvelope envelope,
    required Money price,
    required int quantityAvailable,
    required PickupWindow pickupWindow,
    Uint8List? photoBytes,
    bool repeatsDaily = false,
    List<String> tags = const [],
  }) async {
    if (!_useBackend) {
      final bag = ShopBag(
        id: 'bag_${_nextBagId++}',
        title: title,
        description: description,
        envelope: envelope,
        price: price,
        quantityAvailable: quantityAvailable,
        pickupWindow: pickupWindow,
        photoBytes: photoBytes,
        repeatsDaily: repeatsDaily,
        tags: tags,
      );
      _bags.add(bag);
      notifyListeners();
      return bag;
    }

    final shopId = _shopId;
    if (shopId == null) {
      throw StateError('createBag called before a shop is registered.');
    }
    final row = await _client
        .from('bags')
        .insert(
          _bagRow(
            shopId: shopId,
            title: title,
            description: description,
            envelope: envelope,
            price: price,
            quantityAvailable: quantityAvailable,
            pickupWindow: pickupWindow,
            status: BagStatus.draft,
            repeatsDaily: repeatsDaily,
            tags: tags,
          ),
        )
        .select()
        .single();
    // Supabase Storage upload for `photoBytes` isn't wired yet — bags sync
    // live across apps without photos for now; kept locally for this
    // session's preview only.
    final bag = _bagFromRow(row).copyWith(photoBytes: photoBytes);
    _bags.add(bag);
    notifyListeners();
    return bag;
  }

  Future<void> updateBag(ShopBag updated) async {
    if (_useBackend) {
      final existing = await _client
          .from('bags')
          .select('quantity_total')
          .eq('id', updated.id)
          .maybeSingle();
      await _client
          .from('bags')
          .update(
            _bagRow(
              title: updated.title,
              description: updated.description,
              envelope: updated.envelope,
              price: updated.price,
              quantityAvailable: updated.quantityAvailable,
              pickupWindow: updated.pickupWindow,
              status: updated.status,
              repeatsDaily: updated.repeatsDaily,
              tags: updated.tags,
              quantityTotal: existing?['quantity_total'] as int?,
            ),
          )
          .eq('id', updated.id);
    }
    final index = _bags.indexWhere((b) => b.id == updated.id);
    if (index != -1) _bags[index] = updated;
    notifyListeners();
  }

  Future<void> deleteBag(String id) async {
    if (_useBackend) {
      try {
        await _client.from('bags').delete().eq('id', id);
      } on PostgrestException catch (e) {
        // 23503 = foreign key violation — this bag has orders against it
        // (`orders.bag_id`), which must keep pointing at a real row even
        // for a cancelled/collected order from days ago. A hard delete is
        // only possible for a bag nobody ever ordered; otherwise withdraw
        // it instead — same end state for the shop (gone from their list),
        // but the row survives for order history to keep resolving.
        if (e.code == '23503') {
          await _client
              .from('bags')
              .update({
                'status': 'withdrawn_by_merchant',
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', id);
        } else {
          rethrow;
        }
      }
    }
    _bags.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  /// Copies a bag's details into a new draft — the standalone stand-in for
  /// both "reuse yesterday's template" and "repost for tomorrow," since a
  /// real recurring auto-publish needs a backend scheduler this app doesn't
  /// have.
  Future<ShopBag> duplicateBag(String id) async {
    final source = _bags.firstWhere((b) => b.id == id);
    final now = _clock.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final shift = tomorrow.difference(
      DateTime(
        source.pickupWindow.startAt.year,
        source.pickupWindow.startAt.month,
        source.pickupWindow.startAt.day,
      ),
    );
    return createBag(
      title: source.title,
      description: source.description,
      envelope: source.envelope,
      price: source.price,
      quantityAvailable: source.quantityAvailable,
      pickupWindow: PickupWindow(
        startAt: source.pickupWindow.startAt.add(shift),
        endAt: source.pickupWindow.endAt.add(shift),
      ),
      photoBytes: source.photoBytes,
      repeatsDaily: source.repeatsDaily,
      tags: source.tags,
    );
  }

  /// Duplicates every currently-live bag for tomorrow in one action — the
  /// bulk version of the per-bag "Duplicate for tomorrow" button, for a
  /// shop that re-lists most of its catalog daily rather than one bag at
  /// a time.
  Future<List<ShopBag>> duplicateAllLiveBagsForTomorrow() async {
    final liveIds = _bags
        .where((b) => b.status == BagStatus.live)
        .map((b) => b.id)
        .toList();
    final created = <ShopBag>[];
    for (final id in liveIds) {
      created.add(await duplicateBag(id));
    }
    return created;
  }

  /// Quick live/paused flip from the bag list, without opening the full
  /// editor — the counter-facing "we just ran out" action.
  Future<void> toggleAvailability(String id) async {
    final index = _bags.indexWhere((b) => b.id == id);
    if (index == -1) return;
    final bag = _bags[index];
    if (bag.status == BagStatus.draft) return;
    await updateBag(
      bag.copyWith(
        status: bag.status == BagStatus.live
            ? BagStatus.paused
            : BagStatus.live,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------

  /// Exposed so screens compute "time until pickup" against the same clock
  /// the repository itself uses, rather than each reaching for
  /// `DateTime.now()` independently.
  Clock get clock => _clock;

  List<ShopOrder> getOrders() => List.unmodifiable(_orders);

  /// Confirms a pickup by fallback code (manual entry) — the counter path
  /// every order supports regardless of whether the QR layers scan (A1).
  ///
  /// Throws [PickupCodeMismatchException] rather than silently no-op-ing
  /// on a wrong code, so the caller can show an explicit "that code doesn't
  /// match" error rather than a pickup that appears to do nothing.
  Future<void> confirmPickupByCode({
    required String orderId,
    required String code,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    final order = _orders[index];
    if (order.token.fallbackCode.toUpperCase() != code.trim().toUpperCase()) {
      throw const PickupCodeMismatchException();
    }
    if (_useBackend) {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('orders')
          .update({
            'status': 'collected',
            'collected_at': now,
            'updated_at': now,
          })
          .eq('id', orderId);
    }
    _orders[index] = order.copyWith(status: ShopOrderStatus.collected);
    _addNotification(
      'Pickup confirmed for ${order.bagTitle} — ${order.customerName}.',
    );
    notifyListeners();
    await _persistLocal();
  }

  /// Gives a bag's stock back after an order is settled without a
  /// collection (no-show or cancellation) — otherwise that unit is lost
  /// forever even though nobody actually has it. Mirrors the customer
  /// app's own `OrdersRepositorySupabase.cancelOrder` restore logic
  /// exactly, so a bag that sold out and then had an order fall through
  /// flips back to `live` the same way regardless of which side triggered
  /// the release.
  Future<void> _restoreBagStock({
    required String bagId,
    required int quantity,
  }) async {
    final bagRow = await _client
        .from('bags')
        .select('quantity_available, quantity_total, status')
        .eq('id', bagId)
        .maybeSingle();
    if (bagRow == null) return;
    final restored = ((bagRow['quantity_available'] as int) + quantity)
        .clamp(0, bagRow['quantity_total'] as int);
    await _client
        .from('bags')
        .update({
          'quantity_available': restored,
          'status': bagRow['status'] == 'sold_out' ? 'live' : bagRow['status'],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', bagId);
  }

  /// Records a pickup window that closed without collection. Deliberately a
  /// shop-initiated action rather than something that flips automatically
  /// the instant a window closes — there's no background process in this
  /// standalone build to notice that on its own, and a human confirming
  /// "yes, they really didn't come" is the honest shape of that decision
  /// even in a real system.
  Future<void> markNoShow(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    if (_orders[index].status != ShopOrderStatus.reserved) return;
    final order = _orders[index];
    if (_useBackend) {
      final now = DateTime.now().toUtc().toIso8601String();
      final updatedRow = await _client
          .from('orders')
          .update({'status': 'expired_uncollected', 'updated_at': now})
          .eq('id', orderId)
          .select('bag_id, quantity')
          .single();
      await _restoreBagStock(
        bagId: updatedRow['bag_id'] as String,
        quantity: updatedRow['quantity'] as int,
      );
    }
    _orders[index] = order.copyWith(status: ShopOrderStatus.expired);
    _addNotification(
      'No-show recorded for ${order.bagTitle} — ${order.customerName}.',
    );
    notifyListeners();
    await _persistLocal();
  }

  /// Shop-initiated cancellation (ran out of stock, unexpected closure,
  /// etc.) — only ever on a still-[ShopOrderStatus.reserved] order. Marks
  /// the order cancelled; actually returning the customer's money needs a
  /// real payment processor this standalone build doesn't have, so this
  /// records the shop's side of the decision rather than performing a
  /// refund it can't actually execute.
  Future<void> cancelOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;
    if (_orders[index].status != ShopOrderStatus.reserved) return;
    final order = _orders[index];
    if (_useBackend) {
      final now = DateTime.now().toUtc().toIso8601String();
      final updatedRow = await _client
          .from('orders')
          .update({
            'status': 'cancelled_by_merchant',
            'cancelled_at': now,
            'cancellation_reason': 'Cancelled by shop',
            'updated_at': now,
          })
          .eq('id', orderId)
          .select('bag_id, quantity')
          .single();
      await _restoreBagStock(
        bagId: updatedRow['bag_id'] as String,
        quantity: updatedRow['quantity'] as int,
      );
    }
    _orders[index] = order.copyWith(status: ShopOrderStatus.cancelled);
    _addNotification(
      'Order cancelled for ${order.bagTitle} — ${order.customerName}.',
    );
    notifyListeners();
    await _persistLocal();
  }

  // ---------------------------------------------------------------------
  // Payments / payouts
  // ---------------------------------------------------------------------

  List<PayoutRecord> getPayouts() => List.unmodifiable(_payouts);

  /// Collected orders not yet covered by any past payout.
  List<ShopOrder> get _unpaidCollectedOrders {
    final paidOrderIds = _payouts.expand((p) => p.orderIds).toSet();
    return _orders
        .where(
          (o) =>
              o.status == ShopOrderStatus.collected &&
              !paidOrderIds.contains(o.id),
        )
        .toList();
  }

  /// Net earnings across every collected order, regardless of payout
  /// status — the shop's all-time total.
  Money get totalEarnedAllTime {
    final collected = _orders.where(
      (o) => o.status == ShopOrderStatus.collected,
    );
    var total = const Money.zero();
    for (final order in collected) {
      total += EarningsBreakdown(gross: order.price).net;
    }
    return total;
  }

  /// Net earnings from collected orders not yet paid out — what a
  /// [requestPayout] right now would actually pay.
  Money get pendingPayoutAmount {
    var total = const Money.zero();
    for (final order in _unpaidCollectedOrders) {
      total += EarningsBreakdown(gross: order.price).net;
    }
    return total;
  }

  /// Requests a payout covering every unpaid collected order. A no-op
  /// (returns `null`) when there's nothing to pay — a ₹0 payout record
  /// would be a confusing entry in the shop's payout history for money
  /// that never moved.
  ///
  /// No real payment processor sits behind this in a standalone build —
  /// it records the shop's side of the request rather than moving money.
  Future<PayoutRecord?> requestPayout() async {
    final unpaid = _unpaidCollectedOrders;
    if (unpaid.isEmpty) return null;
    final amount = pendingPayoutAmount;
    final payout = PayoutRecord(
      id: 'payout_${_nextPayoutId++}',
      requestedAt: _clock.now(),
      amount: amount,
      orderIds: unpaid.map((o) => o.id).toList(),
    );
    _payouts.add(payout);
    _addNotification('Payout of ₹${payout.amount.wholeUnits} requested.');
    notifyListeners();
    await _persistLocal();
    return payout;
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  /// Newest first — [_addNotification] inserts at index 0.
  List<ShopNotification> getNotifications() =>
      List.unmodifiable(_notifications);

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.read).length;

  Future<void> markAllNotificationsRead() async {
    if (unreadNotificationCount == 0) return;
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
    notifyListeners();
    await _persistLocal();
  }

  // ---------------------------------------------------------------------
  // Store hours
  // ---------------------------------------------------------------------

  StoreHours get storeHours => _storeHours;

  Future<void> updateStoreHours(StoreHours hours) async {
    _storeHours = hours;
    notifyListeners();
    await _persistLocal();
  }
}

import 'dart:math';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/account/domain/entities/contact_category.dart';
import 'package:surplus_marketplace/features/account/domain/entities/deletion_eligibility.dart';
import 'package:surplus_marketplace/features/account/domain/entities/help_category.dart';
import 'package:surplus_marketplace/features/account/domain/entities/help_topic.dart';
import 'package:surplus_marketplace/features/account/domain/entities/legal_doc_id.dart';
import 'package:surplus_marketplace/features/account/domain/entities/legal_document.dart';
import 'package:surplus_marketplace/features/account/domain/entities/notification_preferences.dart';
import 'package:surplus_marketplace/features/account/domain/entities/saved_location.dart';
import 'package:surplus_marketplace/features/account/domain/repositories/account_repository.dart';
import 'package:surplus_marketplace/features/auth/domain/repositories/auth_repository.dart';
import 'package:surplus_marketplace/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:surplus_marketplace/features/checkout/domain/entities/refund_status.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';
import 'package:surplus_marketplace/features/orders/domain/entities/order_list_segment.dart';
import 'package:surplus_marketplace/features/orders/domain/repositories/orders_repository.dart';

/// Server stand-in (Phase 1 locked decision) for Phase 7 §7.7's remaining
/// surface — everything `auth`/`orders`/`catalog` don't already own.
///
/// **Deletion is the one method that reaches across features** (`_orders`
/// for blockers, `_catalog` to clear saved/watched merchants, `_auth` to
/// end the session) — a real backend would do the equivalent as one
/// transaction across services; here it's the same four-repository
/// composition `bootstrap.dart` already wires for `orders`/`engagement`,
/// extended by one more edge.
final class AccountRepositoryFake implements AccountRepository {
  AccountRepositoryFake({
    required Prefs prefs,
    required OrdersRepository orders,
    required CatalogRepository catalog,
    required AuthRepository auth,
  }) : _prefs = prefs,
       _orders = orders,
       _catalog = catalog,
       _auth = auth;

  final Prefs _prefs;
  final OrdersRepository _orders;
  final CatalogRepository _catalog;
  final AuthRepository _auth;
  final _random = Random.secure();

  static const _maxSavedLocations = 10;
  static const _savedLocationsKey = 'account.savedLocations';
  static const _notifNewBagsKey = 'account.notif.newBagsNearby';
  static const _notifWatchedKey = 'account.notif.watchedMerchantListed';
  static const _notifRateKey = 'account.notif.rateYourPickup';
  static const _themeModeKey = 'account.themeMode';
  static const _dataSaverKey = 'account.dataSaver';

  final _savedLocations = <SavedLocation>[];
  var _hydrated = false;

  Future<void> _hydrate() async {
    if (_hydrated) return;
    _hydrated = true;
    final raw = _prefs.getStringList(_savedLocationsKey);
    if (raw == null) return;
    for (final entry in raw) {
      final parts = entry.split('|');
      if (parts.length != 6) continue;
      _savedLocations.add(
        SavedLocation(
          id: parts[0],
          label: parts[1],
          isDefault: parts[2] == '1',
          location: ResolvedLocation(
            latLng: LatLng(
              latitude: double.parse(parts[3]),
              longitude: double.parse(parts[4]),
            ),
            locality: parts[5].split(',').first,
            city: parts[5].split(',').skip(1).join(',').trim(),
            precision: LocationPrecision.precise,
            source: LocationSource.search,
          ),
        ),
      );
    }
  }

  Future<void> _persist() async {
    await _prefs.setStringList(
      _savedLocationsKey,
      _savedLocations
          .map(
            (l) =>
                '${l.id}|${l.label}|${l.isDefault ? 1 : 0}|'
                '${l.location.latLng.latitude}|${l.location.latLng.longitude}|'
                '${l.location.locality},${l.location.city}',
          )
          .toList(),
    );
  }

  @override
  Future<List<SavedLocation>> getSavedLocations() async {
    await _hydrate();
    return List.unmodifiable(_savedLocations);
  }

  @override
  Future<SavedLocation> addSavedLocation({
    required String label,
    required ResolvedLocation location,
  }) async {
    await _hydrate();
    if (label.trim().isEmpty || label.length > 30) {
      throw const ValidationException(
        fieldErrors: {'label': 'invalid_length'},
      );
    }
    if (_savedLocations.length >= _maxSavedLocations) {
      throw const ValidationException(fieldErrors: {'label': 'cap_reached'});
    }
    final saved = SavedLocation(
      id: 'loc_${_randomHex(10)}',
      label: label,
      location: location,
      isDefault: _savedLocations.isEmpty, // first one becomes default
    );
    _savedLocations.add(saved);
    await _persist();
    return saved;
  }

  @override
  Future<SavedLocation> updateSavedLocationLabel(
    String id,
    String label,
  ) async {
    await _hydrate();
    final index = _savedLocations.indexWhere((l) => l.id == id);
    if (index == -1) throw const NotFoundException();
    final updated = _savedLocations[index].copyWith(label: label);
    _savedLocations[index] = updated;
    await _persist();
    return updated;
  }

  @override
  Future<void> deleteSavedLocation(String id) async {
    await _hydrate();
    final removed = _savedLocations.firstWhere(
      (l) => l.id == id,
      orElse: () => throw const NotFoundException(),
    );
    _savedLocations.removeWhere((l) => l.id == id);
    // §5f.3 — deleting the default promotes another rather than leaving a
    // dangling default reference.
    if (removed.isDefault && _savedLocations.isNotEmpty) {
      _savedLocations[0] = _savedLocations[0].copyWith(isDefault: true);
    }
    await _persist();
  }

  @override
  Future<void> setDefaultSavedLocation(String id) async {
    await _hydrate();
    if (!_savedLocations.any((l) => l.id == id)) {
      throw const NotFoundException();
    }
    for (var i = 0; i < _savedLocations.length; i++) {
      _savedLocations[i] = _savedLocations[i].copyWith(
        isDefault: _savedLocations[i].id == id,
      );
    }
    await _persist();
  }

  @override
  Future<NotificationPreferences> getNotificationPreferences() async =>
      NotificationPreferences(
        newBagsNearby: _prefs.getBool(_notifNewBagsKey) ?? true,
        watchedMerchantListed: _prefs.getBool(_notifWatchedKey) ?? true,
        rateYourPickup: _prefs.getBool(_notifRateKey) ?? true,
      );

  @override
  Future<void> setNotificationPreferences(
    NotificationPreferences prefs,
  ) async {
    await _prefs.setBool(_notifNewBagsKey, value: prefs.newBagsNearby);
    await _prefs.setBool(_notifWatchedKey, value: prefs.watchedMerchantListed);
    await _prefs.setBool(_notifRateKey, value: prefs.rateYourPickup);
  }

  @override
  Future<ThemeMode> getThemeMode() async =>
      ThemeMode.values.byName(_prefs.getString(_themeModeKey) ?? 'system');

  @override
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeModeKey, mode.name);

  @override
  Future<bool> getDataSaverEnabled() async =>
      _prefs.getBool(_dataSaverKey) ?? false;

  @override
  Future<void> setDataSaverEnabled(bool enabled) =>
      _prefs.setBool(_dataSaverKey, value: enabled);

  @override
  Future<int> cacheSizeBytes() async =>
      // A plausible fixture figure — `cached_network_image`'s disk cache
      // has no synchronous size API exposed to this fake; a real
      // implementation would sum the image-cache directory.
      3 * 1024 * 1024;

  @override
  Future<void> clearCache() async {
    // Deliberately touches nothing under `auth.*` — §5f.5's own rule that
    // tokens and order history are not cache.
  }

  @override
  Future<List<HelpTopic>> getHelpTopics() async => _helpTopics;

  @override
  Future<HelpTopic> getHelpTopic(String id) async => _helpTopics.firstWhere(
    (t) => t.id == id,
    orElse: () => throw const NotFoundException(),
  );

  @override
  Future<void> submitContactRequest({
    required ContactCategory category,
    required String message,
    String? orderId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<LegalDocument> getLegalDocument(LegalDocId docId) async =>
      _legalDocuments[docId] ?? (throw const NotFoundException());

  @override
  Future<DeletionEligibility> getDeletionEligibility() async {
    final blockers = await _blockers();
    return DeletionEligibility(eligible: blockers.isEmpty, blockers: blockers);
  }

  @override
  Future<void> deleteAccount() async {
    final blockers = await _blockers();
    if (blockers.isNotEmpty) {
      throw AccountDeletionBlockedException(blockers: blockers);
    }
    // A20 §1 — erase what this fake can reach directly: saved locations,
    // notification preferences, and every saved/watched merchant. The
    // 30-day-later irreversible erasure step and the retained/de-identified
    // order records are a stated policy (rendered in the legal document),
    // not a background job this fake runs — see the implementation log's
    // "Not delivered" note.
    _savedLocations.clear();
    await _persist();
    await _prefs.remove(_notifNewBagsKey);
    await _prefs.remove(_notifWatchedKey);
    await _prefs.remove(_notifRateKey);
    for (final merchant in await _catalog.savedMerchants()) {
      await _catalog.setMerchantSaved(merchant.id, saved: false);
    }
    await _auth.logout();
  }

  Future<List<DeletionBlocker>> _blockers() async {
    final customer = await _auth.restoreSession();
    if (customer == null) return const [];
    final active = await _orders.getOrders(
      segment: OrderListSegment.active,
      customerId: customer.id,
    );
    final blockers = <DeletionBlocker>[
      for (final order in active)
        DeletionBlocker(
          kind: DeletionBlockerKind.activeOrder,
          orderId: order.id,
        ),
    ];
    final past = await _orders.getOrders(
      segment: OrderListSegment.past,
      customerId: customer.id,
    );
    for (final order in past) {
      try {
        final refund = await _orders.getRefund(order.id);
        if (refund.status != RefundStatus.refunded) {
          blockers.add(
            DeletionBlocker(
              kind: DeletionBlockerKind.pendingRefund,
              orderId: order.id,
            ),
          );
        }
      } on Object {
        // No refund on this order — nothing to block on.
      }
    }
    return blockers;
  }

  String _randomHex(int length) => List.generate(
    length,
    (_) => _random.nextInt(16).toRadixString(16),
  ).join();
}

final _helpTopics = <HelpTopic>[
  const HelpTopic(
    id: 'help_reserve',
    title: 'How do I reserve a bag?',
    category: HelpCategory.reservations,
    body:
        'Open a bag you like and tap Reserve. You have a few minutes to '
        'complete payment before the hold releases.',
  ),
  const HelpTopic(
    id: 'help_pickup_code',
    title: "What if I can't scan the QR code?",
    category: HelpCategory.pickup,
    body:
        'Use the fallback code shown next to the QR — read it aloud to '
        'staff or let them type it in.',
  ),
  const HelpTopic(
    id: 'help_refund_timing',
    title: 'How long does a refund take?',
    category: HelpCategory.paymentsRefunds,
    body:
        'Refunds are usually credited within 3 to 7 working days of being '
        'started.',
  ),
  const HelpTopic(
    id: 'help_delete_account',
    title: 'How do I delete my account?',
    category: HelpCategory.account,
    body:
        'Go to Account > Delete account. You will need to verify your '
        'phone number with a one-time code.',
  ),
  const HelpTopic(
    id: 'help_food_safety',
    title: 'I think something is wrong with my food',
    category: HelpCategory.foodSafety,
    body:
        "If you haven't eaten it, stop now. Report it from your order and "
        "we'll respond urgently.",
  ),
];

final _legalDocuments = <LegalDocId, LegalDocument>{
  LegalDocId.terms: LegalDocument(
    docId: LegalDocId.terms,
    title: 'Terms of Service',
    version: '1.0',
    effectiveDate: DateTime(2026, 1, 1),
    lastUpdated: DateTime(2026, 1, 1),
    bodyMarkdown:
        '# Terms of Service\n\n'
        'By using Surplus Marketplace you agree to these terms.\n\n'
        '## Reservations\n\n'
        'A reservation is a binding commitment to collect a bag within its '
        'pickup window.',
  ),
  LegalDocId.privacy: LegalDocument(
    docId: LegalDocId.privacy,
    title: 'Privacy Policy',
    version: '1.0',
    effectiveDate: DateTime(2026, 1, 1),
    lastUpdated: DateTime(2026, 1, 1),
    bodyMarkdown:
        '# Privacy Policy\n\n'
        '## What we collect\n\n'
        '- Location data, to show bags near you\n'
        '- Device identifiers, for push notifications\n'
        '- Payment tokens (never raw card/UPI details)\n\n'
        '## Photos\n\n'
        'EXIF location data is stripped from any photo you upload before '
        'we store it.\n\n'
        '## Retention\n\n'
        'Order and payment records are retained for the period required '
        'by law, separated from your identity once your account is '
        'deleted.\n\n'
        '## Deleting your account\n\n'
        'Deleting your account erases your name, email, avatar, saved '
        'places, and saved shops, with a 30-day window to change your '
        'mind by signing back in.',
  ),
  LegalDocId.refundsCancellations: LegalDocument(
    docId: LegalDocId.refundsCancellations,
    title: 'Refunds & Cancellations',
    version: '1.0',
    effectiveDate: DateTime(2026, 1, 1),
    lastUpdated: DateTime(2026, 1, 1),
    bodyMarkdown:
        '# Refunds & Cancellations\n\n'
        '## Cancelling a reservation\n\n'
        'Free cancellation until 1 hour before your pickup window opens. '
        'After that, no refund applies — the shop has already set your '
        'bag aside.\n\n'
        '## Missed pickups\n\n'
        "If you don't collect your bag within its window, no refund "
        'applies, since the shop held it out of sale for you.\n\n'
        '## Refund timing\n\n'
        'Approved refunds are usually credited within 3 to 7 working '
        'days.',
  ),
  LegalDocId.grievance: LegalDocument(
    docId: LegalDocId.grievance,
    title: 'Grievance Redressal',
    version: '1.0',
    effectiveDate: DateTime(2026, 1, 1),
    lastUpdated: DateTime(2026, 1, 1),
    bodyMarkdown:
        '# Grievance Redressal\n\n'
        'Under the Consumer Protection (E-commerce) Rules 2020, our '
        'Grievance Officer can be reached using the contact details shown '
        'on the Contact Us screen. Complaints are acknowledged and '
        'resolved within the stated timeline.',
  ),
};

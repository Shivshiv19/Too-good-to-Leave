import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/error/app_exception.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/core/storage/secure_store.dart';
import 'package:surplus_marketplace/features/account/account.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/catalog/data/repositories/catalog_repository_fake.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_precision.dart';
import 'package:surplus_marketplace/features/location/domain/entities/location_source.dart';
import 'package:surplus_marketplace/features/location/domain/entities/resolved_location.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  final _store = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async => _store[key] = value;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async => _store[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async => _store.containsKey(key);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async => _store.remove(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async => Map.of(_store);

  @override
  Future<void> deleteAll({required Map<String, String> options}) async =>
      _store.clear();
}

Future<
  ({
    AccountRepositoryFake account,
    AuthRepositoryFake auth,
    OrdersRepositoryFake orders,
    CheckoutRepositoryFake checkout,
    Prefs prefs,
  })
>
_repositories({Clock? clock}) async {
  final effectiveClock = clock ?? const SystemClock();
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
  final prefs = await Prefs.open();
  final auth = AuthRepositoryFake(
    prefs: prefs,
    secureStore: const SecureStore(FlutterSecureStorage()),
    clock: effectiveClock,
  );
  final catalog = CatalogRepositoryFake(prefs: prefs, clock: effectiveClock);
  final checkout = CheckoutRepositoryFake(
    catalog: catalog,
    clock: effectiveClock,
  );
  final orders = OrdersRepositoryFake(
    checkout: checkout,
    clock: effectiveClock,
  );
  final account = AccountRepositoryFake(
    prefs: prefs,
    orders: orders,
    catalog: catalog,
    auth: auth,
  );
  return (
    account: account,
    auth: auth,
    orders: orders,
    checkout: checkout,
    prefs: prefs,
  );
}

final _bengaluru = ResolvedLocation(
  latLng: const LatLng(latitude: 12.9716, longitude: 77.5946),
  locality: 'Indiranagar',
  city: 'Bengaluru',
  precision: LocationPrecision.precise,
  source: LocationSource.search,
);

void main() {
  group('AccountRepositoryFake — saved locations (§5f.3)', () {
    test('the first added location becomes the default', () async {
      final r = await _repositories();
      final saved = await r.account.addSavedLocation(
        label: 'Home',
        location: _bengaluru,
      );
      expect(saved.isDefault, isTrue);
    });

    test('label over 30 characters throws ValidationException', () async {
      final r = await _repositories();
      await expectLater(
        r.account.addSavedLocation(label: 'x' * 31, location: _bengaluru),
        throwsA(isA<ValidationException>()),
      );
    });

    test('the 11th location throws ValidationException (cap of 10)', () async {
      final r = await _repositories();
      for (var i = 0; i < 10; i++) {
        await r.account.addSavedLocation(
          label: 'Place $i',
          location: _bengaluru,
        );
      }
      await expectLater(
        r.account.addSavedLocation(label: 'One too many', location: _bengaluru),
        throwsA(isA<ValidationException>()),
      );
    });

    test('deleting the default promotes another location', () async {
      final r = await _repositories();
      final first = await r.account.addSavedLocation(
        label: 'Home',
        location: _bengaluru,
      );
      await r.account.addSavedLocation(label: 'Work', location: _bengaluru);
      await r.account.deleteSavedLocation(first.id);
      final remaining = await r.account.getSavedLocations();
      expect(remaining.single.isDefault, isTrue);
    });

    test('setDefaultSavedLocation moves the default to exactly one', () async {
      final r = await _repositories();
      final first = await r.account.addSavedLocation(
        label: 'Home',
        location: _bengaluru,
      );
      final second = await r.account.addSavedLocation(
        label: 'Work',
        location: _bengaluru,
      );
      await r.account.setDefaultSavedLocation(second.id);
      final locations = await r.account.getSavedLocations();
      expect(locations.where((l) => l.isDefault).map((l) => l.id), [second.id]);
      expect(locations.firstWhere((l) => l.id == first.id).isDefault, isFalse);
    });
  });

  group('AccountRepositoryFake — notification preferences (§5f.4)', () {
    test('defaults to all-on', () async {
      final r = await _repositories();
      final prefs = await r.account.getNotificationPreferences();
      expect(prefs.newBagsNearby, isTrue);
      expect(prefs.watchedMerchantListed, isTrue);
      expect(prefs.rateYourPickup, isTrue);
    });

    test('setNotificationPreferences persists the change', () async {
      final r = await _repositories();
      await r.account.setNotificationPreferences(
        const NotificationPreferences(
          newBagsNearby: false,
          watchedMerchantListed: true,
          rateYourPickup: false,
        ),
      );
      final prefs = await r.account.getNotificationPreferences();
      expect(prefs.newBagsNearby, isFalse);
      expect(prefs.watchedMerchantListed, isTrue);
      expect(prefs.rateYourPickup, isFalse);
    });
  });

  group('AccountRepositoryFake — app settings (§5f.5)', () {
    test('theme mode defaults to system and round-trips', () async {
      final r = await _repositories();
      expect(await r.account.getThemeMode(), ThemeMode.system);
      await r.account.setThemeMode(ThemeMode.dark);
      expect(await r.account.getThemeMode(), ThemeMode.dark);
    });

    test('data saver defaults to off and round-trips', () async {
      final r = await _repositories();
      expect(await r.account.getDataSaverEnabled(), isFalse);
      await r.account.setDataSaverEnabled(true);
      expect(await r.account.getDataSaverEnabled(), isTrue);
    });
  });

  group('AccountRepositoryFake — legal and help (§5f.7/§5f.9)', () {
    test('getLegalDocument returns all four documents', () async {
      final r = await _repositories();
      for (final id in LegalDocId.values) {
        final doc = await r.account.getLegalDocument(id);
        expect(doc.docId, id);
      }
    });

    test('getHelpTopic throws NotFoundException for an unknown id', () async {
      final r = await _repositories();
      await expectLater(
        r.account.getHelpTopic('help_never_created'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('AccountRepositoryFake — deletion (§5f.11, A20)', () {
    test('eligible with no active orders or pending refunds', () async {
      final r = await _repositories();
      final customer = await _signInDirect(r.auth);
      final eligibility = await r.account.getDeletionEligibility();
      expect(eligibility.eligible, isTrue);
      expect(eligibility.blockers, isEmpty);
      expect(customer.id, isNotEmpty);
    });

    test('blocked by an active order', () async {
      final r = await _repositories();
      final customer = await _signInDirect(r.auth);
      final hold = await r.checkout.createHold(bagId: 'bag_sc_1', quantity: 1);
      await r.checkout.createOrder(
        holdId: hold.id,
        customerId: customer.id,
        method: PaymentMethod.upi,
      );
      final eligibility = await r.account.getDeletionEligibility();
      expect(eligibility.eligible, isFalse);
      expect(
        eligibility.blockers.single.kind,
        DeletionBlockerKind.activeOrder,
      );
    });

    test(
      'deleteAccount throws when blocked, without deleting anything',
      () async {
        final r = await _repositories();
        final customer = await _signInDirect(r.auth);
        final hold = await r.checkout.createHold(
          bagId: 'bag_sc_1',
          quantity: 1,
        );
        await r.checkout.createOrder(
          holdId: hold.id,
          customerId: customer.id,
          method: PaymentMethod.upi,
        );
        await expectLater(
          r.account.deleteAccount(),
          throwsA(isA<AccountDeletionBlockedException>()),
        );
        expect(await r.auth.restoreSession(), isNotNull);
      },
    );

    test(
      'deleteAccount clears saved locations and ends the session when eligible',
      () async {
        final r = await _repositories();
        await _signInDirect(r.auth);
        await r.account.addSavedLocation(label: 'Home', location: _bengaluru);
        await r.account.deleteAccount();
        expect(await r.account.getSavedLocations(), isEmpty);
        expect(await r.auth.restoreSession(), isNull);
      },
    );
  });
}

Future<Customer> _signInDirect(
  AuthRepositoryFake auth, {
  String phone = '+919812345678',
}) async {
  final request = await auth.requestOtp(phoneE164: phone);
  return auth.verifyOtp(requestId: request.requestId, code: '123456');
}

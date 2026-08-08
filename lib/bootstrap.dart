import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:surplus_marketplace/app/app.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/core/platform/location_capability.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config_provider.dart';
import 'package:surplus_marketplace/core/storage/secure_store.dart';
import 'package:surplus_marketplace/core/payment/payment_gateway_fake.dart';
import 'package:surplus_marketplace/features/account/account.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/catalog/catalog.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/config/config.dart';
import 'package:surplus_marketplace/features/engagement/engagement.dart';
import 'package:surplus_marketplace/features/location/location.dart';
import 'package:surplus_marketplace/features/onboarding/onboarding.dart';
import 'package:surplus_marketplace/features/orders/orders.dart';

/// Build flavour (Phase 8 §8.6), selected via `--dart-define=FLAVOR=`.
enum Flavor {
  dev,
  staging,
  prod;

  /// Reads `FLAVOR` from the compile-time environment, defaulting to [dev] —
  /// the flavour every other flavour must be explicitly opted into.
  static Flavor fromEnvironment() {
    const value = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    return Flavor.values.firstWhere(
      (f) => f.name == value,
      orElse: () => Flavor.dev,
    );
  }
}

/// [cloud.maptiler.com](https://cloud.maptiler.com) API key — never
/// hardcoded. Supplied via `flutter run/build
/// --dart-define-from-file=dart_defines.json` (gitignored, real key lives
/// only in that local file — see `.gitignore`'s "Secrets" section).
const _mapTilerApiKey = String.fromEnvironment('MAPTILER_API_KEY');

/// The composition root (Phase 8 §8.6). Builds the `ProviderScope` overrides
/// for [flavor], wires global error handlers, then calls `runApp`.
Future<void> bootstrap({required Flavor flavor}) async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // A structured logging sink (`core/logging`, Phase 8 §8.2) is not built
    // yet; presenting to the console is the interim behaviour.
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
    return true;
  };

  if (flavor != Flavor.dev) {
    // No backend exists yet (Phase 8 §8.11). An HTTP ConfigRepository
    // binding is added here once one does; until then these flavours are
    // declared but unusable, which is preferable to silently running fakes
    // under a "staging"/"prod" label.
    throw UnimplementedError(
      '${flavor.name} has no repository bindings yet — only `dev` is '
      'runnable until an HTTP ConfigRepository exists.',
    );
  }

  if (_mapTilerApiKey.isEmpty) {
    // Fail loudly, same reasoning as the flavour check above — a map
    // screen silently rendering blank grey tiles is a worse debugging
    // experience than an explicit startup error naming the exact flag.
    throw UnimplementedError(
      'No MAPTILER_API_KEY configured. Run with '
      '--dart-define-from-file=dart_defines.json (see .gitignore\'s '
      '"Secrets" section — the real key lives only in that local file).',
    );
  }

  // Platform channels (shared_preferences below) must not be touched before
  // this, and it must run before any `await` in main — see the framework's
  // own guidance on WidgetsFlutterBinding.
  WidgetsFlutterBinding.ensureInitialized();

  // `onboarding`'s repository is real local storage, not a fake standing in
  // for a server (see OnboardingRepository's class doc), so it is
  // constructed here regardless of flavour — there is nothing to swap.
  final prefs = await Prefs.open();
  const secureStore = SecureStore(FlutterSecureStorage());

  // Shared across `authRepositoryProvider` and `account`'s dependency on it
  // (§8.12 step 9) — account editing and deletion both act on the same
  // signed-in customer `auth` owns.
  final authRepositoryFake = AuthRepositoryFake(
    prefs: prefs,
    secureStore: secureStore,
    clock: const SystemClock(),
  );

  // Shared across `catalogRepositoryProvider` and `checkout`'s dependency
  // on it (D-35's cross-feature data-layer dependency) — one instance, one
  // source of truth for bag/merchant fixture reads.
  final catalogRepositoryFake = CatalogRepositoryFake(
    prefs: prefs,
    clock: const SystemClock(),
  );

  // Shared across `checkoutRepositoryProvider` and `orders`' dependency on
  // it (§8.12 step 7's D-53) — `orders` reads and mutates the same order
  // store `checkout` writes to, rather than a second, divergent copy.
  final checkoutRepositoryFake = CheckoutRepositoryFake(
    catalog: catalogRepositoryFake,
    clock: const SystemClock(),
  );

  // Shared with `engagement`'s dependency on it — notifications and
  // review-eligibility are both derived from the same order store
  // (§8.12 step 8).
  final ordersRepositoryFake = OrdersRepositoryFake(
    checkout: checkoutRepositoryFake,
    clock: const SystemClock(),
  );

  runApp(
    ProviderScope(
      overrides: [
        // Phase 1 locked decision — build entirely against fakes.
        configRepositoryProvider.overrideWithValue(ConfigRepositoryFake()),
        onboardingRepositoryProvider.overrideWithValue(
          OnboardingRepositoryPrefs(prefs),
        ),
        authRepositoryProvider.overrideWithValue(authRepositoryFake),
        locationRepositoryProvider.overrideWithValue(
          LocationRepositoryFake(prefs),
        ),
        // The device-capability wrapper, not a server stand-in — always the
        // real `geolocator`-backed implementation regardless of flavour,
        // same reasoning as `SecureStore`/`Prefs` above.
        locationCapabilityProvider.overrideWithValue(
          const LocationCapabilityGeolocator(),
        ),
        catalogRepositoryProvider.overrideWithValue(catalogRepositoryFake),
        checkoutRepositoryProvider.overrideWithValue(checkoutRepositoryFake),
        paymentGatewayProvider.overrideWithValue(const PaymentGatewayFake()),
        ordersRepositoryProvider.overrideWithValue(ordersRepositoryFake),
        engagementRepositoryProvider.overrideWithValue(
          EngagementRepositoryFake(
            orders: ordersRepositoryFake,
            clock: const SystemClock(),
          ),
        ),
        accountRepositoryProvider.overrideWithValue(
          AccountRepositoryFake(
            prefs: prefs,
            orders: ordersRepositoryFake,
            catalog: catalogRepositoryFake,
            auth: authRepositoryFake,
          ),
        ),
        mapTileConfigProvider.overrideWithValue(
          MapTilerTileConfig(apiKey: _mapTilerApiKey),
        ),
      ],
      child: const App(),
    ),
  );
}

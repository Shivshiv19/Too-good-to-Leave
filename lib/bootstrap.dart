import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:surplus_marketplace/app/app.dart';
import 'package:surplus_marketplace/core/domain/clock.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/core/platform/location_capability.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config_provider.dart';
import 'package:surplus_marketplace/core/payment/payment_gateway_fake.dart';
import 'package:surplus_marketplace/features/account/account.dart';
import 'package:surplus_marketplace/features/auth/auth.dart';
import 'package:surplus_marketplace/features/auth/data/repositories/auth_repository_supabase.dart';
import 'package:surplus_marketplace/features/catalog/catalog.dart';
import 'package:surplus_marketplace/features/catalog/data/repositories/catalog_repository_supabase.dart';
import 'package:surplus_marketplace/features/checkout/checkout.dart';
import 'package:surplus_marketplace/features/checkout/data/repositories/checkout_repository_supabase.dart';
import 'package:surplus_marketplace/features/config/config.dart';
import 'package:surplus_marketplace/features/engagement/engagement.dart';
import 'package:surplus_marketplace/features/location/data/repositories/location_repository_maptiler.dart';
import 'package:surplus_marketplace/features/location/location.dart';
import 'package:surplus_marketplace/features/onboarding/onboarding.dart';
import 'package:surplus_marketplace/features/orders/data/repositories/orders_repository_supabase.dart';
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

/// The shared Supabase project both apps read/write — see
/// `supabase/schema.sql` at the repo root for the schema this connects
/// to. Same secrets-file convention as [_mapTilerApiKey].
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

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

  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    throw UnimplementedError(
      'No SUPABASE_URL/SUPABASE_ANON_KEY configured. Run with '
      '--dart-define-from-file=dart_defines.json (see .gitignore\'s '
      '"Secrets" section — the real values live only in that local file).',
    );
  }

  // Platform channels (shared_preferences below) must not be touched before
  // this, and it must run before any `await` in main — see the framework's
  // own guidance on WidgetsFlutterBinding.
  WidgetsFlutterBinding.ensureInitialized();

  // The shared backend both apps read/write — must be ready before any
  // repository below touches it.
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );

  // `onboarding`'s repository is real local storage, not a fake standing in
  // for a server (see OnboardingRepository's class doc), so it is
  // constructed here regardless of flavour — there is nothing to swap.
  final prefs = await Prefs.open();

  // Real Supabase-backed repositories — see `supabase/schema.sql`. Auth is
  // real Supabase Auth sessions behind a hardcoded OTP; catalog/checkout/
  // orders read and write the shared `bags`/`orders`/`payments` tables the
  // shop app (`shop/`) also reads and writes, which is what makes a bag
  // published there and an order placed here show up live on both sides.
  // Payment stays fake (`PaymentGatewayFake` below) — the explicit product
  // scoping this phase was built against.
  final authRepository = AuthRepositorySupabase(prefs);
  final catalogRepository = CatalogRepositorySupabase(prefs);
  final checkoutRepository = CheckoutRepositorySupabase();
  final ordersRepository = OrdersRepositorySupabase();

  runApp(
    ProviderScope(
      overrides: [
        // config/onboarding stay on fakes/local-storage — untouched by this
        // phase's "bags and orders are real and realtime" scope.
        configRepositoryProvider.overrideWithValue(ConfigRepositoryFake()),
        onboardingRepositoryProvider.overrideWithValue(
          OnboardingRepositoryPrefs(prefs),
        ),
        authRepositoryProvider.overrideWithValue(authRepository),
        // Real MapTiler geocoding, not the Bengaluru-only fixture search —
        // see LocationRepositoryMaptiler's class doc.
        locationRepositoryProvider.overrideWithValue(
          LocationRepositoryMaptiler(prefs, apiKey: _mapTilerApiKey),
        ),
        // The device-capability wrapper, not a server stand-in — always the
        // real `geolocator`-backed implementation regardless of flavour,
        // same reasoning as `SecureStore`/`Prefs` above.
        locationCapabilityProvider.overrideWithValue(
          const LocationCapabilityGeolocator(),
        ),
        catalogRepositoryProvider.overrideWithValue(catalogRepository),
        checkoutRepositoryProvider.overrideWithValue(checkoutRepository),
        paymentGatewayProvider.overrideWithValue(const PaymentGatewayFake()),
        ordersRepositoryProvider.overrideWithValue(ordersRepository),
        engagementRepositoryProvider.overrideWithValue(
          EngagementRepositoryFake(
            orders: ordersRepository,
            clock: const SystemClock(),
          ),
        ),
        accountRepositoryProvider.overrideWithValue(
          AccountRepositoryFake(
            prefs: prefs,
            orders: ordersRepository,
            catalog: catalogRepository,
            auth: authRepository,
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

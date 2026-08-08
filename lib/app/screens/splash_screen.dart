import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/design_system/foundations/dimens.dart';
import 'package:surplus_marketplace/features/auth/presentation/providers/auth_providers.dart';
import 'package:surplus_marketplace/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:surplus_marketplace/features/config/presentation/providers/config_providers.dart';
import 'package:surplus_marketplace/features/location/presentation/providers/location_providers.dart';
import 'package:surplus_marketplace/features/onboarding/presentation/providers/onboarding_providers.dart';

/// Bootstrap · force-update gate · A3 payment recovery (§4.2 `/splash`).
///
/// Splash is a real route with real work, not a decorative delay (§4.1):
/// `go_router`'s `redirect` cannot `await`, so every flag a guard might need
/// must be resolved into [SessionState] before any guard runs, and this is
/// the one place that resolution happens.
///
/// **Scope note (Phase 9 Step 6).** This build resolves config, onboarding,
/// auth-session, cached-location, and unresolved-payment (A3) state — every
/// flag §4.3's guard chain reads. The unresolved-payment check always
/// resolves to "none" against the fake (`CheckoutRepositoryFake` has no
/// cross-restart persistence, see its class doc), so A3's redirect has
/// nothing to trigger it end-to-end yet without a real backend.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final session = ref.read(sessionStateProvider);

    // Each independent of the others — a failure in one must not skip
    // resolving the rest (§5a.1's per-step degradation rules).
    final hasSeenOnboarding = await ref
        .read(onboardingRepositoryProvider)
        .hasSeenOnboarding();

    // restoreSession() itself never throws (see AuthRepository's class
    // doc), but a defensive fallback keeps this in the same shape as the
    // config try/catch below rather than relying on that contract alone.
    final customer = await ref
        .read(authRepositoryProvider)
        .restoreSession()
        .catchError((_) => null);
    final isAuthenticated = customer != null;
    final isProfileComplete = customer?.isProfileComplete ?? false;

    // A read failure here is the same "never a launch blocker" case as the
    // config fetch below — an unreadable cache is just "no location yet",
    // not a crash.
    final cachedLocation = await ref
        .read(locationRepositoryProvider)
        .cachedLocation()
        .catchError((_) => null);
    final hasLocation = cachedLocation != null;

    // A3 — never a launch blocker either; an unreachable check just means
    // "nothing unresolved that we know of", not a crash.
    final unresolved = await ref
        .read(checkoutRepositoryProvider)
        .getUnresolvedOrder()
        .catchError((_) => null);
    final unresolvedPaymentOrderId = unresolved?.orderId;

    try {
      final config = await ref.read(remoteConfigProvider.future);
      final packageInfo = await PackageInfo.fromPlatform();
      session.markBootstrapped(
        forceUpdateRequired: config.requiresForceUpdateFor(
          packageInfo.version,
        ),
        maintenanceMode: config.maintenance.active,
        maintenanceEtaAt: config.maintenance.etaAt,
        hasSeenOnboarding: hasSeenOnboarding,
        isAuthenticated: isAuthenticated,
        isProfileComplete: isProfileComplete,
        hasLocation: hasLocation,
        unresolvedPaymentOrderId: unresolvedPaymentOrderId,
      );
    } on Object {
      // §5a.1 — remote config is never a launch blocker. An unreachable
      // config proceeds on the bundled fallback rather than stalling here.
      session.markBootstrapped(
        forceUpdateRequired: false,
        maintenanceMode: false,
        hasSeenOnboarding: hasSeenOnboarding,
        isAuthenticated: isAuthenticated,
        isProfileComplete: isProfileComplete,
        hasLocation: hasLocation,
        unresolvedPaymentOrderId: unresolvedPaymentOrderId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Space.x6),
          child: CircularProgressIndicator(color: colors.actionPrimaryFg),
        ),
      ),
    );
  }
}

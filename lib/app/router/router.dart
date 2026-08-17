import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/app/router/routes.dart';
import 'package:surplus_marketplace/app/session/session_providers.dart';
import 'package:surplus_marketplace/app/session/session_state.dart';

part 'router.g.dart';

/// The GoRouter singleton (Phase 4 §4.1) and the §4.3 ordered redirect chain.
///
/// `kept alive` alongside [sessionStateProvider]: `refreshListenable:` is
/// wired to one specific [SessionState] instance for the life of the app, so
/// this provider must never be rebuilt against a different one.
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final session = ref.watch(sessionStateProvider);
  return GoRouter(
    initialLocation: const SplashRoute().location,
    refreshListenable: session,
    redirect: (context, state) => _redirect(session, state.matchedLocation),
    routes: $appRoutes,
  );
}

const _splash = '/splash';
const _forceUpdate = '/force-update';
const _maintenance = '/maintenance';
const _onboarding = '/onboarding';
const _locationPrimer = '/location-primer';
const _authPhone = '/auth/phone';
const _authOtp = '/auth/otp';
const _authProfileSetup = '/auth/profile-setup';
const _sessionExpired = '/session-expired';
const _discover = '/discover';
const _checkoutVerifying = '/checkout/verifying';

/// §4.3 rule 6 classification — routes that require a resolved location.
/// `/discover` and all its children (search, category, merchant, bag) are
/// the "Public, location required" class (§4.3's route auth
/// classification table) — the first real trigger for a rule that has been
/// mechanically wired since Step 4 with nothing to protect.
const _locationRequiredPrefixes = <String>[_discover];

bool _requiresLocation(String location) =>
    _locationRequiredPrefixes.any(location.startsWith);

/// §4.3 rule 7 classification — routes that require auth. `/orders` joined
/// `/checkout` in Step 7; `/notifications` joins them in Step 8 — every
/// notification here is derived from a signed-in customer's own orders
/// (§8.12 step 8), so there's nothing to show anonymously. `/saved` is
/// deliberately **not** gated: saved/watched merchant state is
/// device-scoped (§8.12 step 5), not account-scoped, so it works the same
/// as Discover — usable anonymously, same as the merchant profile's own
/// Save/Watch toggle prompting for auth inline rather than via a route
/// guard.
const _authRequiredPrefixes = <String>[
  '/checkout',
  '/orders',
  '/notifications',
];

/// **Amendment A18** — `/account` itself is public (Step 9), so gating is
/// per-item rather than per-prefix: only these four sub-routes require
/// auth. `/account/settings`, `/help*`, `/contact`, `/legal/*`, and
/// `/about` all stay public — the account root's own screen shows the
/// gated items anyway, labelled as gated, so a direct deep link into one
/// of them gets the identical treatment (redirect-preserving auth wall)
/// rather than a silent bounce.
const _authRequiredAccountPrefixes = <String>[
  '/account/profile',
  '/account/locations',
  '/account/notifications',
  '/account/delete',
];

bool _requiresAuth(String location) =>
    _authRequiredPrefixes.any(location.startsWith) ||
    _authRequiredAccountPrefixes.any(location.startsWith);

/// §4.3 — a single ordered chain, first match wins.
///
/// **Scope note (Phase 9 Step 6).** All of rules 1–8 are now implemented.
/// Rule 4 (A3) is mechanically wired — `SessionState.unresolvedPaymentOrderId`
/// is resolved at Splash from `CheckoutRepository.getUnresolvedOrder()` —
/// but the fake always returns `null` (no cross-restart persistence for
/// holds/orders/payments, see its class doc), so this rule has no scenario
/// to trigger it end-to-end without a real backend; the redirect target
/// and screen are fully built for when one exists. Rule 7 (the auth wall)
/// now protects `/checkout` and `/orders`; `saved`/`account` still resolve
/// to placeholder shell branches.
/// `/dietary-setup` has no guard rule of its own in §4.3 — it's reached by
/// explicit navigation from `/location-primer`/`/location-setup`, same as
/// the spec.
String? _redirect(SessionState session, String location) {
  if (session.forceUpdateRequired) {
    return location == _forceUpdate ? null : _forceUpdate;
  }
  if (session.maintenanceMode) {
    return location == _maintenance ? null : _maintenance;
  }
  if (!session.isBootstrapped) {
    return location == _splash ? null : _splash;
  }
  final unresolvedPaymentOrderId = session.unresolvedPaymentOrderId;
  if (unresolvedPaymentOrderId != null) {
    // A3 — outranks onboarding and auth deliberately: a debited user with
    // no confirmed order is the most urgent state in the app.
    return location == _checkoutVerifying
        ? null
        : '$_checkoutVerifying?orderId=$unresolvedPaymentOrderId&resumed=true';
  }
  if (!session.hasSeenOnboarding) {
    return location == _onboarding ? null : _onboarding;
  }
  if (_requiresLocation(location) && !session.hasLocation) {
    return _locationPrimer;
  }
  if (_requiresAuth(location) && !session.isAuthenticated) {
    return '$_authPhone?redirectTo=${Uri.encodeComponent(location)}';
  }
  if (session.isAuthenticated && !session.isProfileComplete) {
    return location == _authProfileSetup
        ? null
        : '$_authProfileSetup?redirectTo=${Uri.encodeComponent(location)}';
  }
  // A normal, fully resolved session with nothing further to gate on.
  // Anything terminal falls through to Discover — including the auth
  // screens once there is a completed session to protect them from
  // re-entering. Rule 6 (just above) catches the case where Discover
  // itself isn't reachable yet because location isn't resolved.
  // `/dietary-setup` is deliberately excluded, see above.
  final atTerminalRoute =
      location == _splash ||
      location == _forceUpdate ||
      location == _maintenance ||
      location == _onboarding ||
      (session.isAuthenticated &&
          (location == _authPhone ||
              location == _authOtp ||
              location == _authProfileSetup ||
              location == _sessionExpired));
  if (!atTerminalRoute) return null;
  // Google's own redirect always lands back here, at the app's normal
  // entry point, never directly on the phone-entry screen — nothing
  // Google-specific happens on the way back in. Catching it right here,
  // the one place an unauthenticated session is about to fall through to
  // Discover, sends it to finish signing up instead of leaving the person
  // looking silently signed-out with no explanation.
  if (session.hasPendingGoogleSignIn) {
    return '$_authPhone?from-google=true';
  }
  return _discover;
}

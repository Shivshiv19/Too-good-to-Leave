import 'package:flutter/foundation.dart';

/// Synchronous flags the router's `redirect` chain reads (Phase 4 §4.1).
///
/// `go_router`'s `redirect` callback cannot `await`, so every flag a guard
/// might need must already be resolved before the guard runs. Splash does
/// that resolution once, then calls the setters below; the router is wired
/// to `refreshListenable: sessionState`, so a later flag change (logout,
/// token expiry, location acquired) re-runs the guard chain with no
/// imperative `navigate` call at the site that changed the flag.
///
/// **Scope note (Phase 9 Step 6, revised).** All of §4.3 rules 1–8 are now
/// wired. [unresolvedPaymentOrderId] (rule 4) is resolved at Splash from
/// `CheckoutRepository.getUnresolvedOrder()`, but the fake always returns
/// `null` — see its class doc on why there's no cross-restart persistence
/// to demonstrate an actual A3 resume against. Rule 7 (the auth wall) now
/// protects `/checkout` for real, its first genuine trigger.
final class SessionState extends ChangeNotifier {
  bool _isBootstrapped = false;
  bool _forceUpdateRequired = false;
  bool _maintenanceMode = false;
  DateTime? _maintenanceEtaAt;
  bool _hasSeenOnboarding = false;
  bool _isAuthenticated = false;
  bool _isProfileComplete = false;
  bool _hasLocation = false;
  bool _hasPendingGoogleSignIn = false;
  String? _unresolvedPaymentOrderId;

  /// Whether Splash has finished its bootstrap sequence.
  bool get isBootstrapped => _isBootstrapped;

  /// §4.3 rule 1 — outranks every other guard.
  bool get forceUpdateRequired => _forceUpdateRequired;

  /// §4.3 rule 2.
  bool get maintenanceMode => _maintenanceMode;

  /// Known only when [maintenanceMode] is true; null means unknown (§5a.10).
  DateTime? get maintenanceEtaAt => _maintenanceEtaAt;

  /// §4.3 rule 5.
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  /// §4.3 rule 7 (the auth wall) and rule 8.
  bool get isAuthenticated => _isAuthenticated;

  /// §4.3 rule 8.
  bool get isProfileComplete => _isProfileComplete;

  /// §4.3 rule 6.
  bool get hasLocation => _hasLocation;

  /// True right after a Google sign-in with no phone number collected yet
  /// — see the auth repository's `hasPendingGoogleSignIn`. Read once, at the
  /// moment the router would otherwise land someone fresh out of Splash on
  /// Discover, to send them to finish signing up instead — never rechecked
  /// mid-session, so it can't yank someone back to the phone screen while
  /// they're deliberately off browsing.
  bool get hasPendingGoogleSignIn => _hasPendingGoogleSignIn;

  /// Amendment A3 — non-null while a debited order awaits reconciliation.
  String? get unresolvedPaymentOrderId => _unresolvedPaymentOrderId;

  /// Called once by Splash after config, onboarding, auth, cached-location,
  /// and unresolved-payment state resolve.
  void markBootstrapped({
    required bool forceUpdateRequired,
    required bool maintenanceMode,
    required bool hasSeenOnboarding,
    required bool isAuthenticated,
    required bool isProfileComplete,
    required bool hasLocation,
    bool hasPendingGoogleSignIn = false,
    DateTime? maintenanceEtaAt,
    String? unresolvedPaymentOrderId,
  }) {
    _isBootstrapped = true;
    _forceUpdateRequired = forceUpdateRequired;
    _maintenanceMode = maintenanceMode;
    _maintenanceEtaAt = maintenanceEtaAt;
    _hasSeenOnboarding = hasSeenOnboarding;
    _isAuthenticated = isAuthenticated;
    _isProfileComplete = isProfileComplete;
    _hasLocation = hasLocation;
    _hasPendingGoogleSignIn = hasPendingGoogleSignIn;
    _unresolvedPaymentOrderId = unresolvedPaymentOrderId;
    notifyListeners();
  }

  /// Called once `/checkout/verifying` resolves the payment either way
  /// (§5c.6) — clears rule 4 so the guard chain stops redirecting there.
  void clearUnresolvedPayment() {
    _unresolvedPaymentOrderId = null;
    notifyListeners();
  }

  /// Called by [OnboardingScreen] the moment the user finishes or skips, so
  /// the guard chain reflects it within the same session rather than only
  /// on next launch.
  void markOnboardingSeen() {
    _hasSeenOnboarding = true;
    notifyListeners();
  }

  /// Called the moment a location is confirmed — by the primer screen's
  /// direct GPS path or the setup screen's `Confirm` (§5a.3/§5a.4) — so the
  /// guard chain reflects it within the same session rather than only on
  /// next launch, same reasoning as [markOnboardingSeen].
  void markLocationResolved() {
    _hasLocation = true;
    notifyListeners();
  }

  /// Called the moment `verifyOtp` succeeds (§5a.7).
  void markAuthenticated({required bool isProfileComplete}) {
    _isAuthenticated = true;
    _isProfileComplete = isProfileComplete;
    notifyListeners();
  }

  /// Called the moment `updateProfile` succeeds (§5a.8).
  void markProfileComplete() {
    _isProfileComplete = true;
    notifyListeners();
  }

  /// Called on logout (§7.2.5) or a detected session expiry (A24).
  void markSignedOut() {
    _isAuthenticated = false;
    _isProfileComplete = false;
    notifyListeners();
  }
}

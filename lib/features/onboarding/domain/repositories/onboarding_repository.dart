import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';

/// Local-only state for the onboarding/dietary-setup flow (Phase 5a §5a.2,
/// §5a.5).
///
/// **No fake/HTTP split.** Every other feature's repository stands in for a
/// server (Phase 1 locked decision: fakes first, HTTP later), but there is
/// no server here — `hasSeenOnboarding` and the dietary preset are purely
/// device-local facts. A single implementation backed by `core/storage/
/// prefs.dart` serves every flavour; inventing a "fake" for local storage
/// would model a distinction that doesn't exist.
abstract interface class OnboardingRepository {
  /// Whether the onboarding carousel (§5a.2) has been shown or skipped.
  ///
  /// Read once at Splash into `SessionState.hasSeenOnboarding` (§4.3 rule 5)
  /// — the same synchronous-resolution requirement as the config fetch.
  Future<bool> hasSeenOnboarding();

  Future<void> markOnboardingSeen();

  /// The stored preset, or `null` if dietary setup has never been completed.
  Future<DietaryPreference?> dietaryPreference();

  Future<void> saveDietaryPreference(DietaryPreference preference);
}

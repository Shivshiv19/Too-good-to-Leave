import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/onboarding/domain/repositories/onboarding_repository.dart';

final class OnboardingRepositoryPrefs implements OnboardingRepository {
  const OnboardingRepositoryPrefs(this._prefs);

  final Prefs _prefs;

  static const _hasSeenOnboardingKey = 'onboarding.hasSeenOnboarding';
  static const _dietaryPreferenceKey = 'onboarding.dietaryPreference';

  @override
  Future<bool> hasSeenOnboarding() async =>
      _prefs.getBool(_hasSeenOnboardingKey) ?? false;

  @override
  Future<void> markOnboardingSeen() =>
      _prefs.setBool(_hasSeenOnboardingKey, value: true);

  @override
  Future<DietaryPreference?> dietaryPreference() async {
    final wireValue = _prefs.getString(_dietaryPreferenceKey);
    if (wireValue == null) return null;
    // fromWire falls back to pureVeg on an unrecognised value (the
    // conservative default), which can only happen here from data written by
    // a future app version this build doesn't recognise.
    return DietaryPreference.fromWire(wireValue);
  }

  @override
  Future<void> saveDietaryPreference(DietaryPreference preference) =>
      _prefs.setString(_dietaryPreferenceKey, preference.wireValue);
}

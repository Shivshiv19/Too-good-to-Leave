import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:surplus_marketplace/core/domain/dietary_envelope.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/onboarding/data/repositories/onboarding_repository_prefs.dart';

Future<OnboardingRepositoryPrefs> _repository() async {
  SharedPreferences.setMockInitialValues({});
  return OnboardingRepositoryPrefs(await Prefs.open());
}

void main() {
  group('OnboardingRepositoryPrefs', () {
    test('hasSeenOnboarding defaults to false', () async {
      final repo = await _repository();
      expect(await repo.hasSeenOnboarding(), isFalse);
    });

    test('markOnboardingSeen persists true', () async {
      final repo = await _repository();
      await repo.markOnboardingSeen();
      expect(await repo.hasSeenOnboarding(), isTrue);
    });

    test('dietaryPreference defaults to null (never set)', () async {
      final repo = await _repository();
      expect(await repo.dietaryPreference(), isNull);
    });

    test('saveDietaryPreference round-trips every preset', () async {
      for (final preference in DietaryPreference.values) {
        final repo = await _repository();
        await repo.saveDietaryPreference(preference);
        expect(await repo.dietaryPreference(), preference);
      }
    });

    test(
      'a value written by the same key survives a fresh Prefs instance '
      '(simulates app restart)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final first = OnboardingRepositoryPrefs(await Prefs.open());
        await first.markOnboardingSeen();
        await first.saveDietaryPreference(DietaryPreference.jain);

        final second = OnboardingRepositoryPrefs(await Prefs.open());
        expect(await second.hasSeenOnboarding(), isTrue);
        expect(await second.dietaryPreference(), DietaryPreference.jain);
      },
    );
  });
}

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/core/storage/prefs.dart';
import 'package:surplus_marketplace/features/onboarding/domain/repositories/onboarding_repository.dart';

part 'onboarding_providers.g.dart';

/// Overridden once at bootstrap with the resolved [Prefs] instance — see
/// `bootstrap.dart`. `Prefs.open()` is async, so this cannot be constructed
/// inline the way `ConfigRepositoryFake` is.
@Riverpod(keepAlive: true)
OnboardingRepository onboardingRepository(Ref ref) => throw UnimplementedError(
  'onboardingRepositoryProvider has no override — set one in bootstrap.dart.',
);

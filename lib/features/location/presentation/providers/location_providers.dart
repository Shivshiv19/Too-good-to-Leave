import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/core/platform/location_capability.dart';
import 'package:surplus_marketplace/features/location/domain/repositories/location_repository.dart';

part 'location_providers.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`.
@riverpod
LocationRepository locationRepository(Ref ref) => throw UnimplementedError(
  'locationRepositoryProvider has no override — set one in bootstrap.dart.',
);

/// Separate from [locationRepository]: this is the device-capability wrapper
/// (GPS + permission), always the real `geolocator`-backed implementation
/// regardless of flavour — same reasoning as `SecureStore`/`Prefs`, D-19.
@riverpod
LocationCapability locationCapability(Ref ref) => throw UnimplementedError(
  'locationCapabilityProvider has no override — set one in bootstrap.dart.',
);

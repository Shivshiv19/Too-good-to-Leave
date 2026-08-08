import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/features/auth/domain/repositories/auth_repository.dart';

part 'auth_providers.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`.
@riverpod
AuthRepository authRepository(Ref ref) => throw UnimplementedError(
  'authRepositoryProvider has no override — set one in bootstrap.dart.',
);

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/features/engagement/domain/repositories/engagement_repository.dart';

part 'engagement_providers.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`.
@riverpod
EngagementRepository engagementRepository(Ref ref) => throw UnimplementedError(
  'engagementRepositoryProvider has no override — set one in bootstrap.dart.',
);

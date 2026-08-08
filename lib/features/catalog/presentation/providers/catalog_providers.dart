import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/features/catalog/domain/repositories/catalog_repository.dart';

part 'catalog_providers.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`.
@riverpod
CatalogRepository catalogRepository(Ref ref) => throw UnimplementedError(
  'catalogRepositoryProvider has no override — set one in bootstrap.dart.',
);

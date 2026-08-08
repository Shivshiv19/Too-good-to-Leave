import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/features/config/domain/entities/remote_config.dart';
import 'package:surplus_marketplace/features/config/domain/entities/taxonomy.dart';
import 'package:surplus_marketplace/features/config/domain/repositories/config_repository.dart';

part 'config_providers.g.dart';

/// The DI seam (Phase 8 §8.6).
///
/// Overridden per flavour at the composition root (`bootstrap.dart`) — `dev`
/// binds `ConfigRepositoryFake`; `staging`/`prod` will bind an HTTP
/// repository once a backend exists. The default throws rather than falling
/// back to a fake, so a flavour that forgot its override fails loudly
/// instead of silently shipping fake data.
@riverpod
ConfigRepository configRepository(Ref ref) => throw UnimplementedError(
  'configRepositoryProvider has no override — set one in bootstrap.dart '
  'for this flavour.',
);

/// The `GET /v1/config` response (Phase 7 §7.3), fetched once per app
/// session by the Splash route.
@riverpod
Future<RemoteConfig> remoteConfig(Ref ref) =>
    ref.watch(configRepositoryProvider).fetchConfig();

/// The `GET /v1/config/taxonomy` response (Phase 7 §7.3).
@riverpod
Future<Taxonomy> taxonomy(Ref ref) =>
    ref.watch(configRepositoryProvider).fetchTaxonomy();

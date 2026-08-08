import 'package:surplus_marketplace/features/config/domain/entities/remote_config.dart';
import 'package:surplus_marketplace/features/config/domain/entities/taxonomy.dart';

/// Supplies remote config and taxonomy to every other feature (Phase 8 §8.2).
///
/// `presentation` depends only on this abstraction (§8.1); the fake binding
/// is used in the `dev` flavour, an HTTP binding is added once a backend
/// exists (§8.6). Neither is visible to callers.
abstract interface class ConfigRepository {
  /// Fetches `GET /v1/config` (Phase 7 §7.3). Called once, at Splash.
  Future<RemoteConfig> fetchConfig();

  /// Fetches `GET /v1/config/taxonomy` (Phase 7 §7.3).
  ///
  /// ETag revalidation against the cached copy is a transport-level concern
  /// of the HTTP binding's interceptor chain (§8.2
  /// `core/network/interceptors/etag_interceptor.dart`), not of this
  /// interface — a fake has no wire to revalidate against, so it always
  /// returns a fresh value.
  Future<Taxonomy> fetchTaxonomy();
}

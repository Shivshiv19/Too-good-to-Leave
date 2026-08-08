/// Public surface of the `config` feature (Phase 8 §8.3.1).
///
/// Every other feature reaches `policyValues` and the taxonomy through this
/// barrel — never through `features/config/domain/...` or
/// `features/config/data/...` directly. Reaching into either is a
/// `no_cross_feature_deep_import` lint failure once §8.7's custom lints are
/// built.
library;

export 'package:surplus_marketplace/features/config/data/repositories/config_repository_fake.dart';
export 'package:surplus_marketplace/features/config/domain/entities/maintenance_status.dart';
export 'package:surplus_marketplace/features/config/domain/entities/policy_values.dart';
export 'package:surplus_marketplace/features/config/domain/entities/remote_config.dart';
export 'package:surplus_marketplace/features/config/domain/entities/taxonomy.dart';
export 'package:surplus_marketplace/features/config/domain/repositories/config_repository.dart';
export 'package:surplus_marketplace/features/config/presentation/providers/config_providers.dart';

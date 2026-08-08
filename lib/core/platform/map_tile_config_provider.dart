import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config.dart';

part 'map_tile_config_provider.g.dart';

/// The DI seam (Phase 8 §8.6). Overridden in `bootstrap.dart`. Shared
/// across `location` (pin-drop map) and `catalog` (Discover's map toggle)
/// — the one place both features get their tile source from, so a
/// provider switch is one override, not two.
@riverpod
MapTileConfig mapTileConfig(Ref ref) => throw UnimplementedError(
  'mapTileConfigProvider has no override — set one in bootstrap.dart.',
);

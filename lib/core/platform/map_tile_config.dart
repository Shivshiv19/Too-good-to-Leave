/// The swappable map vendor boundary (Phase 8 §8.6 — "MapProvider,
/// Google → Mappls/Ola swappable").
///
/// **Why this is a tile-URL config, not a widget wrapper.** `flutter_map`
/// (the widget used throughout `design_system`) already takes any raw XYZ
/// tile URL template — it has no vendor lock-in of its own. So the actual
/// swappable surface is just "which tiles, with which key," not a second
/// widget abstraction on top of an already-generic one. Changing providers
/// later (Mappls, Ola, or Google's raster tile endpoint) means writing one
/// new implementation of this interface, never touching a screen.
///
/// **Why not a vector-tile provider (OpenFreeMap).** Tried and reverted —
/// see D-78 through D-81 in `docs/09-implementation-log.md`. `vector_map_tiles`
/// (the only Dart package that renders MapLibre-style vector tiles inside
/// `flutter_map`) pulls in `flutter_scene` for GPU-accelerated rendering,
/// which depends on `dart:ffi` — unavailable on Flutter Web, so the web
/// build fails outright. A raster tile provider avoids that dependency
/// chain entirely.
abstract interface class MapTileConfig {
  /// An XYZ template — `flutter_map`'s `TileLayer.urlTemplate` shape,
  /// e.g. `https://.../{z}/{x}/{y}.png?key=...`.
  String get urlTemplate;

  /// Shown in the map's attribution corner — most tile providers'
  /// terms of service require this to stay visible.
  String get attribution;
}

/// [cloud.maptiler.com](https://cloud.maptiler.com) — free tier to start,
/// same key upgrades to a paid plan with no code change (the reason this
/// project picked it over a vendor requiring a card on file just to
/// evaluate).
final class MapTilerTileConfig implements MapTileConfig {
  const MapTilerTileConfig({required this.apiKey});

  final String apiKey;

  @override
  String get urlTemplate =>
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$apiKey';

  @override
  String get attribution => '© MapTiler © OpenStreetMap contributors';
}

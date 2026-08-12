/// The swappable map vendor boundary — mirrors the customer app's own
/// `core/platform/map_tile_config.dart` (copied-not-shared, same as
/// everything else between these two apps). `flutter_map` takes any raw
/// XYZ tile URL, so the actual swappable surface is just "which tiles,
/// with which key," not a widget abstraction on top of an already-generic
/// one.
abstract interface class MapTileConfig {
  /// An XYZ template — `flutter_map`'s `TileLayer.urlTemplate` shape,
  /// e.g. `https://.../{z}/{x}/{y}.png?key=...`.
  String get urlTemplate;

  /// Shown in the map's attribution corner — most tile providers' terms
  /// of service require this to stay visible.
  String get attribution;
}

/// [cloud.maptiler.com](https://cloud.maptiler.com) — the same MapTiler
/// project/key the customer app already uses for its own map screens.
final class MapTilerTileConfig implements MapTileConfig {
  const MapTilerTileConfig({required this.apiKey});

  final String apiKey;

  @override
  String get urlTemplate =>
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$apiKey';

  @override
  String get attribution => '© MapTiler © OpenStreetMap contributors';
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:surplus_marketplace/app/theme/app_theme.dart';
import 'package:surplus_marketplace/core/domain/lat_lng.dart';
import 'package:surplus_marketplace/core/platform/map_tile_config.dart';

/// One marker on a [TileMapView].
class MapPin {
  const MapPin({required this.position, required this.child, this.onTap});

  final LatLng position;
  final Widget child;
  final VoidCallback? onTap;
}

/// The one place `flutter_map`/MapTiler-specific code lives (Phase 8 §8.6
/// — `MapTileConfig` is the swappable vendor boundary; this widget is
/// vendor-agnostic itself, since `flutter_map` takes any XYZ tile URL).
///
/// Deliberately thin — screens that need a "pin follows the map centre"
/// picker (§5a.4's pin-drop) compose their own centred-icon `Stack` on top
/// of this, rather than this widget growing a second interaction mode. A
/// screen that just needs to show fixed [pins] passes them and nothing
/// else.
class TileMapView extends StatelessWidget {
  const TileMapView({
    required this.tileConfig,
    required this.center,
    this.zoom = 15,
    this.pins = const [],
    this.onCenterChanged,
    this.interactive = true,
    super.key,
  });

  final MapTileConfig tileConfig;
  final LatLng center;
  final double zoom;
  final List<MapPin> pins;

  /// Fires as the user pans/zooms — the pin-drop pattern reads this to
  /// know where the fixed centre icon currently points.
  final ValueChanged<LatLng>? onCenterChanged;

  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return fm.FlutterMap(
      options: fm.MapOptions(
        initialCenter: ll.LatLng(center.latitude, center.longitude),
        initialZoom: zoom,
        interactionOptions: fm.InteractionOptions(
          flags: interactive ? fm.InteractiveFlag.all : fm.InteractiveFlag.none,
        ),
        onPositionChanged: onCenterChanged == null
            ? null
            : (position, hasGesture) {
                final c = position.center;
                onCenterChanged!(
                  LatLng(latitude: c.latitude, longitude: c.longitude),
                );
              },
      ),
      children: [
        fm.TileLayer(
          urlTemplate: tileConfig.urlTemplate,
          userAgentPackageName: 'com.surplusmarketplace.app',
        ),
        if (pins.isNotEmpty)
          fm.MarkerLayer(
            markers: [
              for (final pin in pins)
                fm.Marker(
                  point: ll.LatLng(
                    pin.position.latitude,
                    pin.position.longitude,
                  ),
                  child: pin.onTap == null
                      ? pin.child
                      : GestureDetector(onTap: pin.onTap, child: pin.child),
                ),
            ],
          ),
        fm.RichAttributionWidget(
          attributions: [
            fm.TextSourceAttribution(
              tileConfig.attribution,
              textStyle: context.type.caption.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

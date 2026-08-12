import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:too_good_to_leave_shop/app/theme/app_theme.dart';
import 'package:too_good_to_leave_shop/core/platform/map_tile_config.dart';

/// One marker on a [TileMapView].
class MapPin {
  const MapPin({required this.position, required this.child});

  final LatLng position;
  final Widget child;
}

/// The one place `flutter_map`/MapTiler-specific code lives — mirrors the
/// customer app's own component of the same name. Deliberately thin: a
/// screen that needs a "pin follows the map centre" picker (see
/// `_MapPickerSheet` in `registration_screen.dart`) composes its own
/// centred-icon `Stack` on top of this rather than this widget growing a
/// second interaction mode.
class TileMapView extends StatelessWidget {
  const TileMapView({
    required this.tileConfig,
    required this.center,
    this.zoom = 15,
    this.pins = const [],
    this.onCenterChanged,
    this.interactive = true,
    this.mapController,
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

  /// Lets a parent (e.g. a search box picking a result) recentre the map
  /// programmatically via `mapController.move(...)`. Optional — most call
  /// sites never need to drive the map from outside.
  final fm.MapController? mapController;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return fm.FlutterMap(
      mapController: mapController,
      options: fm.MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: fm.InteractionOptions(
          flags: interactive ? fm.InteractiveFlag.all : fm.InteractiveFlag.none,
        ),
        onPositionChanged: onCenterChanged == null
            ? null
            : (position, hasGesture) => onCenterChanged!(position.center),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: tileConfig.urlTemplate,
          userAgentPackageName: 'com.toogoodtoleave.shop',
        ),
        if (pins.isNotEmpty)
          fm.MarkerLayer(
            markers: [
              for (final pin in pins)
                fm.Marker(point: pin.position, child: pin.child),
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

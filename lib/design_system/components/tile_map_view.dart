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
class TileMapView extends StatefulWidget {
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

  /// Lets a call site drive the camera from outside (zoom buttons, a
  /// recentre-on-me action, jumping to a search result) — same pattern the
  /// shop app's picker sheet already uses. Owned by the caller when passed;
  /// left null, this widget creates and disposes its own.
  final fm.MapController? mapController;

  @override
  State<TileMapView> createState() => _TileMapViewState();
}

class _TileMapViewState extends State<TileMapView> {
  // Falls back to an internally-owned controller (rather than left
  // implicit) so `_onMapTap` can project a pin's LatLng into the *current*
  // screen position — a fixed meters-per-pin threshold can't work, since
  // how many metres a marker's visual footprint covers changes with every
  // zoom level. Only disposed here if we created it ourselves — a
  // caller-supplied controller is the caller's to dispose.
  late final fm.MapController _controller =
      widget.mapController ?? fm.MapController();

  @override
  void dispose() {
    if (widget.mapController == null) _controller.dispose();
    super.dispose();
  }

  /// A plain `GestureDetector` on each marker widget turned out to reliably
  /// miss taps on web — flutter_map's own pan/drag gesture recognizer wins
  /// the gesture arena for a stationary click often enough that markers
  /// were effectively untappable in testing, regardless of hit-test
  /// behaviour or marker size. Handling taps at the map level instead (the
  /// pattern flutter_map's own docs recommend for exactly this) and
  /// picking whichever pin's *screen position* is closest to the tap,
  /// within a fixed pixel radius, sidesteps the arena conflict entirely.
  void _onMapTap(fm.TapPosition tapPosition, ll.LatLng point) {
    final tapOffset = tapPosition.relative;
    if (tapOffset == null) return;
    const hitRadiusPx = 28.0;

    MapPin? closest;
    var closestDistance = double.infinity;
    for (final pin in widget.pins) {
      if (pin.onTap == null) continue;
      final pinLatLng = ll.LatLng(
        pin.position.latitude,
        pin.position.longitude,
      );
      final screenOffset = _controller.camera.latLngToScreenOffset(pinLatLng);
      final distance = (screenOffset - tapOffset).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closest = pin;
      }
    }
    if (closest != null && closestDistance <= hitRadiusPx) {
      closest.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return fm.FlutterMap(
      mapController: _controller,
      options: fm.MapOptions(
        initialCenter: ll.LatLng(
          widget.center.latitude,
          widget.center.longitude,
        ),
        initialZoom: widget.zoom,
        interactionOptions: fm.InteractionOptions(
          flags: widget.interactive
              ? fm.InteractiveFlag.all
              : fm.InteractiveFlag.none,
        ),
        onTap: widget.pins.isEmpty ? null : _onMapTap,
        onPositionChanged: widget.onCenterChanged == null
            ? null
            : (position, hasGesture) {
                final c = position.center;
                widget.onCenterChanged!(
                  LatLng(latitude: c.latitude, longitude: c.longitude),
                );
              },
      ),
      children: [
        fm.TileLayer(
          urlTemplate: widget.tileConfig.urlTemplate,
          userAgentPackageName: 'com.surplusmarketplace.app',
        ),
        if (widget.pins.isNotEmpty)
          fm.MarkerLayer(
            markers: [
              for (final pin in widget.pins)
                fm.Marker(
                  point: ll.LatLng(
                    pin.position.latitude,
                    pin.position.longitude,
                  ),
                  child: IgnorePointer(child: pin.child),
                ),
            ],
          ),
        fm.RichAttributionWidget(
          attributions: [
            fm.TextSourceAttribution(
              widget.tileConfig.attribution,
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
